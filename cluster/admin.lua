#!/usr/bin/env tarantool

local log = require('log')
local fun = require('fun')
local vshard = require('vshard')
local errors = require('errors')
local uuid_lib = require('uuid')
local membership = require('membership')

local pool = require('cluster.pool')
local topology = require('cluster.topology')
local confapplier = require('cluster.confapplier')

local e_bootstrap_vshard = errors.new_class('Bootstrapping vshard failed')
local e_topology_edit = errors.new_class('Editing cluster topology failed')
local e_probe_server = errors.new_class('Can not probe server')

local function get_server_info(members, uuid, uri)
    local member = members[uri]
    local alias = nil
    if member and member.payload then
        alias = member.payload.alias
    end

    local ret = {
        alias = alias,
        uri = uri,
        uuid = uuid,
    }

    -- find the most fresh information
    -- among the members with given uuid
    for _, m in pairs(members) do
        if m.payload.uuid == uuid
        and m.timestamp > (member.timestamp or 0) then
            member = m
        end
    end

    if not member or member.status == 'left' then
        ret.status = 'not found'
        ret.message = 'Server uri is not in membership'
    elseif member.payload.uuid ~= nil and member.payload.uuid ~= uuid then
        ret.status = 'not found'
        ret.message = string.format('Alien uuid %q (%s)', member.payload.uuid, member.status)
    elseif member.status ~= 'alive' then
        ret.status = 'unreachable'
        ret.message = string.format('Server status is %q', member.status)
    elseif member.payload.uuid == nil then
        ret.status = 'unconfigured'
        ret.message = member.payload.error or member.payload.warning or ''
    elseif member.payload.error ~= nil then
        ret.status = 'error'
        ret.message = member.payload.error
    elseif member.payload.warning ~= nil then
        ret.status = 'warning'
        ret.message = member.payload.warning
    else
        ret.status = 'healthy'
        ret.message = ''
    end

    if member and member.uri ~= nil then
        members[member.uri] = nil
    end

    return ret
end

local function get_servers_and_replicasets()
    local members = membership.members()

    local servers = {}
    local replicasets = {}

    for _it, instance_uuid, server in fun.filter(topology.not_expelled, topology.get()) do
        local srv = get_server_info(members, instance_uuid, server.uri)

        srv.replicaset = replicasets[server.replicaset_uuid] or {
            uuid = server.replicaset_uuid,
            roles = server.roles,
            status = 'healthy',
            servers = {},
        }

        if srv.status ~= 'healthy' then
            srv.replicaset.status = 'unhealthy'
        end
        table.insert(srv.replicaset.servers, srv)

        servers[instance_uuid] = srv
        replicasets[server.replicaset_uuid] = srv.replicaset
    end

    for _, m in pairs(members) do
        if (m.status == 'alive') and (m.payload.uuid == nil) then
            table.insert(servers, {
                uri = m.uri,
                uuid = '',
                status = 'unconfigured',
                message = m.payload.error or m.payload.warning or '',
                alias = m.payload.alias
            })
        end
    end

    return servers, replicasets
end

local function get_self()
    local myself = membership.myself()
    local result = {
        alias = myself.payload.alias,
        uri = myself.uri,
        uuid = nil,
    }
    if type(box.cfg) ~= 'function' then
        result.uuid = box.info.uuid
    end
    return result
end

local function get_servers(uuid)
    checks('?string')

    local ret = {}
    local servers, _ = get_servers_and_replicasets()
    if uuid then
        table.insert(ret, servers[uuid])
    else
        for k, v in pairs(servers) do
            table.insert(ret, v)
        end
    end
    return ret
end

local function get_replicasets(uuid)
    checks('?string')

    local ret = {}
    local _, replicasets = get_servers_and_replicasets()
    if uuid then
        table.insert(ret, replicasets[uuid])
    else
        for k, v in pairs(replicasets) do
            table.insert(ret, v)
        end
    end
    return ret
end

local function apply_topology(servers)
    local conf, err = confapplier.get_current()
    if not conf then
        return nil, err
    end

    conf.servers = servers

    local ok, err = confapplier.clusterwide(conf)
    if not ok then
        return nil, err
    end

    return true
end

local function probe_server(uri)
    checks('string')
    local ok, err = membership.probe_uri(uri)
    if not ok then
        return nil, e_probe_server:new('Probe %q failed: %s', uri, err)
    end

    return true
end

local function join_server(args)
    checks({
        uri = 'string',
        instance_uuid = '?string',
        replicaset_uuid = '?string',
        roles = '?table',
    })

    local servers = topology.get()

    if args.instance_uuid == nil then
        args.instance_uuid = uuid_lib.str()
    elseif servers[args.instance_uuid] ~= nil then
        return nil, e_topology_edit:new(
            'servers[%s] is already joined',
            args.instance_uuid
        )
    end

    local replicaset_roles = nil
    if args.replicaset_uuid == nil then
        args.replicaset_uuid = uuid_lib.str()
    else
        for _it, instance_uuid, server in fun.filter(topology.not_expelled, servers) do
            if server.replicaset_uuid == args.replicaset_uuid then
                replicaset_roles = server.roles
                break
            end
        end
    end

    if replicaset_roles and args.roles ~= nil then
        return nil, e_topology_edit:new(
            'join_server() can not edit existing replicaset'
        )
    elseif not replicaset_roles and args.roles == nil then
        return nil, e_topology_edit:new(
            'join_server() missing roles for new replicaset'
        )
    end

    -- This case should work when we are bootstrapping first instance
    -- from the web UI
    if next(servers) == nil then
        -- TODO: we call bootstrap here, because we don't know workdir passed
        --       as command line arg. Make it accessible then refactor to
        --       'ib-common.bootstrap' module
        if args.uri == membership.myself().uri then
            return package.loaded['cluster'].bootstrap(
                args.roles,
                {
                    instance_uuid = args.instance_uuid,
                    replicaset_uuid = args.replicaset_uuid,
                }
            )
        else
            return nil, e_topology_edit:new(
                'invalid attempt to call join_server()' ..
                ' on instance which is not bootstrapped yet'
            )
        end
    else
        servers[args.instance_uuid] = {
            uri = args.uri,
            replicaset_uuid = args.replicaset_uuid,
            roles = replicaset_roles or args.roles,
        }

        local ok, err = apply_topology(servers)
        if not ok then
            return nil, err
        end

        return true
    end
end

local function edit_server(args)
    checks({
        uuid = 'string',
        uri = 'string',
    })

    local servers = topology.get()

    if servers[args.uuid] == nil then
        return nil, e_topology_edit:new('server %q not in config', args.uuid)
    elseif servers[args.uuid] == "expelled" then
        return nil, e_topology_edit:new('servers[%s] is expelled', args.uuid)
    end

    servers[args.uuid].uri = args.uri

    local ok, err = apply_topology(servers)
    if not ok then
        return nil, err
    end

    return true
end

local function expell_server(uuid)
    checks('string')

    local servers = topology.get()

    if servers[uuid] == nil then
        return nil, e_topology_edit:new('server %q not in config', uuid)
    elseif servers[uuid] == "expelled" then
        return nil, e_topology_edit:new('servers[%s] is expelled', uuid)
    end

    servers[uuid] = "expelled"

    local ok, err = apply_topology(servers)
    if not ok then
        return nil, err
    end

    return true
end

local function edit_replicaset(args)
    checks({
        uuid = 'string',
        roles = 'table',
    })

    local servers = topology.get()
    local ok = false

    for _it, instance_uuid, server in fun.filter(topology.not_expelled, servers) do
        if server.replicaset_uuid == args.uuid then
            server.roles = args.roles
            ok = true
        end
    end

    if not ok then
        return nil, e_topology_edit:new('Replicaset %q not in config', args.uuid)
    end

    local ok, err = apply_topology(servers)
    if not ok then
        return nil, err
    end

    return true
end

local function bootstrap_vshard()
    local info = vshard.router.info()

    for uid, replicasets in pairs(info.replicasets or {}) do
        local uri = replicasets.master.uri
        local conn, err = pool.connect(uri)

        if conn == nil or conn:eval('return box.space._bucket == nil') then
            return nil, e_bootstrap_vshard:new('%q not ready yet', uri)
        end
    end

    local sharding_config = topology.get_sharding_config()

    if next(sharding_config) == nil then
        return false
    end

    log.info('Bootstrapping vshard.router...')

    local ok, err = vshard.router.bootstrap({timeout=10})
    if not ok then
        return nil, e_bootstrap_vshard:new(
            '%s (%s, %s)',
            err.message, err.type, err.name
        )
    end

    return true
end

return {
    get_self = get_self,
    get_servers = get_servers,
    get_replicasets = get_replicasets,

    probe_server = probe_server,
    join_server = join_server,
    edit_server = edit_server,
    expell_server = expell_server,
    edit_replicaset = edit_replicaset,

    bootstrap_vshard = bootstrap_vshard,

    -- upload_config = upload_config,
    -- download_config = download_config,
}