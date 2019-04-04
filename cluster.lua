#!/usr/bin/env tarantool

--- High-level cluster management interface.
-- Tarantool Enterprise cluster module provides you with a simple way
-- to manage cluster operations.
-- The cluster consists of several Tarantool instances acting in concert.
-- Cluster module does not care about how the instances start,
-- it only cares about the configuration of already running processes.
--
-- Cluster module automates vshard and replication configuration,
-- simplifies custom configuration and administrative tasks.
-- @module cluster

local fio = require('fio')
local uri = require('uri')
local log = require('log')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local vshard = require('vshard')
local membership = require('membership')
local http = require('http.server')
_G.vshard = vshard

local rpc = require('cluster.rpc')
local vars = require('cluster.vars').new('cluster')
local auth = require('cluster.auth')
local admin = require('cluster.admin')
local webui = require('cluster.webui')
local topology = require('cluster.topology')
local bootstrap = require('cluster.bootstrap')
local confapplier = require('cluster.confapplier')
local cluster_cookie = require('cluster.cluster-cookie')
local service_registry = require('cluster.service-registry')

local e_init = errors.new_class('Cluster initialization failed')
local e_http = errors.new_class('Http initialization failed')
-- Parameters to be passed at bootstrap
vars:new('box_opts')
vars:new('boot_opts')
vars:new('bootstrapped')

--- Initialize the cluster module.
-- After this call, you can operate the instance via Tarantool console.
-- Notice that this call does not initialize the database - `box.cfg` is not called yet.
-- Do not try to call `box.cfg` yourself, the cluster will do it when it is time.
-- @function cfg
--
-- @tparam table opts
-- @tparam string opts.workdir The instance's working directory. Also used as `wal_dir` and `memtx_dir`.
-- @tparam string opts.advertise_uri
--   The instance's URI advertised to other members.
--   This address is used to establish connections between cluster instances,
--   cluster operations, replication, and status monitoring.
-- @tparam ?string opts.cluster_cookie
-- @tparam ?number opts.bucket_count
-- @tparam ?string|number opts.http_port
-- @tparam ?string opts.alias
-- @tparam ?table opts.roles
-- @tparam ?table box_opts passed to `box.cfg` as is.
--
-- @treturn[1] boolean `true`
-- @treturn[2] nil
-- @treturn[2] table Error description
local function cfg(opts, box_opts)
    checks({
        workdir = 'string',
        advertise_uri = 'string',
        cluster_cookie = '?string',
        bucket_count = '?number',
        http_port = '?string|number',
        alias = '?string',
        roles = '?table',
    }, '?table')

    if (vars.boot_opts ~= nil) then
        return nil, e_init:new('Cluster is already initialized')
    end

    opts.workdir = fio.abspath(opts.workdir)

    if not fio.path.is_dir(opts.workdir) then
        local rc = os.execute(('mkdir -p \'%s\''):format(opts.workdir))
        if rc ~= 0 then
            return nil, e_init:new('Can not create workdir %q', opts.workdir)
        end
    end

    confapplier.set_workdir(opts.workdir)
    cluster_cookie.init(opts.workdir)
    if opts.cluster_cookie ~= nil then
        cluster_cookie.set_cookie(opts.cluster_cookie)
    end
    if cluster_cookie.cookie() == nil then
        cluster_cookie.set_cookie('secret-cluster-cookie')
    end


    local advertise = uri.parse(opts.advertise_uri)
    if advertise.service == nil then
        return nil, e_init:new('Missing port in advertise_uri %q', opts.advertise_uri)
    else
        advertise.service = tonumber(advertise.service)
    end

    log.info('Using advertise_uri "%s:%d"', advertise.host, advertise.service)
    local ok, err = e_init:pcall(membership.init, advertise.host, advertise.service)
    if not ok then
        return nil, err
    end

    membership.set_encryption_key(cluster_cookie.cookie())
    membership.set_payload('alias', opts.alias)
    local ok, estr = membership.probe_uri(membership.myself().uri)
    if not ok then
        return nil, e_init:new('Can not ping myself: %s', estr)
    end

    -- broadcast several popular ports
    for p, _ in pairs({
        [3301] = true,
        [advertise.service] = true,
        [advertise.service-1] = true,
        [advertise.service+1] = true,
    }) do
        membership.broadcast(p)
    end

    if opts.http_port ~= nil then
        local httpd = http.new(
            '0.0.0.0', opts.http_port,
            { log_requests = false }
        )

        local ok, err = e_http:pcall(httpd.start, httpd)
        if not ok then
            return nil, err
        end

        local ok, err = e_http:pcall(webui.init, httpd)
        if not ok then
            return nil, err
        end

        local ok, err = e_init:pcall(auth.init, httpd)
        if not ok then
            return nil, err
        end

        local srv_name = httpd.tcp_server:name()
        log.info('Listening HTTP on %s:%s', srv_name.host, srv_name.port)
        service_registry.set('httpd', httpd)
    end

    for _, role in ipairs(opts.roles or {}) do
        local ok, err = confapplier.register_role(role)
        if not ok then
            return nil, err
        end
    end

    -- metrics.init()
    -- admin.init()

    -- startup_tune.init()
    -- errors.monkeypatch_netbox_call()
    -- netbox_fiber_storage.monkeypatch_netbox_call()

    vars.box_opts = box_opts
    vars.boot_opts = {
        workdir = opts.workdir,
        binary_port = advertise.service,
        bucket_count = opts.bucket_count,
    }

    if #fio.glob(opts.workdir..'/*.snap') > 0 then
        log.info('Snapshot found in ' .. opts.workdir)
        local ok, err = bootstrap.from_snapshot(vars.boot_opts, vars.box_opts)
        if not ok then
            log.error('%s', err)
        end
    else
        fiber.create(function()
            while type(box.cfg) == 'function' do
                if not bootstrap.from_membership(vars.boot_opts, vars.box_opts) then
                    fiber.sleep(1.0)
                end
            end

            vars.bootstrapped = true
        end)
        log.info('Ready for bootstrap')
    end

    return true
end

local function bootstrap_from_scratch(roles, uuids)
    checks('?table', {
        instance_uuid = '?uuid_str',
        replicaset_uuid = '?uuid_str',
    })

    if vars.bootstrapped then
        return nil, e_init:new('Cluster is already bootstrapped')
    end

    local _boot_opts = table.copy(vars.boot_opts)
    _boot_opts.instance_uuid = uuids and uuids.instance_uuid
    _boot_opts.replicaset_uuid = uuids and uuids.replicaset_uuid

    local function pack(...)
        return select('#', ...), {...}
    end
    local n, ret = pack(
        bootstrap.from_scratch(_boot_opts, vars.box_opts, roles)
    )

    vars.bootstrapped = true

    return unpack(ret, 1, n)
end

return {
    cfg = cfg,

    --- Shorthand for `cluster.admin` module.
    -- @field cluster.admin
    admin = admin,

    --- Bootstrap a new cluster.
    -- It is bootstrapped with the only (current) instance.
    -- Later, you can join other instances using
    -- `cluster.admin`.
    -- @function bootstrap
    bootstrap = bootstrap_from_scratch,

    --- Check cluster health.
    -- It is healthy if all instances are healthy.
    -- @function is_healthy
    -- @treturn boolean
    is_healthy = topology.cluster_is_healthy,


    --- Clusterwide configuration.
    -- See `cluster.confapplier` module for details.
    -- @section confapplier

    --- Shorthand for `cluster.confapplier.get_readonly`.
    --- @function config_get_readonly
    config_get_readonly = confapplier.get_readonly,

    --- Shorthand for `cluster.confapplier.get_deepcopy`.
    --- @function config_get_deepcopy
    config_get_deepcopy = confapplier.get_deepcopy,

    --- Shorthand for `cluster.confapplier.patch_clusterwide`.
    --- @function config_patch_clusterwide
    config_patch_clusterwide = confapplier.patch_clusterwide,

    confapplier = {
        get_readonly = function(...)
            log.warn(
                'Function "cluster.confapplier.get_readonly()" is deprecated. ' ..
                'Use "cluster.config_get_readonly()" instead.'
            )
            return confapplier.get_readonly(...)
        end,

        get_deepcopy = function(...)
            log.warn(
                'Function "cluster.confapplier.get_deepcopy()" is deprecated. ' ..
                'Use "cluster.config_get_deepcopy()" instead.'
            )
            return confapplier.get_deepcopy(...)
        end,

        patch_clusterwide = function(...)
            log.warn(
                'Function "cluster.confapplier.patch_clusterwide()" is deprecated. ' ..
                'Use "cluster.config_patch_clusterwide()" instead.'
            )
            return confapplier.patch_clusterwide(...)
        end,
    },

    --- Inter-role interaction.
    -- See `cluster.service-registry` module for details.
    -- @section service_registry

    --- Shorthand for `cluster.service-registry.get`.
    -- @function service_get
    service_get = service_registry.get,

    --- Shorthand for `cluster.service-registry.set`.
    -- @function service_set
    service_set = service_registry.set,

    service_registry = {
        get = function(...)
            log.warn(
                'Function "cluster.service_registry.get()" is deprecated. ' ..
                'Use "cluster.service_get()" instead.'
            )
            return service_registry.get(...)
        end,
        set = function(...)
            log.warn(
                'Function "cluster.service_registry.set()" is deprecated. ' ..
                'Use "cluster.service_set()" instead.'
            )
            return service_registry.set(...)
        end,
    },

    --- Cross-instance calls.
    -- See `cluster.rpc` module for details.
    -- @section rpc

    --- Shorthand for `cluster.rpc.call`.
    -- @function rpc_call
    rpc_call = rpc.call,

    --- Users authorization.
    -- @section auth

    --- Shorthand for `cluster.auth.set_enabled`.
    -- @function auth_set_enabled
    auth_set_enabled = auth.set_enabled,

    --- Shorthand for `cluster.auth.set_callbacks`.
    -- @function auth_set_callbacks
    auth_set_callbacks = auth.set_callbacks,
}
