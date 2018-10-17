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
    local topology_cfg = confapplier.get_current('topology')

    local servers = {}
    local replicasets = {}

    for replicaset_uuid, replicaset in pairs(topology_cfg.replicasets) do
        replicasets[replicaset_uuid] = {
            uuid = replicaset_uuid,
            roles = {},
            status = 'healthy',
            servers = {},
        }

        if replicaset.roles['vshard-router'] then
            table.insert(replicasets[replicaset_uuid].roles, 'vshard-router')
        end

        if replicaset.roles['vshard-storage'] then
            table.insert(replicasets[replicaset_uuid].roles, 'vshard-storage')
        end
    end

    for _it, instance_uuid, server in fun.filter(topology.not_expelled, topology_cfg.servers) do
        local srv = get_server_info(members, instance_uuid, server.uri)

        srv.replicaset = replicasets[server.replicaset_uuid]

        if srv.status ~= 'healthy' then
            srv.replicaset.status = 'unhealthy'
        end
        table.insert(srv.replicaset.servers, srv)

        servers[instance_uuid] = srv
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

local function apply_topology(topology)
    local conf = confapplier.get_current()
    conf.topology = topology

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

    local roles = {}
    for _, role in pairs(args.roles or {}) do
        roles[role] = true
    end

    local topology_cfg = confapplier.get_current('topology')
    if topology_cfg == nil then
        topology_cfg = {
            servers = {},
            replicasets = {},
        }
    end

    if args.instance_uuid == nil then
        args.instance_uuid = uuid_lib.str()
    elseif topology_cfg.servers[args.instance_uuid] ~= nil then
        return nil, e_topology_edit:new(
            'Server %q is already joined',
            args.instance_uuid
        )
    end

    if args.replicaset_uuid == nil then
        args.replicaset_uuid = uuid_lib.str()
    end

    -- This case should work when we are bootstrapping
    -- first instance from the web UI
    if next(topology_cfg.servers) == nil then
        if args.uri == membership.myself().uri then
            return package.loaded['cluster'].bootstrap(
                roles,
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
        topology_cfg.servers[args.instance_uuid] = {
            uri = args.uri,
            replicaset_uuid = args.replicaset_uuid,
        }
        if topology_cfg.replicasets[args.replicaset_uuid] == nil then
            topology_cfg.replicasets[args.replicaset_uuid] = {
                roles = roles,
                master = args.instance_uuid,
            }
        end

        local ok, err = apply_topology(topology_cfg)
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

    local topology_cfg = confapplier.get_current('topology')

    if topology_cfg.servers[args.uuid] == nil then
        return nil, e_topology_edit:new('Server %q not in config', args.uuid)
    elseif topology_cfg.servers[args.uuid] == "expelled" then
        return nil, e_topology_edit:new('Server %q is expelled', args.uuid)
    end

    topology_cfg.servers[args.uuid].uri = args.uri

    local ok, err = apply_topology(topology_cfg)
    if not ok then
        return nil, err
    end

    return true
end

local function expell_server(uuid)
    checks('string')

    local topology_cfg = confapplier.get_current('topology')

    if topology_cfg.servers[uuid] == nil then
        return nil, e_topology_edit:new('Server %q not in config', uuid)
    elseif topology_cfg.servers[uuid] == "expelled" then
        return nil, e_topology_edit:new('Server %q is already expelled', uuid)
    end

    local expell_replicaset = topology_cfg.servers[uuid].replicaset_uuid

    topology_cfg.servers[uuid] = "expelled"

    for _it, instance_uuid, server in fun.filter(topology.not_expelled, topology_cfg.servers) do
        if server.replicaset_uuid == expell_replicaset then
            expell_replicaset = nil
        end
    end
    if expell_replicaset ~= nil then
        topology_cfg.replicasets[expell_replicaset] = nil
    end

    local ok, err = apply_topology(topology_cfg)
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

    local topology_cfg = confapplier.get_current('topology')
    local replicaset = topology_cfg.replicasets[args.uuid]

    if replicaset == nil then
        return nil, e_topology_edit:new('Replicaset %q not in config', args.uuid)
    end

    replicaset.roles = {}
    for _, role in pairs(args.roles) do
        replicaset.roles[role] = true
    end

    local ok, err = apply_topology(topology_cfg)
    if not ok then
        return nil, err
    end

    return true
end

local function bootstrap_vshard()
    local info = vshard.router.info()

    for uid, replicaset in pairs(info.replicasets or {}) do
        local uri = replicaset.master.uri
        local conn, err = pool.connect(uri)

        if conn == nil or conn:eval('return box.space._bucket == nil') then
            return nil, e_bootstrap_vshard:new('%q not ready yet', uri)
        end
    end

    local sharding_config = topology.get_sharding_config()

    if next(sharding_config) == nil then
        return nil, e_bootstrap_vshard:new('Sharding config is empty')
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