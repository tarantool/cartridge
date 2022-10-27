--- Remote procedure calls between cluster instances.
--
-- @module cartridge.rpc

local fun = require('fun')
local checks = require('checks')
local json = require('json')
local errors = require('errors')
local netbox = require('net.box')
local membership = require('membership')

local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local roles = require('cartridge.roles')
local topology = require('cartridge.topology')
local failover = require('cartridge.failover')
local confapplier = require('cartridge.confapplier')
local twophase = require('cartridge.twophase')
local service_registry = require('cartridge.service-registry')
local label_utils = require('cartridge.label-utils')

local RemoteCallError = errors.new_class('RemoteCallError')

local function call_local(role_name, fn_name, args)
    checks('string', 'string', '?table')
    local role = service_registry.get(role_name)

    if role == nil then
        -- Optimistic approach.
        -- Probably instance in apply config state so
        -- we need to wait a bit until it finishes.
        if twophase.wait_config_release()
        and confapplier.wish_state('RolesConfigured') == 'RolesConfigured' then
            role = service_registry.get(role_name)
        end
    end

    if role == nil then
        return nil, RemoteCallError:new('Role %q unavailable', role_name)
    end

    local fn = role[fn_name]
    if fn == nil then
        return nil, RemoteCallError:new('Role %q has no method %q', role_name, fn_name)
    end

    if type(args) == 'table' then
        return RemoteCallError:pcall(fn, unpack(args, 1, table.maxn(args)))
    else
        return RemoteCallError:pcall(fn)
    end
end

local function member_is_healthy(uri, instance_uuid)
    local member = membership.get_member(uri)
    return (
        (member ~= nil)
        and (member.status == 'alive' or member.status == 'suspect')
        and (member.payload.uuid == instance_uuid)
        and (
            member.payload.state_prev == nil or -- for backward compatibility with old versions
            member.payload.state_prev == 'RolesConfigured' or
            member.payload.state_prev == 'ConfiguringRoles'
        )
        and (
            member.payload.state == 'ConfiguringRoles' or
            member.payload.state == 'RolesConfigured'
        )
    )
end


--- List candidates suitable for performing a remote call.
-- Candidates are deduced from a local config and membership, which may
-- differ from replica to replica (e.g. during `patch_clusterwide`). It
-- may produce invalid candidates.
--
-- @function get_candidates
--
-- @tparam string role_name
-- @tparam[opt] table opts
-- @tparam ?boolean opts.leader_only
--   Filter instances which are leaders now.
--   (default: **false**)
-- @tparam ?boolean opts.healthy_only
--   The member is considered healthy if
--   it reports either `ConfiguringRoles` or `RolesConfigured` state
--   and its SWIM status is either `alive` or `suspect`
--   (added in v1.1.0-11, default: **true**)
-- @tparam ?table opts.labels
--   Filter instances that have the specified labels. Adding labels is possible via the
--   edit_topology method or via graphql
--   Example: rpc.get_candidates('role', { labels = {['msk'] = 'dc'} })
--
-- @treturn[1] {string,...} URIs
local function get_candidates(role_name, opts)
    opts = opts or {}
    if opts.healthy_only == nil then
        opts.healthy_only = true
    end

    checks('string', {
        leader_only = '?boolean',
        healthy_only = '?boolean',
        labels = '?table'
    })

    local topology_cfg = confapplier.get_readonly('topology')
    if topology_cfg == nil then
        return {}
    end

    local servers = assert(topology_cfg.servers)
    local replicasets = assert(topology_cfg.replicasets)
    local active_leaders
    if opts.leader_only then
        active_leaders = failover.get_active_leaders()
    end

    local candidates = {}
    for _, instance_uuid, server in fun.filter(topology.not_disabled, servers) do
        local replicaset_uuid = server.replicaset_uuid
        local replicaset = replicasets[replicaset_uuid]

        if roles.get_enabled_roles(replicaset.roles)[role_name]
        and (not opts.healthy_only or member_is_healthy(server.uri, instance_uuid))
        and (not opts.leader_only or active_leaders[replicaset_uuid] == instance_uuid)
        and (not opts.labels or label_utils.labels_match(opts.labels, server.labels))
        then
            table.insert(candidates, server.uri)
        end
    end

    return candidates
end

--- Connect to an instance with an enabled role.
-- Candidates to connect are deduced from a local config and membership,
-- which may differ from replica to replica (e.g. during `patch_clusterwide`).
-- It may produce invalid candidates.
--
-- @function get_connection
-- @local
--
-- @tparam string role_name
-- @tparam[opt] table opts
-- @tparam ?boolean opts.prefer_local
-- @tparam ?boolean opts.leader_only
-- @tparam ?table opts.labels
--
-- @return[1] `net.box` connection
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_connection(role_name, opts)
    opts = opts or {}
    checks('string', {
        prefer_local = '?boolean',
        leader_only = '?boolean',
        labels = '?table',
    })

    local candidates = get_candidates(role_name, {leader_only = opts.leader_only, labels = opts.labels})
    if next(candidates) == nil then
        if opts.labels then
            return nil, RemoteCallError:new('No remotes with role %q and labels %s available',
                role_name, json.encode(opts.labels))
        end
        return nil, RemoteCallError:new('No remotes with role %q available', role_name)
    end

    local prefer_local = opts.prefer_local
    if prefer_local == nil then
        prefer_local = true
    end

    local myself = membership.myself()
    if prefer_local and utils.table_find(candidates, myself.uri) then
        return netbox.self
    end

    local uri, conn
    local num_candidates = #candidates
    repeat
        local n = math.random(num_candidates)
        num_candidates = num_candidates - 1

        uri = table.remove(candidates, n)
        conn = pool.connect(uri, {wait_connected = false})
    until conn:wait_connected() or num_candidates == 0

    if not conn:is_connected() then
        return nil, RemoteCallError:new('%q: %s',
            uri, conn.error or "Connection not established (yet)"
        )
    end

    return conn
end

--- Perform a remote procedure call.
-- Find a suitable healthy instance with an enabled role and
-- perform a [`net.box` `conn:call`](
-- https://tarantool.io/en/doc/latest/reference/reference_lua/net_box/#net-box-call)
-- on it. `rpc.call()` can only be used for functions defined in role return table
-- unlike `net.box` `conn:call()`, which is used for global functions as well.
--
-- @usage
--    -- myrole.lua
--    return {
--        role_name = 'myrole',
--        add = function(a, b) return a + b end,
--    }
--
-- @usage
--    -- call it as follows:
--    cartridge.rpc_call('myrole', 'add', {2, 2}) -- returns 4
--
-- @function call
--
-- @tparam string role_name
-- @tparam string fn_name
-- @tparam[opt] table args
-- @tparam[opt] table opts
-- @tparam ?boolean opts.prefer_local
--   Don't perform a remote call if possible. When the role is enabled
--   locally and current instance is healthy the remote netbox call is
--   substituted with a local Lua function call. When the option is
--   disabled it never tries to perform call locally and always uses
--   netbox connection, even to connect self.
--   (default: **true**)
-- @tparam ?boolean opts.leader_only
--   Perform a call only on the replica set leaders.
--   (default: **false**)
-- @tparam ?string opts.uri
--   Force a call to be performed on this particular uri.
--   Disregards member status and `opts.prefer_local`.
--   Conflicts with `opts.leader_only = true`.
--   (added in v1.2.0-63)
-- @tparam ?table opts.labels
--   Filter instances that have the specified labels. Adding labels is possible via the
--   edit_topology method or via graphql.
--   Example: rpc.call('role', 'func', {}, { labels = { ['msk'] = 'dc' } })
-- @param opts.remote_only (*deprecated*) Use `prefer_local` instead.
-- @param opts.timeout passed to `net.box` `conn:call` options.
-- @param opts.buffer passed to `net.box` `conn:call` options.
-- @param opts.on_push passed to `net.box` `conn:call` options.
-- @param opts.on_push_ctx passed to `net.box` `conn:call` options.
--
-- @return[1] `conn:call()` result
-- @treturn[2] nil
-- @treturn[2] table Error description
local function call_remote(role_name, fn_name, args, opts)
    opts = opts or {}
    checks('string', 'string', '?table', {
        prefer_local = '?boolean',
        leader_only = '?boolean',
        labels = '?table',
        remote_only = '?boolean', -- deprecated
        uri = '?string',
        timeout = '?', -- for net.box.call
        buffer = '?', -- for net.box.call
        on_push = '?function', -- for net.box.call
        on_push_ctx = '?', -- for net.box.call
    })

    if opts.uri ~= nil and (opts.leader_only or opts.labels) then
        local err = "bad argument opts.uri to rpc_call" ..
            " (conflicts with opts.leader_only=true or opts.labels={...})"
        error(err, 2)
    end

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

    if (opts.on_push ~= nil or opts.on_push_ctx ~= nil) and opts.prefer_local ~= false then
        local err = "bad argument opts.on_push/opts.on_push_ctx to rpc_call" ..
            " (allowed to be used only with opts.prefer_local=false)"
        error(err, 2)
    end

    local leader_only = opts.leader_only
    if leader_only == nil then
        leader_only = false
    end

    local conn, err
    if opts.uri ~= nil then
        conn, err = pool.connect(opts.uri, {wait_connected = false})
    else
        conn, err = get_connection(role_name, {
            prefer_local = prefer_local,
            leader_only = leader_only,
            labels = opts.labels,
        })
    end

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
                on_push = opts.on_push,
                on_push_ctx = opts.on_push_ctx,
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
