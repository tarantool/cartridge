#!/usr/bin/env tarantool

local fio = require('fio')
local uri = require('uri')
local log = require('log')
local checks = require('checks')
local errors = require('errors')
local membership = require('membership')

local vars = require('cluster.vars').new('cluster')
local topology = require('cluster.topology')
local cluster_cookie = require('cluster.cluster-cookie')

vars:new('workdir')
vars:new('advertise_uri')

local e_init = errors.new_class('Cluster initialization failed')
local function init(opts)
    checks({
        workdir = 'string',
        advertise_uri = 'string',
        cluster_cookie = '?string',
        alias = '?string',
    })

    vars.workdir = fio.abspath(opts.workdir)
    vars.advertise_uri = opts.advertise_uri

    if not fio.path.exists(vars.workdir) then
        local rc = os.execute(('mkdir -p \'%s\''):format(vars.workdir))
        if not rc then
            return nil, e_init:new('Can not create working directory %q', vars.workdir)
        end
    end

    local rc = fio.chdir(vars.workdir)
    if not rc then
        return nil, e_init:new('Can not change to working directory %q', vars.workdir)
    end

    cluster_cookie.init(vars.workdir)
    if vars.cluster_cookie ~= nil then
        cluster_cookie.set_cookie(vars.cluster_cookie)
    end
    if cluster_cookie.cookie() == nil then
        cluster_cookie.set_cookie('secret-cluster-cookie')
    end


    local advertise = uri.parse(vars.advertise_uri)
    if advertise.service == nil then
        return nil, e_init('Missing port in advertise_uri %q', vars.advertise_uri)
    else
        advertise.service = tonumber(advertise.service)
    end

    log.info('Using advertise_uri "%s:%d"', advertise.host, advertise.service)
    membership.init(advertise.host, advertise.service)
    membership.set_encryption_key(cluster_cookie.cookie())
    membership.set_payload('alias', vars.alias)
    -- topology.set_password(cluster_cookie.cookie())
    local ok, err = membership.probe_uri(membership.myself().uri)
    if not ok then
        return nil, e_init('Can not ping myself: %s', err)
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

    return true
end

return {
    init = init,
}
