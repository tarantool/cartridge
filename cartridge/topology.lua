-- luacheck: ignore _it

--- Topology validation and filtering.
--
-- @module cartridge.topology

local fun = require('fun')
local checks = require('checks')
local errors = require('errors')
local membership = require('membership')
local log = require('log')

local pool = require('cartridge.pool')
local roles = require('cartridge.roles')
local utils = require('cartridge.utils')
local label_utils = require('cartridge.label-utils')

local e_config = errors.new_class('Invalid cluster topology config')
--[[ topology_cfg: {
    auth = false,
    failover = nil | boolean | {
        -- mode = 'disabled' | 'eventual' | 'stateful' | 'raft',
        -- state_provider = nil | 'tarantool' | 'etcd2',
        -- failover_timeout = nil | number,
        -- tarantool_params = nil | {
        --     uri = string,
        --     password = string,
        -- },
        -- etcd2_params = nil | {
        --     prefix = nil | string,
        --     lock_delay = nil | number,
        --     endpoints = nil | {string,...},
        --     username = nil | string,
        --     password = nil | string,
        -- },
        -- fencing_enabled = nil | boolean,
        -- fencing_timeout = nil | number,
        -- fencing_pause = nil | number,
        -- leader_autoreturn = nil | boolean,
        -- autoreturn_delay = nil | number,
        -- check_cookie_hash = nil | boolean,
    },
    servers = {
        -- ['instance-uuid-1'] = 'expelled',
        -- ['instance-uuid-2'] = {
        --     uri = 'localhost:3301',
        --     disabled = false,
        --     electable = true,
        --     replicaset_uuid = 'replicaset-uuid-2',
        --     zone = nil | string,
        -- },
    },
    replicasets = {
        -- ['replicaset-uuid-2'] = {
        --     roles = {
        --         ['role-1'] = true,
        --         ['role-2'] = true,
        --     },
        --     master = 'instance-uuid-2' -- old format, still compatible
        --     master = {'instance-uuid-2', 'instance-uuid-1'} -- new format
        --     weight = 1.0,
        --     vshard_group = 'group_name',
        -- }
    },
}]]

-- to be used in fun.filter
local function expelled(_, srv)
    return srv == 'expelled'
end

local function disabled(uuid, srv)
    if expelled(uuid, srv) then
        return true
    elseif srv ~= nil then
        return srv.disabled
    end
    return false
end

local function electable(_, srv)
    if srv ~= nil and srv.electable ~= nil then
        return srv.electable
    else
        return true
    end
end

local function not_expelled(_, srv)
    return not expelled(_, srv)
end

local function not_disabled(uuid, srv)
    return not disabled(uuid, srv)
end

local function not_electable(_, srv)
    return not electable(_, srv)
end

local function every_node()
    return true
end

--- Get full list of replicaset leaders.
--
-- Full list is composed of:
--
--  1. New order array
--  2. Initial order from topology_cfg (with no repetitions)
--  3. All other servers in the replicaset, sorted by uuid, ascending
--
-- Neither `topology_cfg` nor `new_order` tables are modified.
-- New order validity is ignored too.
--
-- By default, `get_leaders_order` doesn't return unelectable nodes.
-- To fix it, use `only_electable` argument of `opts`.
--
-- By default, `get_leaders_order` returns disabled nodes.
-- To fix it, use `only_enabled` argument of `opts`.
--
-- @function get_leaders_order
-- @local
-- @tparam table topology_cfg
-- @tparam string replicaset_uuid
-- @tparam ?table new_order
-- @tparam ?table opts
-- @treturn {string,...} array of leaders uuids
local function get_leaders_order(topology_cfg, replicaset_uuid, new_order, opts)
    checks('table', 'string', '?table', '?table')

    local servers = topology_cfg.servers
    local replicasets = topology_cfg.replicasets
    local ret = table.copy(new_order) or {}

    if opts == nil then
        opts = {}
    end
    if opts.only_electable == nil then
        opts.only_electable = true
    end
    if opts.only_enabled == nil then
        opts.only_enabled = false
    end

    local replicaset = replicasets and replicasets[replicaset_uuid]

    local filter_disabled = opts.only_enabled and not_disabled or every_node
    if replicaset ~= nil then
        local initial_order
        if type(replicaset.master) == 'table' then
            initial_order = replicaset.master
        else
            initial_order = {replicaset.master}
        end

        for _, uuid in ipairs(initial_order) do
            if electable(uuid, servers[uuid])
            and filter_disabled(uuid, servers[uuid])
            and not utils.table_find(ret, uuid)
            then
                table.insert(ret, uuid)
            end
        end
    else
        error('Inconsistent topology and uuid args provided')
    end

    if servers ~= nil then
        local ret_tail = {}
        for _, instance_uuid, server in fun.filter(not_expelled, servers)
            :filter(opts.only_enabled and not_disabled or every_node)
            :filter(opts.only_electable and electable or every_node)
        do
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
        topology.failover == nil or
        type(topology.failover) == 'boolean' or
        type(topology.failover) == 'table',
        '%s.failover must be a table, got %s', field, type(topology.failover)
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
                type(server.electable or false) == 'boolean',
                '%s.electable must be true or false', field
            )
            e_config:assert(
                type(server.replicaset_uuid) == 'string',
                '%s.replicaset_uuid must be a string, got %s', field, type(server.replicaset_uuid)
            )
            e_config:assert(
                _G.checkers.uuid_str(server.replicaset_uuid),
                '%s.replicaset_uuid %q is not a valid UUID', field, server.replicaset_uuid
            )

            e_config:assert(
                server.zone == nil or
                type(server.zone) == 'string',
                '%s.zone must be a string, got %s', field, type(server.zone)
            )

            local ok, err = label_utils.validate_labels(field, server)
            if not ok then
                log.error(("Invalid labels: %s. Usage of invalid labels will be forbidden in next releases")
                    :format(err.err))
            end

            local known_keys = {
                ['uri'] = true,
                ['disabled'] = true,
                ['electable'] = true,
                ['replicaset_uuid'] = true,
                ['labels'] = true,
                ['zone'] = true,
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

        if topology.failover and topology.failover.mode == 'raft' then
            e_config:assert(not replicaset.all_rw, "Raft failover can't be enabled with ALL_RW replicasets")
        end
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

local function validate_failover_schema(field, topology)

    if type(topology.failover) == 'table' then
        e_config:assert(
            topology.failover.mode == nil or
            type(topology.failover.mode) == 'string',
            '%s.failover.mode must be string, got %s',
            field, type(topology.failover.mode)
        )
        e_config:assert(
            topology.failover.mode == nil or
            topology.failover.mode == 'disabled' or
            topology.failover.mode == 'eventual' or
            topology.failover.mode == 'stateful' or
            topology.failover.mode == 'raft',
            '%s.failover unknown mode %q',
            field, topology.failover.mode
        )

        if topology.failover.mode == 'raft' then
            local ok, err = package.loaded['cartridge.failover.raft'].check_version()
            e_config:assert(ok, err)
        end

        if topology.failover.failover_timeout ~= nil then
            e_config:assert(
                type(topology.failover.failover_timeout) == 'number',
                '%s.failover.failover_timeout must be a number, got %s',
                field, type(topology.failover.failover_timeout)
            )
            e_config:assert(
                topology.failover.failover_timeout >= 0,
                '%s.failover.failover_timeout must be non-negative, got %s',
                field, topology.failover.failover_timeout
            )
        end

        e_config:assert(
            topology.failover.fencing_enabled == nil or
            type(topology.failover.fencing_enabled) == 'boolean',
            '%s.failover.fencing_enabled must be boolean, got %s',
            field, type(topology.failover.fencing_enabled)
        )

        if topology.failover.fencing_pause ~= nil then
            e_config:assert(
                type(topology.failover.fencing_pause) == 'number',
                '%s.failover.fencing_pause must be a number, got %s',
                field, type(topology.failover.fencing_pause)
            )

            e_config:assert(
                topology.failover.fencing_pause > 0,
                '%s.failover.fencing_pause must be positive, got %s',
                field, topology.failover.fencing_pause
            )
        end

        if topology.failover.fencing_timeout ~= nil then
            e_config:assert(
                type(topology.failover.fencing_timeout) == 'number',
                '%s.failover.fencing_timeout must be a number, got %s',
                field, type(topology.failover.fencing_timeout)
            )

            e_config:assert(
                topology.failover.fencing_timeout >= 0,
                '%s.failover.fencing_timeout must be non-negative, got %s',
                field, topology.failover.fencing_timeout
            )
        end

        if topology.failover.leader_autoreturn ~= nil then
            e_config:assert(
                type(topology.failover.leader_autoreturn) == 'boolean',
                '%s.failover.leader_autoreturn must be a boolean, got %s',
                field, type(topology.failover.leader_autoreturn)
            )
        end

        if topology.failover.autoreturn_delay ~= nil then
            e_config:assert(
                type(topology.failover.autoreturn_delay) == 'number',
                '%s.failover.autoreturn_delay must be a number, got %s',
                field, type(topology.failover.autoreturn_delay)
            )

            e_config:assert(
                topology.failover.autoreturn_delay >= 0,
                '%s.failover.autoreturn_delay must be non-negative, got %s',
                field, topology.failover.autoreturn_delay
            )
        end

        if topology.failover.check_cookie_hash ~= nil then
            e_config:assert(
                type(topology.failover.check_cookie_hash) == 'boolean',
                '%s.failover.check_cookie_hash must be a boolean, got %s',
                field, type(topology.failover.check_cookie_hash)
            )
        end

        if topology.failover.mode == 'stateful'
        and topology.failover.fencing_enabled == true
        then
            e_config:assert(
                topology.failover.failover_timeout ~= nil,
                '%s.failover.failover_timeout must be specified'
                ..' when fencing is enabled',
                field
            )

            e_config:assert(
                topology.failover.failover_timeout > topology.failover.fencing_timeout,
                '%s.failover.failover_timeout must be greater than fencing_timeout',
                field
            )

        end

        if topology.failover.mode == 'stateful' then
            e_config:assert(
                topology.failover.state_provider ~= nil,
                '%s.failover missing state_provider for mode "stateful"',
                field
            )
        end

        if topology.failover.state_provider ~= nil then
            e_config:assert(
                type(topology.failover.state_provider) == 'string',
                '%s.failover.state_provider must be a string, got %s',
                field, type(topology.failover.state_provider)
            )
        end

        if topology.failover.state_provider == 'tarantool' then
            e_config:assert(
                topology.failover.tarantool_params ~= nil,
                '%s.failover missing tarantool_params',
                field
            )
        elseif topology.failover.state_provider == 'etcd2' then
            e_config:assert(
                topology.failover.etcd2_params ~= nil,
                '%s.failover missing etcd2_params',
                field
            )
        elseif topology.failover.state_provider ~= nil then
            e_config:assert(false,
                '%s.failover unknown state_provider %q',
                field, topology.failover.state_provider
            )
        end

        if topology.failover.tarantool_params ~= nil then
            local params = topology.failover.tarantool_params
            local field = field .. '.failover.tarantool_params'
            e_config:assert(
                type(params) == 'table',
                '%s must be a table, got %s',
                field, type(params)
            )

            e_config:assert(
                type(params.uri) == 'string',
                '%s.uri must be a string, got %s',
                field, type(params.uri)
            )

            local _, err = pool.format_uri(params.uri)
            e_config:assert(
                not err,
                '%s.uri: %s',
                field, err and err.err
            )

            e_config:assert(
                type(params.password) == 'string',
                '%s.password must be a string, got %s',
                field, type(params.password)
            )

            local known_keys = {
                ['uri'] = true,
                ['password'] = true,
            }
            for k, _ in pairs(params) do
                e_config:assert(
                    known_keys[k],
                    '%s has unknown parameter %q', field, k
                )
            end
        end

        if topology.failover.etcd2_params ~= nil then
            local params = topology.failover.etcd2_params
            local field = field .. '.failover.etcd2_params'
            e_config:assert(
                type(params) == 'table',
                '%s must be a table, got %s',
                field, type(params)
            )

            e_config:assert(
                params.prefix == nil or
                type(params.prefix) == 'string',
                '%s.prefix must be a string, got %s',
                field, type(params.prefix)
            )

            e_config:assert(
                params.username == nil or
                type(params.username) == 'string',
                '%s.username must be a string, got %s',
                field, type(params.username)
            )

            e_config:assert(
                params.password == nil or
                type(params.password) == 'string',
                '%s.password must be a string, got %s',
                field, type(params.password)
            )

            e_config:assert(
                params.lock_delay == nil or
                type(params.lock_delay) == 'number',
                '%s.lock_delay must be a number, got %s',
                field, type(params.lock_delay)
            )

            if params.endpoints ~= nil then
                e_config:assert(
                    type(params.endpoints) == 'table',
                    '%s.endpoints must be a table, got %s',
                    field, type(params.endpoints)
                )

                local i = 1
                for k, _ in pairs(params.endpoints) do
                    e_config:assert(
                        type(k) == 'number',
                        '%s.endpoints must have integer keys', field
                    )

                    local uri = params.endpoints[i]
                    e_config:assert(
                        type(uri) == 'string',
                        '%s.endpoints must be a contiguous array of strings', field
                    )

                    local _, err = pool.format_uri(uri)
                    e_config:assert(
                        not err,
                        '%s.endpoints[%d]: %s',
                        field, i, err and err.err
                    )
                    i = i + 1
                end
            end

            local known_keys = {
                ['prefix'] = true,
                ['endpoints'] = true,
                ['lock_delay'] = true,
                ['username'] = true,
                ['password'] = true,
            }
            for k, _ in pairs(params) do
                e_config:assert(
                    known_keys[k],
                    '%s has unknown parameter %q', field, k
                )
            end
        end

        local known_keys = {
            ['mode'] = true,
            ['state_provider'] = true,
            ['failover_timeout'] = true,
            ['tarantool_params'] = true,
            ['etcd2_params'] = true,
            ['fencing_enabled'] = true,
            ['fencing_timeout'] = true,
            ['fencing_pause'] = true,
            ['leader_autoreturn'] = true,
            ['autoreturn_delay'] = true,
            ['check_cookie_hash'] = true,
            -- For the sake of backward compatibility with v2.0.1-78
            -- See bug https://github.com/tarantool/cartridge/issues/754
            ['enabled'] = true,
            ['coordinator_uri'] = true,
        }
        for k, _ in pairs(topology.failover) do
            e_config:assert(
                known_keys[k],
                '%s.failover has unknown parameter %q', field, k
            )
        end
    end
end

local function validate_consistency(topology)
    checks('table')
    local servers = topology.servers or {}
    local replicasets = topology.replicasets or {}
    local known_uuids = {}
    local known_uris = {}

    for _it, instance_uuid, server in fun.filter(not_expelled, servers) do
        local field = string.format('servers[%s]', instance_uuid)
        e_config:assert(
            replicasets[server.replicaset_uuid] ~= nil,
            '%s.replicaset_uuid is not configured in replicasets table',
            field
        )
        e_config:assert(
            known_uris[server.uri] == nil,
            '%s.uri %q collision with another server',
            field, server.uri
        )
        known_uuids[server.replicaset_uuid] = true
        known_uris[server.uri] = true
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
                    roles.get_role(role),
                    'replicasets[%s] can not enable unknown role %q',
                    replicaset_uuid, tostring(role)
                )
            end
        end
    end
end

--- Validate topology configuration.
--
-- @function validate
-- @local
-- @tparam table topology_new
-- @tparam table topology_old
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
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
    validate_failover_schema('topology_new', topology_new)
    validate_consistency(topology_new)
    validate_availability(topology_new)
    validate_upgrade(topology_new, topology_old)

    return true
end

local function get_failover_params(topology_cfg)
    checks('?table')
    local ret
    if topology_cfg == nil then
        ret = {
            mode = 'disabled',
        }
    elseif topology_cfg.__type == 'ClusterwideConfig' then
        local err = "Bad argument #1 to get_failover_params" ..
            " (table expected, got ClusterwideConfig)"
        error(err, 2)
    elseif topology_cfg.failover == nil then
        ret = {
            mode = 'disabled',
        }
    elseif type(topology_cfg.failover) == 'boolean' then
        ret = {
            mode = topology_cfg.failover and 'eventual' or 'disabled'
        }
    elseif type(topology_cfg.failover) == 'table' then
        ret = {
            mode = topology_cfg.failover.mode,
            state_provider = topology_cfg.failover.state_provider,
            failover_timeout = topology_cfg.failover.failover_timeout,
            tarantool_params = table.deepcopy(topology_cfg.failover.tarantool_params),
            etcd2_params = table.deepcopy(topology_cfg.failover.etcd2_params),
            fencing_enabled = topology_cfg.failover.fencing_enabled,
            fencing_timeout = topology_cfg.failover.fencing_timeout,
            fencing_pause = topology_cfg.failover.fencing_pause,
            leader_autoreturn = topology_cfg.failover.leader_autoreturn,
            autoreturn_delay = topology_cfg.failover.autoreturn_delay,
            check_cookie_hash = topology_cfg.failover.check_cookie_hash,
        }

        if ret.etcd2_params ~= nil then
            utils.table_setrw(ret.etcd2_params)
        end
    else
        local err = string.format(
            'assertion failed! topology.failover = %s (%s)',
            topology_cfg.failover, type(topology_cfg.failover)
        )
        error(err)
    end

    if ret.mode == nil
    and type(topology_cfg.failover.enabled) == 'boolean'
    then
        -- backward compatibility with 2.0.1-78
        -- see https://github.com/tarantool/cartridge/pull/617
        ret.mode = topology_cfg.failover.enabled and 'eventual' or 'disabled'
    end

    if ret.mode == 'stateful'
    and ret.state_provider == nil
    then
        -- backward compatibility with 2.0.1-95
        -- see https://github.com/tarantool/cartridge/pull/651
        ret.mode = 'disabled'
        -- because stateful failover itself wasn't implemented yet
    end

    -- Enrich tarantool params with defaults
    if ret.tarantool_params == nil then
        ret.tarantool_params = {}
    end

    if ret.tarantool_params.uri == nil then
        ret.tarantool_params.uri = 'tcp://localhost:4401'
    end

    if ret.tarantool_params.password == nil then
        ret.tarantool_params.password = ''
    end

    -- Enrich etcd2 params with defaults
    if ret.etcd2_params == nil then
        ret.etcd2_params = {}
    end

    if ret.etcd2_params.prefix == nil then
        ret.etcd2_params.prefix = '/'
    end

    if ret.etcd2_params.lock_delay == nil then
        ret.etcd2_params.lock_delay = 10
    end

    if ret.etcd2_params.endpoints == nil
    or next(ret.etcd2_params.endpoints) == nil
    then
        ret.etcd2_params.endpoints = {
            'http://127.0.0.1:4001',
            'http://127.0.0.1:2379',
        }
    end

    if ret.etcd2_params.username == nil then
        ret.etcd2_params.username = ""
    end

    if ret.etcd2_params.password == nil then
        ret.etcd2_params.password = ""
    end

    if ret.failover_timeout == nil then
        ret.failover_timeout = 20
    end

    -- Enrich fencing params with defaults
    if ret.mode ~= 'stateful' or ret.fencing_enabled == nil then
        ret.fencing_enabled = false
    end

    if ret.fencing_timeout == nil then
        ret.fencing_timeout = 10
    end

    if ret.fencing_pause == nil then
        ret.fencing_pause = 2
    end

    if ret.mode ~= 'stateful' or ret.leader_autoreturn == nil then
        ret.leader_autoreturn = false
    end

    if ret.autoreturn_delay == nil then
        ret.autoreturn_delay = 300
    end

    if ret.check_cookie_hash == nil then
        ret.check_cookie_hash = true
    end

    return ret
end

--- Find the server in topology config.
--
-- (**Added** in v1.2.0-17)
--
-- @function find_server_by_uri
-- @local
-- @tparam table topology_cfg
-- @tparam string uri
-- @treturn nil|string `instance_uuid` found
local function find_server_by_uri(topology_cfg, uri)
    checks('table', 'string')
    if topology_cfg.__type == 'ClusterwideConfig' then
        local err = "Bad argument #1 to find_server_by_uri" ..
            " (table expected, got ClusterwideConfig)"
        error(err, 2)
    end

    if topology_cfg.servers == nil then
        return nil
    end

    for _it, instance_uuid, server in fun.filter(not_expelled, topology_cfg.servers) do
        if server.uri == uri then
            return instance_uuid
        end
    end

    return nil
end

--- Merge servers URIs form topology_cfg with fresh membership status.
--
-- This function sustains cartridge operability in case of
-- advertise_uri change. The uri map is composed basing on
-- topology_cfg, but if some of them turns out to be dead, the
-- member with corresponding payload.uuid is searched beyond.
--
-- (**Added** in v2.3.0-7)
--
-- @function refine_servers_uri
-- @local
-- @tparam table topology_cfg
-- @treturn {[uuid] = uri} with all servers except expelled ones.
local function refine_servers_uri(topology_cfg)
    checks('table')
    if topology_cfg.__type == 'ClusterwideConfig' then
        local err = "Bad argument #1 to find_server_by_uri" ..
            " (table expected, got ClusterwideConfig)"
        error(err, 2)
    end

    local members_fresh = membership.members()
    local members_known = {}
    local ret = {}

    -- Step 1: get URIs from topology_cfg as is.
    for _, uuid, srv in fun.filter(not_expelled, topology_cfg.servers) do
        ret[uuid] = assert(srv.uri)
        -- Mark members we already processed
        members_known[srv.uri] = members_fresh[srv.uri]
        members_fresh[srv.uri] = nil
    end

    -- Step 2: Try to find another member among the unprocessed.
    for uuid, uri in pairs(ret) do
        local member = members_known[uri]

        if member ~= nil
        and (member.status == 'alive' or member.status == 'suspect')
        then
            goto continue
        end

        for uri, m in pairs(members_fresh) do
            if m.payload.uuid == uuid
            and (m.status == 'alive' or m.status == 'suspect')
            then
                members_fresh[uri] = nil
                ret[uuid] = uri
                break
            end
        end

        ::continue::
    end

    return ret
end

--- Check the cluster health.
-- It is healthy if all instances are healthy.
--
-- The function is designed mostly for testing purposes.
--
-- @function cluster_is_healthy
-- @treturn boolean true / false
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
        elseif member.payload.state ~= 'ConfiguringRoles'
        and member.payload.state ~= 'RolesConfigured' then
            return nil, string.format(
                '%s state %s',
                server.uri, member.payload.state
            )
        end
    end

    return true
end

--- Send UDP ping to servers missing from membership table.
--
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

--- Get replication config to set up full mesh.
--
-- (**Added** in v1.2.0-17)
--
-- @function get_fullmesh_replication
-- @local
-- @tparam table topology_cfg
-- @tparam string replicaset_uuid
-- @treturn table
local function get_fullmesh_replication(topology_cfg, replicaset_uuid, instance_uuid, advertise_uri, params)
    checks('table', 'string', 'string', '?string', '?table')
    if topology_cfg.__type == 'ClusterwideConfig' then
        local err = "Bad argument #1 to get_fullmesh_replication" ..
            " (table expected, got ClusterwideConfig)"
        error(err, 2)
    end
    assert(topology_cfg.servers ~= nil)

    local replication = {}

    for _it, uuid, server in fun.filter(not_disabled, topology_cfg.servers) do
        if server.replicaset_uuid == replicaset_uuid then
            local uri
            if uuid == instance_uuid then
                uri = advertise_uri
            else
                uri = server.uri
            end

            table.insert(replication, uri and pool.format_uri(uri))
        end
    end

    table.sort(replication)

    params = params or {}
    if params.transport == 'ssl' then
        local sslreplication = {}
        for _, uri in ipairs(replication) do
            table.insert(sslreplication, {
                uri = uri,
                params = params,
            })
        end
        return sslreplication
    end
    return replication
end

return {
    validate = function(...)
        return e_config:pcall(validate, ...)
    end,

    expelled = expelled,
    disabled = disabled,
    electable = electable,
    not_expelled = not_expelled,
    not_disabled = not_disabled,
    not_electable = not_electable,

    get_failover_params = get_failover_params,
    get_leaders_order = get_leaders_order,
    cluster_is_healthy = cluster_is_healthy,
    refine_servers_uri = refine_servers_uri,
    probe_missing_members = probe_missing_members,

    find_server_by_uri = find_server_by_uri,
    get_fullmesh_replication = get_fullmesh_replication,
}
