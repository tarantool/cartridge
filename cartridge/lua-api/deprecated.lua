--- Administration functions (deprecated).
--
-- @module cartridge.lua-api.deprecated

local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local membership = require('membership')

local pool = require('cartridge.pool')
local confapplier = require('cartridge.confapplier')
local lua_api_topology = require('cartridge.lua-api.topology')
local lua_api_failover = require('cartridge.lua-api.failover')

local EditTopologyError = errors.new_class('Editing cluster topology failed')

--- Join an instance to the cluster (*deprecated*).
--
-- (**Deprecated** since v1.0.0-17 in favor of `cartridge.admin_edit_topology`)
--
-- @function join_server
-- @within Deprecated functions
-- @tparam table args
-- @tparam string args.uri
-- @tparam ?string args.instance_uuid
-- @tparam ?string args.replicaset_uuid
-- @tparam ?{string,...} args.roles
-- @tparam ?number args.timeout
-- @tparam ?{[string]=string,...} args.labels
-- @tparam ?string args.vshard_group
-- @tparam ?string args.replicaset_alias
-- @tparam ?number args.replicaset_weight
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function join_server(args)
    checks({
        uri = 'string',
        instance_uuid = '?string',
        replicaset_uuid = '?string',
        roles = '?table',
        timeout = '?number',
        labels = '?table',
        vshard_group = '?string',
        replicaset_alias = '?string',
        replicaset_weight = '?number',
    })

    local topology_cfg = confapplier.get_readonly('topology')
    if topology_cfg == nil then
        -- Bootstrapping first instance from the web UI
        local myself = membership.myself()
        if args.uri ~= myself.uri then
            return nil, EditTopologyError:new(
                "Invalid attempt to call join_server()." ..
                " This instance isn't bootstrapped yet" ..
                " and advertises uri=%q while you are joining uri=%q.",
                myself.uri, args.uri
            )
        end
    end

    if topology_cfg ~= nil
    and topology_cfg.replicasets[args.replicaset_uuid] ~= nil
    then
        -- Keep old behavior:
        -- Prevent simultaneous join_server and edit_replicaset
        -- Ignore roles if replicaset already exists
        args.roles = nil
        args.vshard_group = nil
        args.replicaset_alias = nil
        args.replicaset_weight = nil
    end


    local topology, err = lua_api_topology.edit_topology({
        -- async = false,
        replicasets = {{
            uuid = args.replicaset_uuid,
            roles = args.roles,
            alias = args.replicaset_alias,
            weight = args.replicaset_weight,
            vshard_group = args.vshard_group,
            join_servers = {{
                uri = args.uri,
                uuid = args.instance_uuid,
                labels = args.labels,
            }}
        }}
    })

    if topology == nil then
        return nil, err
    end

    local timeout = args.timeout or 0
    if not (timeout > 0) then
        return true
    end

    local deadline = fiber.time() + timeout
    local cond = membership.subscribe()
    local conn = nil
    while not conn and fiber.time() < deadline do
        cond:wait(0.2)

        local member = membership.get_member(args.uri)
        if (member ~= nil)
        and (member.status == 'alive')
        and (member.payload.uuid == args.instance_uuid)
        and (
            member.payload.state == 'ConfiguringRoles' or
            member.payload.state == 'RolesConfigured'
        ) then
            conn = pool.connect(args.uri)
        end
    end
    membership.unsubscribe(cond)

    if conn then
        return true
    else
        return nil, EditTopologyError:new('Timeout connecting %q', args.uri)
    end
end

--- Edit an instance (*deprecated*).
--
-- (**Deprecated** since v1.0.0-17 in favor of `cartridge.admin_edit_topology`)
--
-- @function edit_server
-- @within Deprecated functions
-- @tparam table args
-- @tparam string args.uuid
-- @tparam ?string args.uri
-- @tparam ?{[string]=string,...} args.labels
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function edit_server(args)
    checks({
        uuid = 'string',
        uri = '?string',
        labels = '?table'
    })

    local topology, err = lua_api_topology.edit_topology({
        servers = {args},
    })
    if topology == nil then
        return nil, err
    end

    return true
end

--- Expel an instance (*deprecated*).
-- Forever.
--
-- (**Deprecated** since v1.0.0-17 in favor of `cartridge.admin_edit_topology`)
--
-- @function expel_server
-- @within Deprecated functions
-- @tparam string uuid
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function expel_server(uuid)
    checks('string')

    local topology, err = lua_api_topology.edit_topology({
        servers = {{
            uuid = uuid,
            expelled = true,
        }}
    })

    if topology == nil then
        return nil, err
    end

    return true
end

--- Edit replicaset parameters (*deprecated*).
--
-- (**Deprecated** since v1.0.0-17 in favor of `cartridge.admin_edit_topology`)
--
-- @function edit_replicaset
-- @within Deprecated functions
-- @tparam table args
-- @tparam string args.uuid
-- @tparam string args.alias
-- @tparam ?{string,...} args.roles
-- @tparam ?{string,...} args.master Failover order
-- @tparam ?number args.weight
-- @tparam ?string args.vshard_group
-- @tparam ?boolean args.all_rw
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function edit_replicaset(args)
    checks({
        uuid = 'string',
        alias = '?string',
        roles = '?table',
        master = '?table',
        weight = '?number',
        vshard_group = '?string',
        all_rw = '?boolean',
    })

    local topology, err = lua_api_topology.edit_topology({
        replicasets = {{
            uuid = args.uuid,
            alias = args.alias,
            all_rw = args.all_rw,
            roles = args.roles,
            weight = args.weight,
            failover_priority = args.master,
            vshard_group = args.vshard_group,
        }}
    })

    if topology == nil then
        return nil, err
    end

    return true
end

--- Get current failover state.
--
-- (**Deprecated** since v2.0.1-78)
-- @function get_failover_enabled
-- @treturn boolean `true`/`false`
local function get_failover_enabled()
    return lua_api_failover.get_params().enabled
end

--- Enable failover.
--
-- (**Deprecated** since v2.0.1-78)
-- @function enable_failover
-- @treturn[1] boolean New enabled state
-- @treturn[2] nil
-- @treturn[2] table Error description
local function enable_failover()
    local ok, err = lua_api_failover.set_params({enabled = true})
    if ok == nil then
        return nil, err
    end

    return get_failover_enabled()
end

--- Disable failover.
--
-- (**Deprecated** since v2.0.1-78)
-- @function disable_failover
-- @treturn[1] boolean New enabled state
-- @treturn[2] nil
-- @treturn[2] table Error description
local function disable_failover()
    local ok, err = lua_api_failover.set_params({enabled = false})
    if ok == nil then
        return nil, err
    end

    return get_failover_enabled()
end

return {
    edit_replicaset = edit_replicaset,
    edit_server = edit_server,
    join_server = join_server,
    expel_server = expel_server,

    enable_failover = enable_failover,
    disable_failover = disable_failover,
    get_failover_enabled = get_failover_enabled,
}
