#!/usr/bin/env tarantool
-- luacheck: ignore _it

-- this module incorporates information about
-- conf.servers and membership status

local fun = require('fun')
-- local log = require('log')
local checks = require('checks')
local errors = require('errors')
local membership = require('membership')

local vars = require('cartridge.vars').new('cartridge.topology')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local label_utils = require('cartridge.label-utils')

local e_config = errors.new_class('Invalid cluster topology config')
vars:new('known_roles', {
    -- [role_name] = true/false,
})
-- vars:new('topology', {
--     auth = false,
--     failover = false,
--     servers = {
--         -- ['instance-uuid-1'] = 'expelled',
--         -- ['instance-uuid-2'] = {
--         --     uri = 'localhost:3301',
--         --     disabled = false,
--         --     replicaset_uuid = 'replicaset-uuid-2',
--         -- },
--     },
--     replicasets = {
--         -- ['replicaset-uuid-2'] = {
--         --     roles = {
--         --         ['role-1'] = true,
--         --         ['role-2'] = true,
--         --     },
--         --     master = 'instance-uuid-2' -- old format, still compatible
--         --     master = {'instance-uuid-2', 'instance-uuid-1'} -- new format
--         --     weight = 1.0,
--         --     vshard_group = 'group_name',
--         -- }
--     },
-- })

-- to be used in fun.filter
local function not_expelled(_, srv)
    return srv ~= 'expelled'
end

local function not_disabled(uuid, srv)
    return not_expelled(uuid, srv) and not srv.disabled
end

--- Get full list of replicaset leaders.
--
-- Full list is composed of:
--  1. New order array
--  2. Initial order from topology_cfg (with no repetitions)
--  3. All other servers in the replicaset, sorted by uuid, ascending
--
-- Neither initial nor new order is modified.
-- It's validity is ignored too.
--
-- @function get_leaders_orded
-- @local
-- @treturn {string,...} array of leaders uuids
local function get_leaders_order(topology_cfg, replicaset_uuid, new_order)
    checks('table', 'string', 'nil|table')

    local servers = topology_cfg.servers
    local replicasets = topology_cfg.replicasets
    local ret = table.copy(new_order) or {}

    local replicaset = replicasets and replicasets[replicaset_uuid]

    if replicaset ~= nil then
        local initial_order
        if type(replicaset.master) == 'table' then
            initial_order = replicaset.master
        else
            initial_order = {replicaset.master}
        end

        for _, uuid in ipairs(initial_order) do
            if not utils.table_find(ret, uuid) then
                table.insert(ret, uuid)
            end
        end
    else
        error('Inconsistent topology and uuid args provided')
    end

    if servers ~= nil then
        local ret_tail = {}
        for _, instance_uuid, server in fun.filter(not_expelled, servers) do
            if server.replicaset_uuid == replicaset_uuid then
                if not utils.table_find(ret, instance_uuid) then
                    table.insert(ret_tail, instance_uuid)
                end
            end
        end

        table.sort(ret_tail)
        utils.table_append(ret, ret_tail)
    end

    return ret
end

local function validate_schema(field, topology)
    checks('string', 'table')
    local servers = topology.servers or {}
    local replicasets = topology.replicasets or {}

    e_config:assert(
        topology.auth == nil or type(topology.auth) == 'boolean',
        '%s.auth must be boolean, got %s', field, type(topology.auth)
    )

    e_config:assert(
        topology.failover == nil or type(topology.failover) == 'boolean',
        '%s.failover must be boolean, got %s', field, type(topology.failover)
    )

    e_config:assert(
        type(servers) == 'table',
        '%s.servers must be a table, got %s', field, type(servers)
    )

    e_config:assert(
        type(replicasets) == 'table',
        '%s.replicasets must be a table, got %s', field, type(replicasets)
    )

    for instance_uuid, server in pairs(servers) do
        e_config:assert(
            type(instance_uuid) == 'string',
            '%s.servers must have string keys', field
        )
        e_config:assert(
            _G.checkers.uuid_str(instance_uuid),
            '%s.servers key %q is not a valid UUID', field, instance_uuid
        )

        local field = string.format('%s.servers[%s]', field, instance_uuid)

        if not_expelled(instance_uuid, server) then

            e_config:assert(
                type(server) == 'table',
                '%s must be either a table or the string "expelled"', field
            )
            e_config:assert(
                type(server.uri) == 'string',
                '%s.uri must be a string, got %s', field, type(server.uri)
            )
            e_config:assert(
                type(server.disabled or false) == 'boolean',
                '%s.disabled must be true or false', field
            )
            e_config:assert(
                type(server.replicaset_uuid) == 'string',
                '%s.replicaset_uuid must be a string, got %s', field, type(server.replicaset_uuid)
            )
            e_config:assert(
                _G.checkers.uuid_str(server.replicaset_uuid),
                '%s.replicaset_uuid %q is not a valid UUID', field, server.replicaset_uuid
            )

            label_utils.validate_labels(field, server)

            local known_keys = {
                ['uri'] = true,
                ['disabled'] = true,
                ['replicaset_uuid'] = true,
                ['labels'] = true
            }
            for k, _ in pairs(server) do
                e_config:assert(
                    known_keys[k],
                    '%s has unknown parameter %q', field, k
                )
            end
        end
    end

    for replicaset_uuid, replicaset in pairs(replicasets) do
        e_config:assert(
            type(replicaset_uuid) == 'string',
            '%s.replicasets must have string keys', field
        )
        e_config:assert(
            _G.checkers.uuid_str(replicaset_uuid),
            '%s.replicasets key %q is not a valid UUID', field, replicaset_uuid
        )

        local field = string.format('%s.replicasets[%s]', field, replicaset_uuid)

        e_config:assert(
            type(replicaset) == 'table',
            '%s must be a table', field
        )

        e_config:assert(
            type(replicaset.master) == 'string' or type(replicaset.master) == 'table',
            '%s.master must be either string or table, got %s', field, type(replicaset.master)
        )
        if type(replicaset.master) == 'table' then
            local i = 1
            local leaders_order = replicaset.master
            local leaders_seen = {}
            for k, _ in pairs(leaders_order) do
                e_config:assert(
                    type(k) == 'number',
                    '%s.master must have integer keys', field
                )
                e_config:assert(
                    type(leaders_order[i]) == 'string',
                    '%s.master must be a contiguous array of strings', field
                )
                e_config:assert(
                    not leaders_seen[leaders_order[i]],
                    "%s.master values mustn't repeat", field
                )
                leaders_seen[leaders_order[i]] = true
                i = i + 1
            end
        end

        e_config:assert(
            type(replicaset.roles) == 'table',
            '%s.roles must be a table, got %s', field, type(replicaset.roles)
        )

        e_config:assert(
            (replicaset.alias == nil) or (type(replicaset.alias) == 'string'),
            '%s.alias must be a string, got %s', field, type(replicaset.alias)
        )

        e_config:assert(
            (replicaset.weight == nil) or (type(replicaset.weight) == 'number'),
            '%s.weight must be a number, got %s', field, type(replicaset.weight)
        )

        e_config:assert(
            (replicaset.vshard_group == nil) or (type(replicaset.vshard_group) == 'string'),
            '%s.vshard_group must be a string, got %s', field, type(replicaset.vshard_group)
        )

        for k, v in pairs(replicaset.roles) do
            e_config:assert(
                type(k) == 'string',
                '%s.roles must have string keys', field
            )
            e_config:assert(
                type(v) == 'boolean',
                '%s.roles[%q] must be true or false', field, k
            )
        end

        e_config:assert(
            (replicaset.all_rw == nil) or (type(replicaset.all_rw) == 'boolean'),
            '%s.all_rw must be a boolean, got %s', field, type(replicaset.all_rw)
        )

        local known_keys = {
            ['roles'] = true,
            ['master'] = true,
            ['weight'] = true,
            ['vshard_group'] = true,
            ['all_rw'] = true,
            ['alias'] = true,
        }
        for k, _ in pairs(replicaset) do
            e_config:assert(
                known_keys[k],
                '%s has unknown parameter %q', field, k
            )
        end
    end

    local known_keys = {
        ['servers'] = true,
        ['replicasets'] = true,
        ['failover'] = true,
        ['auth'] = true,
    }
    for k, _ in pairs(topology) do
        e_config:assert(
            known_keys[k],
            '%s has unknown parameter %q', field, k
        )
    end
end

local function validate_consistency(topology)
    checks('table')
    local servers = topology.servers or {}
    local replicasets = topology.replicasets or {}
    local known_uuids = {}

    for _it, instance_uuid, server in fun.filter(not_expelled, servers) do
        local field = string.format('servers[%s]', instance_uuid)
        e_config:assert(
            replicasets[server.replicaset_uuid] ~= nil,
            '%s.replicaset_uuid is not configured in replicasets table',
            field
        )
        known_uuids[server.replicaset_uuid] = true
    end

    for replicaset_uuid, _ in pairs(replicasets) do
        local field = string.format('replicasets[%s]', replicaset_uuid)

        e_config:assert(
            known_uuids[replicaset_uuid],
            '%s has no servers', field
        )

        local leaders_order = get_leaders_order(topology, replicaset_uuid)
        for _, leader_uuid in ipairs(leaders_order) do
            local leader = servers[leader_uuid]
            e_config:assert(
                leader ~= nil,
                "%s leader %q doesn't exist", field, leader_uuid
            )
            e_config:assert(
                not_expelled(leader_uuid, leader),
                "%s leader %q can't be expelled", field, leader_uuid
            )
            e_config:assert(
                leader.replicaset_uuid == replicaset_uuid,
                '%s leader %q belongs to another replicaset', field, leader_uuid
            )
        end
    end
end


local function validate_availability(topology)
    checks('table')
    local servers = topology.servers or {}

    for _it, instance_uuid, server in fun.filter(not_disabled, servers) do
        local member = membership.get_member(server.uri)
        e_config:assert(
            member ~= nil,
            'Server %q is not in membership', server.uri
        )
        e_config:assert(
            member.status == 'alive',
            'Server %q is unreachable with status %q',
            server.uri, member.status
        )
        e_config:assert(
            (member.payload.uuid == nil) or (member.payload.uuid == instance_uuid),
            'Server %q bootstrapped with different uuid %q',
            server.uri, member.payload.uuid
        )
        e_config:assert(
            member.payload.error == nil,
            'Server %q has error: %s',
            server.uri, member.payload.error
        )
    end

    local myself = membership.myself()
    local myself_uuid = myself.payload.uuid
    if myself_uuid ~= nil then
        local srv = topology.servers and topology.servers[myself_uuid]
        e_config:assert(
            srv ~= nil,
            'Current instance %q is not listed in config', myself.uri
        )
        e_config:assert(
            not_expelled(myself_uuid, srv),
            'Current instance %q can not be expelled', myself.uri
        )
        e_config:assert(
            not_disabled(myself_uuid, srv),
            'Current instance %q can not be disabled', myself.uri
        )
    end
end

local function validate_upgrade(topology_new, topology_old)
    checks('table', 'table')
    local servers_new = topology_new.servers or {}
    local servers_old = topology_old.servers or {}
    local replicasets_new = topology_new.replicasets or {}
    local replicasets_old = topology_old.replicasets or {}

    -- validate that nobody was removed from previous config
    -- luacheck: ignore server_old
    for instance_uuid, server_old in pairs(servers_old) do
        local server_new = servers_new[instance_uuid]
        e_config:assert(
            server_new ~= nil,
            'servers[%s] can not be removed from config', instance_uuid
        )
    end

    for _it, instance_uuid, server_new in fun.filter(not_expelled, servers_new) do
        local field = string.format('servers[%s]', instance_uuid)
        local server_old = servers_old[instance_uuid]

        if server_old then
            e_config:assert(
                not_expelled(instance_uuid, server_old),
                '%s has been expelled earlier', field
            )
            e_config:assert(
                server_old.replicaset_uuid == server_new.replicaset_uuid,
                '%s.replicaset_uuid can not be changed', field
            )
        end
    end

    for replicaset_uuid, replicaset_new in pairs(replicasets_new) do
        local replicaset_old = replicasets_old[replicaset_uuid]
        for role, enabled_new in pairs(replicaset_new.roles) do
            local enabled_old = replicaset_old and replicaset_old.roles[role]
            if enabled_new and not enabled_old then
                e_config:assert(
                    vars.known_roles[role],
                    'replicasets[%s] can not enable unknown role %q',
                    replicaset_uuid, tostring(role)
                )
            end
        end
    end
end

local function validate(topology_new, topology_old)
    topology_old = topology_old or {}
    e_config:assert(
        type(topology_new) == 'table',
        'topology_new must be a table, got %s', type(topology_new)
    )
    e_config:assert(
        type(topology_old) == 'table',
        'topology_old must be a table, got %s', type(topology_old)
    )

    validate_schema('topology_old', topology_old)
    validate_schema('topology_new', topology_new)
    validate_consistency(topology_new)
    validate_availability(topology_new)
    validate_upgrade(topology_new, topology_old)

    return true
end

local function find_server_by_uri(topology_cfg, uri)
    checks('table', 'string')
    assert(topology_cfg.__type ~= 'ClusterwideConfig')

    if topology_cfg.servers == nil then
        return nil
    end

    for _it, instance_uuid, server in fun.filter(not_expelled, topology_cfg.servers) do
        if server.uri == uri then
            return instance_uuid, server
        end
    end

    return nil
end

local function cluster_is_healthy()
    local confapplier = require('cartridge.confapplier')
    if confapplier.get_state() ~= 'RolesConfigured' then
        return nil, confapplier.get_state()
    end

    local topology_cfg = confapplier.get_readonly('topology')

    for _it, instance_uuid, server in fun.filter(not_disabled, topology_cfg.servers) do
        local member = membership.get_member(server.uri) or {}

        if (member.status ~= 'alive') then
            return nil, string.format(
                '%s status is %s',
                server.uri, member.status
            )
        elseif (member.payload.uuid ~= instance_uuid) then
            return nil, string.format(
                '%s uuid mismatch: expected %s, have %s',
                server.uri, instance_uuid, member.payload.uuid
            )
        elseif (member.payload.error ~= nil) then
            return nil, string.format(
                '%s: %s',
                server.uri, member.payload.error
            )
        end
    end

    return true
end

--- Send UDP ping to servers missing from membership table.
-- @function probe_missing_members
-- @local
-- @tparam table servers
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function probe_missing_members(servers)
    local err = nil
    for _, _, srv in fun.filter(not_disabled, servers) do
        if membership.get_member(srv.uri) == nil then
            local _, _err = membership.probe_uri(srv.uri)
            if _err ~= nil then
                err = errors.new(
                    'ProbeError',
                    'Probe %q failed: %s', srv.uri, _err
                )
            end
        end
    end

    if err ~= nil then
        return nil, err
    end

    return true
end

local function get_fullmesh_replication(topology_cfg, replicaset_uuid)
    checks('table', 'string')
    assert(topology_cfg.__type ~= 'ClusterwideConfig')
    assert(topology_cfg.servers ~= nil)

    local replication = {}

    for _it, _, server in fun.filter(not_disabled, topology_cfg.servers) do
        if server.replicaset_uuid == replicaset_uuid then
            table.insert(replication, pool.format_uri(server.uri))
        end
    end

    table.sort(replication)
    return replication
end

return {
    validate = function(...)
        return e_config:pcall(validate, ...)
    end,
    add_known_role = function(role_name)
        vars.known_roles[role_name] = true
    end,

    not_expelled = not_expelled,
    not_disabled = not_disabled,

    get_leaders_order = get_leaders_order,
    cluster_is_healthy = cluster_is_healthy,
    probe_missing_members = probe_missing_members,

    find_server_by_uri = find_server_by_uri,
    get_fullmesh_replication = get_fullmesh_replication,
}
