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
local membership = require('membership')
local membership_network = require('membership.network')
local http = require('http.server')

local rpc = require('cluster.rpc')
local vars = require('cluster.vars').new('cluster')
local auth = require('cluster.auth')
local utils = require('cluster.utils')
local admin = require('cluster.admin')
local webui = require('cluster.webui')
local argparse = require('cluster.argparse')
local topology = require('cluster.topology')
local bootstrap = require('cluster.bootstrap')
local confapplier = require('cluster.confapplier')
local vshard_utils = require('cluster.vshard-utils')
local cluster_cookie = require('cluster.cluster-cookie')
local service_registry = require('cluster.service-registry')

local e_init = errors.new_class('Cluster initialization failed')
local e_http = errors.new_class('Http initialization failed')

local DEFAULT_CLUSTER_COOKIE = 'secret-cluster-cookie'

--- Vshard storage group configuration.
--
-- Every vshard storage must be assigned to a group.
-- @tfield
--   number bucket_count
--   Bucket count for the storage group.
-- @table VshardGroup
local function check_vshard_group(name, params)
    if type(name) ~= 'string' then
        return nil, 'bad argument options.vshard_groups' ..
            ' to cluster.cfg (table must have string keys)'
    end

    local field = string.format('options.vshard_groups[%s]', name)

    if type(params) ~= 'table' then
        return nil, string.format(
            'bad argument %s' ..
            ' (table expected, got %s)',
            field, type(params)
        )
    end

    local bucket_count = params.bucket_count
    if bucket_count ~= nil and type(bucket_count) ~= 'number' then
        return nil, string.format(
            'bad argument %s.bucket_count' ..
            ' (?number expected, got %s)',
            field, type(bucket_count)
        )
    end

    local known_keys = {
        bucket_count = true,
    }
    for key, _ in pairs(params) do
        if not known_keys[key] then
            return string.format(
                'unexpected argument %s.%s',
                field, key
            )
        end
    end

    return true
end

--- Initialize the cluster module.
--
-- After this call, you can operate the instance via Tarantool console.
-- Notice that this call does not initialize the database - `box.cfg` is not called yet.
-- Do not try to call `box.cfg` yourself, the cluster will do it when it is time.
--
-- Both cluster.cfg and box.cfg options can be configured with
-- command-line arguments or environment variables.
--
-- @function cfg
-- @tparam table opts Available options are:
--
-- @tparam ?string opts.workdir
--  a directory where all data will be stored: snapshots, wal logs and cluster config file.
--  (default: ".", overriden by
--  env `TARANTOOL_WORKDIR`,
--  args `--workdir`)
--
-- @tparam ?string opts.advertise_uri
--  either `"<HOST>:<PORT>"` or `"<HOST>:"` or `"<PORT>"`.
--  Used by other instances to connect the current one.
--
--  When `<HOST>` isn't specified, it's detected as the only one non-local IP address.
--  If there is more than one IP adresses available - defaults to "localhost".
--
--  When `<PORT>` isn't specified, it's derived as follows:
--  If the `TARANTOOL_INSTANCE_NAME` has numeric suffix `_<N>`, then `<PORT> = 3300+<N>`.
--  Otherwise default `<PORT> = 3301` is used.
--
-- @tparam ?string opts.cluster_cookie
--  secret used to separate unrelated clusters, which
--  prevents them from seeing each other during broadcasts.
--  Also used for encrypting internal communication.
--  (default: "secret-cluster-cookie", overriden by
--  env `TARANTOOL_CLUSTER_COOKIE`,
--  args `--cluster-cookie`)
--
-- @tparam ?number opts.bucket_count
--  bucket count for vshard cluster. See vshard doc for more details.
--  (default: 30000)
--
-- @tparam ?{[string]=VshardGroupParams,...} opts.vshard_groups
--  vshard storage groups, table keys used as names
--
-- @tparam ?string|number opts.http_port
--  port to open administrative UI and API on
--  (default: nil, overriden by
--  env `TARANTOOL_HTTP_PORT`,
--  args `--http-port`)
--
-- @tparam ?string opts.alias
-- human-readable instance name that will be available in administrative UI
--  (default: nil, overriden by
--  env `TARANTOOL_ALIAS`,
--  args `--alias`)
--
-- @tparam table opts.roles
-- list of user-defined roles that will be available to enable on the instance_uuid
--
-- @tparam ?boolean opts.auth_enabled
-- toggle authentication in administrative UI and API
--  (default: false)
--
-- @tparam ?string opts.auth_backend_name
-- user-provided set of callbacks related to authentication
--
-- @tparam ?string opts.console_sock
-- Socket to start console listening on.
--  (default: nil, overriden by
--  env `TARANTOOL_CONSOLE_SOCK`,
--  args `--console-sock`)
--
-- @tparam ?table box_opts
-- tarantool extra box.cfg options (e. g. memtx_memory), that may require additional tuning
--
-- @return[1] true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function cfg(opts, box_opts)
    checks({
        workdir = '?string',
        advertise_uri = '?string',
        cluster_cookie = '?string',
        bucket_count = '?number',
        http_port = '?string|number',
        alias = '?string',
        roles = 'table',
        auth_backend_name = '?string',
        auth_enabled = '?boolean',
        vshard_groups = '?table',
        console_sock = '?string',
    }, '?table')

    local args, err = argparse.parse()
    if args == nil then
        return nil, err
    end
    local _cluster_opts, err = argparse.get_cluster_opts()
    if _cluster_opts == nil then
        return nil, err
    end
    local _box_opts, err = argparse.get_box_opts()
    if _box_opts == nil then
        return nil, err
    end

    for k, v in pairs(_cluster_opts) do
        opts[k] = v
    end

    if box_opts == nil then
        box_opts = {}
    end
    for k, v in pairs(_box_opts) do
        box_opts[k] = v
    end

    local vshard_groups = {}
    for k, v in pairs(opts.vshard_groups or {}) do
        local name, params
        if type(k) == 'number' and type(v) == 'string' then
            -- {'group-name'}
            name, params = v, {}
        else
            -- {['group-name'] = {bucket_count=1000}}
            name, params = k, table.copy(v)
        end

        local ok, err = check_vshard_group(name, params)
        if not ok then
            error(err, 2)
        end

        vshard_groups[name] = params
    end

    if (vars.boot_opts ~= nil) then
        return nil, e_init:new('Cluster is already initialized')
    end

    if opts.workdir == nil then
        opts.workdir = '.'
    end
    opts.workdir = fio.abspath(opts.workdir)

    local ok, err = utils.mktree(opts.workdir)
    if not ok then
        return nil, err
    end

    confapplier.set_workdir(opts.workdir)
    cluster_cookie.init(opts.workdir)
    if opts.cluster_cookie ~= nil then
        cluster_cookie.set_cookie(opts.cluster_cookie)
    end
    if cluster_cookie.cookie() == nil then
        cluster_cookie.set_cookie(DEFAULT_CLUSTER_COOKIE)
    end

    local advertise
    if opts.advertise_uri ~= nil then
        advertise = uri.parse(opts.advertise_uri)
    else
        advertise = {}
    end
    if advertise == nil then
        return nil, e_init:new('Invalid advertise_uri %q', opts.advertise_uri)
    end

    if advertise.service == nil then
        local offset
        if args.instance_name ~= nil then
            offset = args.instance_name:match('_(%d+)$')
            offset = tonumber(offset)
        end

        if offset ~= nil then
            args.http_port = 8080 + offset
            log.info('Derived http_port to be %d', args.http_port)
            advertise.service = 3300 + offset
            log.info('Derived binary_port to be %d', advertise.service)
        else
            advertise.service = 3301
        end
    else
        advertise.service = tonumber(advertise.service)
    end

    if advertise.service == nil then
        return nil, e_init:new('Invalid port in advertise_uri %q', opts.advertise_uri)
    end

    if advertise.host == nil then
        local ips = membership_network.getifaddrs()
        local ip_count = utils.table_count(ips or {})

        if ip_count > 1 then
            log.info('This node has more than one non-local IP address:')
            for iface, ipstruct in pairs(ips) do
                log.info('  %s: %s', iface, ipstruct.inet4)
            end
            log.info('Auto-detection of IP address disabled. '
                .. 'Use --advertise-uri argument'
                .. ' or ADVERTISE_URI environment variable'
            )
            advertise.host = 'localhost'
        elseif ip_count == 1 then
            local _, ipstruct = next(ips)
            advertise.host = ipstruct.inet4
            log.info('Auto-detected IP to be %q', advertise.host)
        else
            advertise.host = 'localhost'
        end
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

    if opts.auth_backend_name ~= nil then
        local auth_backend, err = e_init:pcall(require, opts.auth_backend_name)
        if not auth_backend then
            return nil, err
        end

        local ok, err = e_init:pcall(function()
            local ok = auth.set_callbacks(auth_backend)
            return ok
        end)
        if not ok then
            return nil, err
        end

        local auth_enabled = opts.auth_enabled
        if auth_enabled == nil then
            auth_enabled = false
        end
        local ok, err = e_init:pcall(auth.set_enabled, auth_enabled)
        if not ok then
            return nil, err
        end
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

    if next(vshard_groups) == nil then
        vshard_groups = nil
    else
        for _, params in pairs(vshard_groups) do
            if params.bucket_count == nil then
                params.bucket_count = opts.bucket_count
            end
        end
    end

    vshard_utils.set_known_groups(vshard_groups, opts.bucket_count)

    bootstrap.set_box_opts(box_opts)
    bootstrap.set_boot_opts({
        workdir = opts.workdir,
        binary_port = advertise.service,
        bucket_count = opts.bucket_count,
        vshard_groups = vshard_groups,
    })

    if #fio.glob(opts.workdir..'/*.snap') > 0 then
        log.info('Snapshot found in ' .. opts.workdir)
        local ok, err = bootstrap.from_snapshot()
        if not ok then
            log.error('%s', err)
        end
    else
        fiber.create(function()
            while type(box.cfg) == 'function' do
                if not bootstrap.from_membership() then
                    fiber.sleep(1.0)
                end
            end

            vars.bootstrapped = true
        end)
        log.info('Ready for bootstrap')
    end

    if opts.console_sock ~= nil then
        local console = require('console')
        local ok, err = e_init:pcall( console.listen, 'unix/:' .. opts.console_sock)
        if not ok then
            return nil, err
        end
    end

    return true
end

--- Bootstrap a new cluster.
--
-- It is bootstrapped with the only (current) instance.
-- Later, you can join other instances using `cluster.admin`.
--
-- @function bootstrap
-- @tparam {string,...} roles
--   roles to be enabled on the current instance
-- @tparam table uuids
-- @tparam ?string uuids.instance_uuid
--   bootstrap current instance with specified uuid
-- @tparam ?string uuids.replicaset_uuid
--   assign replicaset uuid to the current instance
-- @tparam {[string]=string,...} labels
--   labels for the current instance
-- @tparam string vshard_group
--   which vshard storage group to join to
--   (for multi-group configuration only)
local function bootstrap_from_scratch(roles, uuids, labels, vshard_group)
    checks('?table', {
        instance_uuid = '?uuid_str',
        replicaset_uuid = '?uuid_str',
        },
        '?table',
        '?string'
    )

    return admin.join_server({
        uri = membership.myself().uri,
        instance_uuid = uuids and uuids.instance_uuid,
        replicaset_uuid = uuids and uuids.replicaset_uuid,
        roles = roles,
        labels = labels,
        vshard_group = vshard_group,
    })
end

return {
    cfg = cfg,
    bootstrap = bootstrap_from_scratch,

    --- Shorthand for `cluster.admin` module.
    -- @field cluster.admin
    admin = admin,

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
            errors.deprecate(
                'Function "cluster.confapplier.get_readonly()" is deprecated. ' ..
                'Use "cluster.config_get_readonly()" instead.'
            )
            return confapplier.get_readonly(...)
        end,

        get_deepcopy = function(...)
            errors.deprecate(
                'Function "cluster.confapplier.get_deepcopy()" is deprecated. ' ..
                'Use "cluster.config_get_deepcopy()" instead.'
            )
            return confapplier.get_deepcopy(...)
        end,

        patch_clusterwide = function(...)
            errors.deprecate(
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
            errors.deprecate(
                'Function "cluster.service_registry.get()" is deprecated. ' ..
                'Use "cluster.service_get()" instead.'
            )
            return service_registry.get(...)
        end,
        set = function(...)
            errors.deprecate(
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
}
