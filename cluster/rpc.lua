#!/usr/bin/env tarantool

--- Remote procedure calls between cluster instances.
--
-- @module cluster.rpc

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
        return fn(unpack(args, 1, table.maxn(args)))
    else
        return fn()
    end
end

--- List instances suitable for performing a remote call.
--
-- @function get_candidates
-- @local
--
-- @tparam string role_name
-- @tparam[opt] table opts
-- @tparam boolean opts.leader_only
--
-- @treturn[1] table with URIs
-- @treturn[2] nil
-- @treturn[2] table Error description
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

--- Connect to an instance with an enabled role.
--
-- @function get_connection
-- @local
--
-- @tparam string role_name
-- @tparam[opt] table opts
-- @tparam boolean opts.remote_only
-- @tparam boolean opts.leader_only
--
-- @return[1] `net.box` connection
-- @treturn[2] nil
-- @treturn[2] table Error description
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

--- Perform a remote procedure call.
-- Find a suitable healthy instance with an enabled role and
-- perform a [`net.box` `conn:call`](
-- https://tarantool.io/en/doc/latest/reference/reference_lua/net_box/#net-box-call)
-- on it.
--
-- @function call
--
-- @tparam string role_name
-- @tparam string fn_name
-- @tparam[opt] table args
-- @tparam[opt] table opts
-- @tparam boolean opts.remote_only Always try to call a remote host
-- even if the role is enabled locally.
-- @tparam boolean opts.leader_only Perform a call only on the replica set leaders.
-- @param opts.timeout passed to `net.box` `conn:call` options.
-- @param opts.buffer passed to `net.box` `conn:call` options.
--
-- @return[1] `conn:call()` result
-- @treturn[2] nil
-- @treturn[2] table Error description
local function call_remote(role_name, fn_name, args, opts)
    opts = opts or {}
    checks('string', 'string', '?table', {
        remote_only = '?boolean',
        leader_only = '?boolean',
        timeout = '?', -- for net.box.call
        buffer = '?', -- for net.box.call
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
    get_candidates = get_candidates,
    get_connection = get_connection,
    call = call_remote,
}
