#!/usr/bin/env tarantool

--- Remote procedure calls between cluster instances.
--
-- @module cartridge.rpc

local fun = require('fun')
local checks = require('checks')
local errors = require('errors')
local netbox = require('net.box')
local membership = require('membership')

local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')
local service_registry = require('cartridge.service-registry')

local rpc_error = errors.new_class('Remote call failed')

local function call_local(role_name, fn_name, args)
    checks('string', 'string', '?table')
    local role = service_registry.get(role_name)

    if role == nil then
        return nil, rpc_error:new('Role %q unavailable', role_name)
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

local function member_is_healthy(uri, instance_uuid)
    local member = membership.get_member(uri)
    return (
        (member ~= nil)
        and (member.status == 'alive')
        and (member.payload.uuid == instance_uuid)
        and (member.payload.error == nil)
    )
end


--- List instances suitable for performing a remote call.
--
-- @function get_candidates
--
-- @tparam string role_name
-- @tparam[opt] table opts
-- @tparam ?boolean opts.leader_only
--   Filter instances which are leaders now.
--   (default: **false**)
-- @tparam ?boolean opts.healthy_only
--   Filter instances which have membership status healthy.
--   (added in v1.1.0-11, default: **true**)
--
-- @treturn[1] {string,...} URIs
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_candidates(role_name, opts)
    opts = opts or {}
    if opts.healthy_only == nil then
        opts.healthy_only = true
    end

    checks('string', {
        leader_only = '?boolean',
        healthy_only = '?boolean'
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

        if confapplier.get_enabled_roles(replicaset.roles)[role_name]
        and (not opts.healthy_only or member_is_healthy(server.uri, instance_uuid))
        and (not opts.leader_only or active_leaders[replicaset_uuid] == instance_uuid)
        then
            table.insert(candidates, server.uri)
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
-- @tparam ?boolean opts.prefer_local
-- @tparam ?boolean opts.leader_only
--
-- @return[1] `net.box` connection
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_connection(role_name, opts)
    opts = opts or {}
    checks('string', {
        prefer_local = '?boolean',
        leader_only = '?boolean',
    })

    local candidates, err = get_candidates(role_name, {leader_only = opts.leader_only})
    if not candidates then
        return nil, err
    end

    local prefer_local = opts.prefer_local
    if prefer_local == nil then
        prefer_local = true
    end

    local myself = membership.myself()
    local uri_exists = utils.table_find(candidates, myself.uri)
    if prefer_local and uri_exists then
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
-- @tparam ?boolean opts.prefer_local
--   Don't perform a remote call if possible.
--   (default: **true**)
-- @tparam ?boolean opts.leader_only
--   Perform a call only on the replica set leaders.
--   (default: **false**)
-- @param opts.remote_only (*deprecated*) Use `prefer_local` instead.
-- @param opts.timeout passed to `net.box` `conn:call` options.
-- @param opts.buffer passed to `net.box` `conn:call` options.
--
-- @return[1] `conn:call()` result
-- @treturn[2] nil
-- @treturn[2] table Error description
local function call_remote(role_name, fn_name, args, opts)
    opts = opts or {}
    checks('string', 'string', '?table', {
        prefer_local = '?boolean',
        leader_only = '?boolean',
        remote_only = '?boolean', -- deprecated
        timeout = '?', -- for net.box.call
        buffer = '?', -- for net.box.call
    })

    local prefer_local
    if opts.remote_only ~= nil then
        errors.deprecate('Option "remote_only" is deprecated, use "prefer_local" instead')
        prefer_local = not opts.remote_only
    end

    if opts.prefer_local ~= nil then
        prefer_local = opts.prefer_local
    end

    if prefer_local == nil then
        prefer_local = true
    end

    local leader_only = opts.leader_only
    if leader_only == nil then
        leader_only = false
    end

    local conn, err = get_connection(role_name, {
        prefer_local = prefer_local,
        leader_only = leader_only,
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
