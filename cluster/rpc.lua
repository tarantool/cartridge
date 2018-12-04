#!/usr/bin/env tarantool

local fun = require('fun')
local checks = require('checks')
local errors = require('errors')
local netbox = require('net.box')
local membership = require('membership')

local pool = require('cluster.pool')
local topology = require('cluster.topology')
local service_registry = require('cluster.service-registry')

local rpc_error = errors.new_class('Remote call failed')

local function call_local(role_name, fn_name, args)
    checks('string', 'string', '?table')
    local role = service_registry.get(role_name)

    if role == nil then
        return rpc_error:new('Role %q unavailable', role_name)
    end

    local fn = role[fn_name]
    if fn == nil then
        return nil, rpc_error:new('Role %q has no method %q', role_name, fn_name)
    end

    if type(args) == 'table' then
        return fn(unpack(args))
    else
        return fn()
    end
end

local function get_candidates(role_name, opts)
    opts = opts or {}
    checks('string', {
        leader_only = '?boolean',
    })

    local servers = topology.get().servers
    local replicasets = topology.get().replicasets
    local active_leaders
    if opts.leader_only then
        active_leaders = topology.get_active_masters()
    end

    local candidates = {}
    for _, instance_uuid, server in fun.filter(topology.not_disabled, servers) do
        local replicaset_uuid = server.replicaset_uuid
        local replicaset = replicasets[replicaset_uuid]
        local member = membership.get_member(server.uri)

        if replicaset.roles[role_name]
        and (member ~= nil)
        and (member.status == 'alive')
        and (member.payload.uuid == instance_uuid)
        and (member.payload.error == nil)
        and (not opts.leader_only or active_leaders[replicaset_uuid] == instance_uuid)
        then
            table.insert(candidates, server.uri)
            candidates[server.uri] = true
        end
    end

    if next(candidates) == nil then
        return nil, rpc_error:new('No remotes with role %q available', role_name)
    end
    return candidates
end

local function get_connection(role_name, opts)
    opts = opts or {}
    checks('string', {
        remote_only = '?boolean',
        leader_only = '?boolean',
    })

    local candidates, err = get_candidates(role_name, {leader_only = opts.leader_only})
    if not candidates then
        return nil, err
    end

    local myself = membership.myself()
    if not opts.remote_only and candidates[myself.uri] then
        return netbox.self
    end

    local conn, err
    local num_candidates = #candidates
    while conn == nil and num_candidates > 0 do
        local n = math.random(num_candidates)
        local uri = table.remove(candidates, n)
        num_candidates = num_candidates - 1

        if uri == myself.uri then
            conn, err = netbox.self, nil
        else
            conn, err = pool.connect(uri)
        end
    end

    if conn == nil then
        return nil, err
    end

    return conn
end

local function call_remote(role_name, fn_name, args, opts)
    opts = opts or {}
    checks('string', 'string', '?table', {
        remote_only = '?boolean',
        leader_only = '?boolean',
        timeout = '?', -- from net.box
        buffer = '?', -- from net.box
    })

    local conn, err = get_connection(role_name, {
        remote_only = opts.remote_only,
        leader_only = opts.leader_only,
    })
    if not conn then
        return nil, err
    end

    if conn == netbox.self then
        return call_local(role_name, fn_name, args)
    else
        return errors.netbox_call(
            conn,
            '_G.__cluster_rpc_call_local',
            {role_name, fn_name, args},
            {
                timeout = opts.timeout,
                buffer = opts.buffer,
            }
        )
    end
end

_G.__cluster_rpc_call_local = call_local

return {
    __get_candidates = get_candidates,
    __get_connection = get_connection,
    call = call_remote,
}
