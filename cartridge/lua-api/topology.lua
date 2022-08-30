--- Administration functions (topology related).
--
-- @module cartridge.lua-api.topology

local checks = require('checks')
local errors = require('errors')
local membership = require('membership')

local pool = require('cartridge.pool')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')
local lua_api_get_topology = require('cartridge.lua-api.get-topology')
local lua_api_edit_topology = require('cartridge.lua-api.edit-topology')

local ProbeServerError = errors.new_class('ProbeServerError')
local RestartReplicationError = errors.new_class('RestartReplicationError')

--- Get alias, uri and uuid of current instance.
-- @function get_self
-- @local
-- @treturn table
local function get_self()
    local myself = membership.myself()
    local state, err = confapplier.get_state()
    local app_info = require('cartridge.argparse').get_opts({
        app_name = 'string',
        instance_name = 'string'
    })

    local result = {
        uri = myself.uri,
        uuid = confapplier.get_instance_uuid(),
        demo_uri = os.getenv('TARANTOOL_DEMO_URI'),
        alias = myself.payload.alias,
        state = state,
        error = err and err.err or nil,
        app_name = app_info.app_name,
        instance_name = app_info.instance_name,
    }
    return result
end

--- Get servers list.
-- Optionally filter out the server with the given uuid.
-- @function get_servers
-- @tparam[opt] string uuid
-- @treturn[1] {ServerInfo,...}
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_servers(uuid)
    checks('?string')

    local ret = {}
    local topology, err = lua_api_get_topology.get_topology()
    if topology == nil then
        return nil, err
    end

    if uuid then
        table.insert(ret, topology.servers[uuid])
    else
        for _, v in pairs(topology.servers) do
            table.insert(ret, v)
        end
    end
    return ret
end

--- Get replicasets list.
-- Optionally filter out the replicaset with given uuid.
-- @function get_replicasets
-- @tparam[opt] string uuid
-- @treturn[1] {ReplicasetInfo,...}
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_replicasets(uuid)
    checks('?string')

    local ret = {}
    local topology, err = lua_api_get_topology.get_topology()
    if topology == nil then
        return nil, err
    end

    if uuid then
        table.insert(ret, topology.replicasets[uuid])
    else
        for _, v in pairs(topology.replicasets) do
            table.insert(ret, v)
        end
    end
    return ret
end

--- Discover an instance.
-- @function probe_server
-- @tparam string uri
local function probe_server(uri)
    checks('string')
    local ok, err = membership.probe_uri(uri)
    if not ok then
        return nil, ProbeServerError:new('Probe %q failed: %s', uri, err)
    end

    return true
end

local function __set_servers_disabled_state(uuids, state)
    checks('table', 'boolean')
    local patch = {servers = {}}

    for _, uuid in pairs(uuids) do
        table.insert(patch.servers, {
            uuid = uuid,
            disabled = state,
        })
    end

    local topology, err = lua_api_edit_topology.edit_topology(patch)
    if topology == nil then
        return nil, err
    end

    return topology.servers
end

--- Enable nodes after they were disabled.
-- @function enable_servers
-- @tparam {string,...} uuids
-- @treturn[1] {ServerInfo,...}
-- @treturn[2] nil
-- @treturn[2] table Error description
local function enable_servers(uuids)
    checks('table')
    return __set_servers_disabled_state(uuids, false)
end

--- Temporarily disable nodes.
--
-- @function disable_servers
-- @tparam {string,...} uuids
-- @treturn[1] {ServerInfo,...}
-- @treturn[2] nil
-- @treturn[2] table Error description
local function disable_servers(uuids)
    checks('table')
    return __set_servers_disabled_state(uuids, true)
end

--- Restart replication on specified instances.
--
-- (added in v2.6.0-43)
--
-- @function restart_replication
-- @tparam {string, ...} uuids
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function restart_replication(uuids)
    checks('table')
    local topology_cfg = confapplier.get_readonly('topology')

    if topology_cfg == nil then
        return nil, RestartReplicationError:new(
            "Current instance isn't bootstrapped yet"
        )
    end

    -- Prepare a server group to be operated
    local uri_list = {}
    local refined_uri_list = topology.refine_servers_uri(topology_cfg)
    for _, uuid in ipairs(uuids) do
        local srv = topology_cfg.servers[uuid]
        if not srv then
            return nil, RestartReplicationError:new(
                'Server %s not in clusterwide config', uuid
            )
        elseif topology.disabled(uuid, srv) then
            return nil, RestartReplicationError:new(
                'Server %s is disabled, not suitable' ..
                ' for restarting replication', uuid
            )
        end

        table.insert(uri_list, refined_uri_list[uuid])
    end

    local retmap, errmap = pool.map_call(
        '_G.__cartridge_confapplier_restart_replication',
        {}, { uri_list = uri_list }
    )

    for _, uri in ipairs(uri_list) do
        if retmap[uri] == nil then
            local err = errmap and errmap[uri]
            if err == nil then
                err = RestartReplicationError:new('Unknown error at %s', uri)
            end
            return nil, err
        end
    end

    return true
end

local function __set_servers_electable_state(uuids, state)
    checks('table', 'boolean')
    local patch = {servers = {}}

    for _, uuid in pairs(uuids) do
        table.insert(patch.servers, {
            uuid = uuid,
            electable = state,
        })
    end

    local topology, err = lua_api_edit_topology.edit_topology(patch)
    if topology == nil then
        return nil, err
    end

    return topology.servers
end

--- Make nodes electable after they were set unelectable.
-- @function set_electable_servers
-- @tparam {string,...} uuids
-- @treturn[1] {ServerInfo,...}
-- @treturn[2] nil
-- @treturn[2] table Error description
local function set_electable_servers(uuids)
    checks('table')
    return __set_servers_electable_state(uuids, true)
end

--- Temporarily make nodes unelectable as leaders.
-- @function set_unelectable_servers
-- @tparam {string,...} uuids
-- @treturn[1] {ServerInfo,...}
-- @treturn[2] nil
-- @treturn[2] table Error description
local function set_unelectable_servers(uuids)
    checks('table')
    return __set_servers_electable_state(uuids, false)
end

return {
    get_self = get_self,
    get_servers = get_servers,
    get_replicasets = get_replicasets,
    get_topology = lua_api_get_topology.get_topology,

    edit_topology = lua_api_edit_topology.edit_topology,
    probe_server = probe_server,
    enable_servers = enable_servers,
    disable_servers = disable_servers,
    set_electable_servers = set_electable_servers,
    set_unelectable_servers = set_unelectable_servers,
    restart_replication = restart_replication,
}
