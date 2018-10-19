#!/usr/bin/env tarantool

local fio = require('fio')
local uri = require('uri')
local log = require('log')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local vshard = require('vshard')
local membership = require('membership')
_G.vshard = vshard

local admin = require('cluster.admin')
local webui = require('cluster.webui')
local topology = require('cluster.topology')
local bootstrap = require('cluster.bootstrap')
local confapplier = require('cluster.confapplier')
local cluster_cookie = require('cluster.cluster-cookie')

local e_init = errors.new_class('Cluster initialization failed')
local function init(opts, box_opts)
    checks({
        workdir = 'string',
        advertise_uri = 'string',
        cluster_cookie = '?string',
        alias = '?string',
    }, '?table')

    opts.workdir = fio.abspath(opts.workdir)

    if not fio.path.exists(opts.workdir) then
        local rc = os.execute(('mkdir -p \'%s\''):format(opts.workdir))
        if not rc then
            return nil, e_init:new('Can not create working directory %q', opts.workdir)
        end
    end

    -- Is this necessary?
    -- local rc = fio.chdir(opts.workdir)
    -- if not rc then
    --     return nil, e_init:new('Can not change to working directory %q', opts.workdir)
    -- end

    cluster_cookie.init(opts.workdir)
    if opts.cluster_cookie ~= nil then
        cluster_cookie.set_cookie(opts.cluster_cookie)
    end
    if cluster_cookie.cookie() == nil then
        cluster_cookie.set_cookie('secret-cluster-cookie')
    end


    local advertise = uri.parse(opts.advertise_uri)
    if advertise.service == nil then
        return nil, e_init('Missing port in advertise_uri %q', opts.advertise_uri)
    else
        advertise.service = tonumber(advertise.service)
    end

    log.info('Using advertise_uri "%s:%d"', advertise.host, advertise.service)
    membership.init(advertise.host, advertise.service)
    membership.set_encryption_key(cluster_cookie.cookie())
    membership.set_payload('alias', opts.alias)
    -- topology.set_password(cluster_cookie.cookie())
    local ok, err = membership.probe_uri(membership.myself().uri)
    if not ok then
        return nil, e_init:new('Can not ping myself: %s', err)
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

    -- http.init(args.http_port)
    -- graphql.init()
    -- metrics.init()
    -- admin.init()

    -- startup_tune.init()
    -- errors.monkeypatch_netbox_call()
    -- netbox_fiber_storage.monkeypatch_netbox_call()

    local boot_opts = {}
    boot_opts.workdir = opts.workdir
    boot_opts.binary_port = advertise.service

    if #fio.glob(opts.workdir..'/*.snap') > 0 then
        log.info('Snapshot found in ' .. opts.workdir)
        return bootstrap.from_snapshot(boot_opts, box_opts)
    else
        package.loaded['cluster'].bootstrap = function(roles, uuids)
            checks('?table', {
                instance_uuid = '?uuid_str',
                replicaset_uuid = '?uuid_str',
            })

            local _boot_opts = table.copy(boot_opts)
            _boot_opts.instance_uuid = uuids.instance_uuid
            _boot_opts.replicaset_uuid = uuids.replicaset_uuid
            return bootstrap.from_scratch(_boot_opts, box_opts, roles)
        end

        fiber.create(function()
            while type(box.cfg) == 'function' do
                if not bootstrap.from_membership(boot_opts, box_opts) then
                    fiber.sleep(1.0)
                end
            end
            package.loaded['cluster'].bootstrap = function()
                return nil, e_init:new('Already bootstrapped')
            end
        end)
        log.info('Ready for bootstrap')
    end

    package.loaded['cluster'].init = function()
        return nil, e_init:new('Already initialized')
    end

    return true
end

return {
    init = init,
    admin = admin,
    webui = webui,
    bootstrap = nil,
    is_healthy = topology.cluster_is_healthy,
}
