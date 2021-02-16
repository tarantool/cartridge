--- Administration functions (`get-topology` implementation).
--
-- @module cartridge.lua-api.get-topology

local fun = require('fun')
local membership = require('membership')

local utils = require('cartridge.utils')
local roles = require('cartridge.roles')
local failover = require('cartridge.failover')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')

local set_topology_meta

--- Replicaset general information.
-- @tfield string uuid
--   The replicaset UUID.
-- @tfield {string,...}  roles
--   Roles enabled on the replicaset.
-- @tfield string status
--   Replicaset health.
-- @tfield ServerInfo master
--   Replicaset leader according to configuration.
-- @tfield ServerInfo active_master
--   Active leader.
-- @tfield number weight
--   Vshard replicaset weight.
--   Matters only if vshard-storage role is enabled.
-- @tfield string vshard_group
--   Name of vshard group the replicaset belongs to.
-- @tfield boolean all_rw
--   A flag indicating that all servers in the replicaset should be read-write.
-- @tfield string alias
--   Human-readable replicaset name.
-- @tfield {ServerInfo,...} servers
--   All instances in the replicaset.
-- @table ReplicasetInfo

--- Instance general information.
-- @tfield string alias
--   Human-readable instance name.
-- @tfield string uri
-- @tfield string uuid
-- @tfield boolean disabled
-- @tfield string status
--   Instance health.
-- @tfield string message
--   Auxilary health status.
-- @tfield ReplicasetInfo replicaset
--   Circular reference to a replicaset.
--   (**Deprecated** since v2.4.0-??)
-- @tfield ?string replicaset_uuid
-- @tfield number priority
--   Leadership priority for automatic failover.
-- @tfield number clock_delta
--   Difference between remote clock and the current one (in
--   seconds), obtained from the membership module (SWIM protocol).
--   Positive values mean remote clock are ahead of local, and vice
--   versa.
-- @tfield string zone
-- @table ServerInfo

--- Get servers and replicasets lists.
-- @function get_topology
-- @local
-- @treturn[1] {servers={ServerInfo,...},replicasets={ReplicasetInfo,...}}
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_topology()
    local state, err = confapplier.get_state()
    -- OperationError doesn't influence observing topology
    if state == 'InitError' or state == 'BootError' then
        return nil, err
    end

    local members = membership.members()
    local topology_cfg = confapplier.get_readonly('topology')
    if topology_cfg == nil then
        topology_cfg = {
            servers = {},
            replicasets = {},
        }
    end

    local servers = {}
    local replicasets = {}
    local known_roles = roles.get_known_roles()
    local leaders_order = {}
    local failover_cfg = topology.get_failover_params(topology_cfg)

    for replicaset_uuid, replicaset in pairs(topology_cfg.replicasets) do
        replicasets[replicaset_uuid] = {
            uuid = replicaset_uuid,
            roles = {},
            status = 'healthy',
            master = {
                uri = 'void',
                uuid = 'void',
                status = 'void',
                message = 'void',
            },
            active_master = {
                uri = 'void',
                uuid = 'void',
                status = 'void',
                message = 'void',
            },
            weight = nil,
            vshard_group = replicaset.vshard_group,
            servers = {},
            all_rw = replicaset.all_rw or false,
            alias = replicaset.alias or 'unnamed',
        }

        local enabled_roles = roles.get_enabled_roles(replicaset.roles)

        for _, role in pairs(known_roles) do
            if enabled_roles[role] then
                table.insert(replicasets[replicaset_uuid].roles, role)
            end
        end

        if replicaset.roles['vshard-storage'] then
            replicasets[replicaset_uuid].weight = replicaset.weight or 0.0
        end

        leaders_order[replicaset_uuid] = topology.get_leaders_order(
            topology_cfg, replicaset_uuid
        )
    end

    local active_leaders = failover.get_active_leaders()
    local refined_uri = topology.refine_servers_uri(topology_cfg)

    for _, instance_uuid, server in fun.filter(topology.not_expelled, topology_cfg.servers) do
        local uri = assert(refined_uri[instance_uuid])
        local member = members[uri]
        members[uri] = nil

        local srv = {
            uri = uri,
            uuid = instance_uuid,
            disabled = not topology.not_disabled(instance_uuid, server),
            zone = server.zone,
            alias = nil,
            status = nil,
            message = nil,
            priority = nil,
            replicaset_uuid = server.replicaset_uuid,
            clock_delta = nil,
        }

        local rpl = replicasets[server.replicaset_uuid]

        if member ~= nil and member.payload ~= nil then
            srv.alias = member.payload.alias
        end

        if not member or member.status == 'left' then
            srv.status = 'not found'
            srv.message = 'Server uri is not in membership'
        elseif member.payload.uuid ~= nil and member.payload.uuid ~= instance_uuid then
            srv.status = 'not found'
            srv.message = string.format('Alien uuid %q (%s)', member.payload.uuid, member.status)
        elseif member.status ~= 'alive' then
            srv.status = 'unreachable'
            srv.message = string.format('Server status is %q', member.status)
        elseif member.payload.uuid == nil then
            srv.status = 'unconfigured'
            srv.message = member.payload.state or ''
        elseif member.payload.state == 'ConfiguringRoles'
        or member.payload.state == 'RolesConfigured' then
            srv.status = 'healthy'
            srv.message = ''
        elseif member.payload.state == 'InitError'
        or member.payload.state == 'BootError'
        or member.payload.state == 'OperationError' then
            srv.status = 'error'
            srv.message = member.payload.state
        else
            srv.status = 'warning'
            srv.message = member.payload.state or 'UnknownState'
        end

        if member ~= nil and member.status == 'alive'
        and member.clock_delta ~= nil
        then
            srv.clock_delta = member.clock_delta * 1e-6
        end

        if leaders_order[server.replicaset_uuid][1] == instance_uuid then
            if failover_cfg.mode ~= 'stateful' then
                rpl.master = srv
            end
        end
        if active_leaders[server.replicaset_uuid] == instance_uuid then
            if failover_cfg.mode == 'stateful' then
                rpl.master = srv
            end
            rpl.active_master = srv
        end
        if srv.status ~= 'healthy' then
            rpl.status = 'unhealthy'
        end

        srv.priority = utils.table_find(
            leaders_order[server.replicaset_uuid],
            instance_uuid
        )
        srv.labels = server.labels or {}
        rpl.servers[srv.priority] = srv

        servers[instance_uuid] = srv
    end

    for _, m in pairs(members) do
        if (m.status == 'alive') and (m.payload.uuid == nil) then
            table.insert(servers, {
                uri = m.uri,
                uuid = '',
                status = 'unconfigured',
                message = m.payload.state or '',
                clock_delta = m.clock_delta and (m.clock_delta * 1e-6),
                alias = m.payload.alias,
            })
        end
    end

    return set_topology_meta({
        servers = servers,
        replicasets = replicasets,
    })
end


--- Set metatables for each server in topology
-- This function creates links from server to its replicaset
-- through metatable for backward compatibility with circular
-- topology table
-- @tparam table topology
-- @tparam {ServerInfo,..} topology.servers
-- @tparam {ReplicasetInfo,..} topology.replicasets
-- @treturn {servers={ServerInfo,...},replicasets={ReplicasetInfo,...}}
set_topology_meta = function(topology, call_get_topology)
    local servers_to_set = topology.servers or {}
    local replicasets_to_set = topology.replicasets or {}

    local replicasets = topology.replicasets
    if call_get_topology then
        local t, err = get_topology()
        if err ~= nil then
            return nil, err
        end
        replicasets = t.replicasets
    end

    local __server_mt = {__index = function(server, key)
        if key == 'replicaset' then
            return replicasets[server.replicaset_uuid]
        end
    end}

    -- Set metatable for each server in replicaset (if topology table
    -- recieved from net.box and we want to restore circular refs)
    for _, replicaset in pairs(replicasets_to_set) do
        setmetatable(replicaset.active_master, __server_mt)
        setmetatable(replicaset.master, __server_mt)

        for _, server in pairs(replicaset.servers) do
            setmetatable(server, __server_mt)
        end
    end

    for _, server in pairs(servers_to_set) do
        setmetatable(server, __server_mt)
    end
    return topology
end


return {
    get_topology = get_topology,
    set_topology_meta = set_topology_meta,
}
