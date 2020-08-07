--- Administration functions (`edit-topology` implementation).
--
-- @module cartridge.lua-api.edit-topology

local fun = require('fun')
local checks = require('checks')
local errors = require('errors')
local uuid_lib = require('uuid')

local roles = require('cartridge.roles')
local topology = require('cartridge.topology')
local twophase = require('cartridge.twophase')
local vshard_utils = require('cartridge.vshard-utils')
local confapplier = require('cartridge.confapplier')

local lua_api_get_topology = require('cartridge.lua-api.get-topology')

local EditTopologyError = errors.new_class('Editing cluster topology failed')

local topology_cfg_checker = {
    auth = '?',
    failover = '?',
    servers = 'table',
    replicasets = 'table',
}

local function __join_server(topology_cfg, params)
    checks(topology_cfg_checker, {
        uri = 'string',
        uuid = 'string',
        labels = '?table',
        replicaset_uuid = 'string',
    })

    if topology_cfg.servers[params.uuid] ~= nil then
        return nil, EditTopologyError:new(
            "Server %q is already joined",
            params.uuid
        )
    end

    local replicaset = topology_cfg.replicasets[params.replicaset_uuid]

    replicaset.master = topology.get_leaders_order(
        topology_cfg, params.replicaset_uuid
    )
    table.insert(replicaset.master, params.uuid)

    local server = {
        uri = params.uri,
        labels = params.labels,
        disabled = false,
        replicaset_uuid = params.replicaset_uuid,
    }

    topology_cfg.servers[params.uuid] = server
    return true
end

local function __edit_server(topology_cfg, params)
    checks(topology_cfg_checker, {
        uuid = 'string',
        uri = '?string',
        labels = '?table',
        disabled = '?boolean',
        expelled = '?boolean',
    })

    local server = topology_cfg.servers[params.uuid]
    if server == nil then
        return nil, EditTopologyError:new('Server %q not in config', params.uuid)
    elseif server == "expelled" then
        return nil, EditTopologyError:new('Server %q is expelled', params.uuid)
    end

    if params.uri ~= nil then
        server.uri = params.uri
    end

    if params.labels ~= nil then
        server.labels = params.labels
    end

    if params.disabled ~= nil then
        server.disabled = params.disabled
    end

    if params.expelled == true then
        topology_cfg.servers[params.uuid] = 'expelled'
    end

    return true
end

local function __edit_replicaset(topology_cfg, params)
    checks(topology_cfg_checker, {
        uuid = 'string',
        alias = '?string',
        all_rw = '?boolean',
        roles = '?table',
        weight = '?number',
        failover_priority = '?table',
        vshard_group = '?string',
        join_servers = '?table',
    })

    local replicaset = topology_cfg.replicasets[params.uuid]

    if replicaset == nil then
        if params.join_servers == nil
        or next(params.join_servers) == nil
        then
            return nil, EditTopologyError:new(
                'Replicaset %q not in config',
                params.uuid
            )
        end

        replicaset = {
            roles = {},
            alias = 'unnamed',
            master = {},
            weight = 0,
        }
        topology_cfg.replicasets[params.uuid] = replicaset
    end

    if params.join_servers ~= nil then
        for _, srv in pairs(params.join_servers) do
            if srv.uuid == nil then
                srv.uuid = uuid_lib.str()
            end

            srv.replicaset_uuid = params.uuid

            local ok, err = __join_server(topology_cfg, srv)
            if ok == nil then
                return nil, err
            end
        end
    end

    local old_roles = replicaset.roles
    if params.roles ~= nil then
        replicaset.roles = roles.get_enabled_roles(params.roles)
    end

    if params.failover_priority ~= nil then
        replicaset.master = topology.get_leaders_order(
            topology_cfg, params.uuid,
            params.failover_priority
        )
    end

    if params.alias ~= nil then
        replicaset.alias = params.alias
    end

    if params.all_rw ~= nil then
        replicaset.all_rw = params.all_rw
    end

    -- Set proper vshard group
    repeat -- until true
        if not replicaset.roles['vshard-storage'] then
            -- ignore unless replicaset is a storage
            break
        end

        if params.vshard_group ~= nil then
            replicaset.vshard_group = params.vshard_group
            break
        end

        if replicaset.vshard_group == nil then
            replicaset.vshard_group = 'default'
        end
    until true


    -- Set proper replicaset weight
    repeat -- until true
        if not replicaset.roles['vshard-storage'] then
            replicaset.weight = 0
            break
        end

        if params.weight ~= nil then
            replicaset.weight = params.weight
            break
        end

        if old_roles['vshard-storage'] then
            -- don't adjust weight if storage role
            -- has already been enabled
            break
        end

        local vshard_groups = vshard_utils.get_known_groups()
        local group_params = vshard_groups[replicaset.vshard_group]

        if group_params and not group_params.bootstrapped then
            replicaset.weight = 1
        else
            replicaset.weight = 0
        end
    until true

    return true
end

--- Edit cluster topology.
-- This function can be used for:
--
-- - bootstrapping cluster from scratch
-- - joining a server to an existing replicaset
-- - creating new replicaset with one or more servers
-- - editing uri/labels of servers
-- - disabling and expelling servers
--
-- (**Added** in v1.0.0-17)
-- @function edit_topology
-- @tparam table args
-- @tparam ?{EditServerParams,..} args.servers
-- @tparam ?{EditReplicasetParams,..} args.replicasets
-- @within Editing topology

--- Replicatets modifications.
-- @tfield ?string uuid
-- @tfield ?string alias
-- @tfield ?{string,...} roles
-- @tfield ?boolean all_rw
-- @tfield ?number weight
-- @tfield ?{string,...} failover_priority
--   array of uuids specifying servers failover priority
-- @tfield ?string vshard_group
-- @tfield ?{JoinServerParams,...} join_servers
-- @table EditReplicasetParams
-- @within Editing topology

--- Parameters required for joining a new server.
-- @tfield string uri
-- @tfield ?string uuid
-- @tfield ?table labels
-- @table JoinServerParams
-- @within Editing topology

--- Servers modifications.
-- @tfield ?string uri
-- @tfield string uuid
-- @tfield ?table labels
-- @tfield ?boolean disabled
-- @tfield ?boolean expelled
--   Expelling an instance is permanent and can't be undone.
--   It's suitable for situations when the hardware is destroyed,
--   snapshots are lost and there is no hope to bring it back to life.
-- @table EditServerParams
-- @within Editing topology

local function edit_topology(args)
    checks({
        replicasets = '?table',
        servers = '?table',
    })

    local args = table.deepcopy(args)
    local topology_cfg = confapplier.get_deepcopy('topology')
    if topology_cfg == nil then
        topology_cfg = {
            replicasets = {},
            servers = {},
            failover = false,
        }
    end

    local i = 0
    for _, srv in pairs(args.servers or {}) do
        i = i + 1
        if args.servers[i] == nil then
            error('bad argument args.servers' ..
                ' to edit_topology (it must be a contiguous array)', 2
            )
        end

        local ok, err = __edit_server(topology_cfg, srv)
        if ok == nil then
            return nil, err
        end
    end

    local i = 0
    for _, rpl in pairs(args.replicasets or {}) do
        i = i + 1
        if args.replicasets[i] == nil then
            error('bad argument args.replicasets' ..
                ' to edit_topology (it must be a contiguous array)', 2
            )
        end

        if rpl.uuid == nil then
            rpl.uuid = uuid_lib.str()
        end

        local ok, err = __edit_replicaset(topology_cfg, rpl)
        if ok == nil then
            return nil, err
        end
    end

    for replicaset_uuid, _ in pairs(topology_cfg.replicasets) do
        local replicaset_empty = true
        for _, _, server in fun.filter(topology.not_expelled, topology_cfg.servers) do
            if server.replicaset_uuid == replicaset_uuid then
                replicaset_empty = false
            end
        end

        if replicaset_empty then
            topology_cfg.replicasets[replicaset_uuid] = nil
        else
            local replicaset = topology_cfg.replicasets[replicaset_uuid]
            local leaders = topology.get_leaders_order(topology_cfg, replicaset_uuid)

            if topology_cfg.servers[leaders[1]] == 'expelled' then
                return nil, EditTopologyError:new(
                    "Server %q is the leader and can't be expelled", leaders[1]
                )
            end

            -- filter out all expelled instances
            replicaset.master = {}
            for _, leader_uuid in pairs(leaders) do
                if topology.not_expelled(leader_uuid, topology_cfg.servers[leader_uuid]) then
                    table.insert(replicaset.master, leader_uuid)
                end
            end
        end
    end

    local ok, err = twophase.patch_clusterwide({topology = topology_cfg})
    if not ok then
        return nil, err
    end

    local ret = {
        replicasets = {},
        servers = {},
    }

    local topology, err = lua_api_get_topology.get_topology()
    if topology == nil then
        return nil, err
    end

    for _, srv in pairs(args.servers or {}) do
        table.insert(ret.servers, topology.servers[srv.uuid])
    end

    for _, rpl in pairs(args.replicasets or {}) do
        for _, srv in pairs(rpl.join_servers or {}) do
            table.insert(ret.servers, topology.servers[srv.uuid])
        end
        table.insert(ret.replicasets, topology.replicasets[rpl.uuid])
    end

    return ret
end

return {
    edit_topology = edit_topology,
}
