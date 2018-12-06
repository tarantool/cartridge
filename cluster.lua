#!/usr/bin/env tarantool

--- High-level cluster management interface.
-- Tarantool Enterprise cluster module provides you a simple way
-- to manage operation of tarantool cluster.
-- What we call a cluster is a several tarantool instances, connected together.
-- Cluster module does not care about who starts those instances,
-- it only cares about configuration of already running processes.
--
-- Cluster module automates vshard and replication configuration,
-- simplifies configuration and administration tasks.
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

local vars = require('cluster.vars').new('cluster')
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
-- After the call user can operate the instance via tarantool console.
-- Notice that this call does not initialize the database - `box.cfg` is not called yet.
-- The user must not try to call `box.cfg` himself, the cluster will do it when it's time to.
-- @function cfg
-- @tparam table opts
-- @tparam table box_opts
-- @return[1] true
-- @treturn[2] nil
-- @treturn[2] error Error description
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

        httpd:route({
                method = 'GET',
                path = '/',
                public = true,
            },
            function(req)
                return req:redirect_to('/cluster')
            end
        )

        local ok, err = e_http:pcall(webui.init, httpd)
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
    _boot_opts.instance_uuid = uuids.instance_uuid
    _boot_opts.replicaset_uuid = uuids.replicaset_uuid

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
    admin = admin,
    bootstrap = bootstrap_from_scratch,
    is_healthy = topology.cluster_is_healthy,
    confapplier = {
        get_readonly = confapplier.get_readonly,
        get_deepcopy = confapplier.get_deepcopy,
        patch_clusterwide = confapplier.patch_clusterwide,
    },
    service_registry = service_registry,
}
