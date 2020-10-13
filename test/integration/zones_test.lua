local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {{
            alias = 'A',
            roles = {'vshard-router', 'vshard-storage'},
            servers = 3,
        }},
    })
    g.cluster:start()


    g.A1 = g.cluster:server('A-1')
    g.A2 = g.cluster:server('A-2')
    g.A3 = g.cluster:server('A-3')
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

local function set_zones(zones)
    local servers = {}
    for k, v in pairs(zones) do
        table.insert(servers, {uuid = k, zone = v})
    end
    return g.cluster.main_server.net_box:eval([[
        local servers = ...
        local ret, err = require('cartridge').admin_edit_topology({
            servers = servers,
        })
        if ret == nil then
            return nil, err
        end
        return true
    ]], {servers})
end

local function set_distances(distances)
    return g.cluster.main_server.net_box:call(
        'package.loaded.cartridge.config_patch_clusterwide',
        {{zone_distances = distances}}
    )
end

local function get_config(...)
    return g.cluster.main_server.net_box:call(
        'package.loaded.cartridge.config_get_readonly', {...}
    )
end

function g.test_zones()
    local ok, err = set_zones({
        [g.A1.instance_uuid] = 'z1',
        [g.A2.instance_uuid] = 'z2',
    })
    t.assert_equals({ok, err}, {true, nil})

    t.assert_items_equals(
        g.A1:graphql({query = '{servers {uuid zone}}'}).data.servers,
        {
            {uuid = g.A1.instance_uuid, zone = 'z1'},
            {uuid = g.A2.instance_uuid, zone = 'z2'},
            {uuid = g.A3.instance_uuid, zone = box.NULL},
        }
    )

    local ok, err = set_zones({
        [g.A1.instance_uuid] = box.NULL, -- null doesn't edit value
        [g.A2.instance_uuid] = '',
    })
    t.assert_equals({ok, err}, {true, nil})

    local topology_cfg = get_config('topology')
    t.assert_equals(topology_cfg.servers[g.A1.instance_uuid].zone, 'z1')
    t.assert_equals(topology_cfg.servers[g.A2.instance_uuid].zone, nil)

    local resp = g.A1:graphql({query = [[
        mutation($servers: [EditServerInput]) {
            cluster {
                edit_topology(servers: $servers){
                    servers {uuid zone}
                }
            }
        }
    ]], variables = {
        servers = {
            {uuid = g.A1.instance_uuid, zone = ''},
            {uuid = g.A2.instance_uuid, zone = 'z2'},
        }
    }})

    t.assert_equals(
        resp.data.cluster.edit_topology.servers,
        {
            {uuid = g.A1.instance_uuid, zone = box.NULL},
            {uuid = g.A2.instance_uuid, zone = 'z2'},
        }
    )

    t.assert_error_msg_contains (
        "bad argument params.zone to __edit_server"..
        " (?string expected, got number)",
        set_zones, {[g.A2.instance_uuid] = 2}
    )
end

function g.test_distances()
    local q_get_priority = [[
        local replicaset = require('vshard').router.routeall()[...]
        return require('fun').iter(replicaset.priority_list)
            :map(function(r) return r.zone end)
            :totable()
    ]]

    local ok, err = set_zones({
        [g.A1.instance_uuid] = 'z1',
        [g.A2.instance_uuid] = 'z2',
        [g.A3.instance_uuid] = 'z3',
    })
    t.assert_equals({ok, err}, {true, nil})

    local topology_cfg = get_config('topology')
    t.assert_equals(topology_cfg.servers[g.A1.instance_uuid].zone, 'z1')
    t.assert_equals(topology_cfg.servers[g.A2.instance_uuid].zone, 'z2')
    t.assert_equals(topology_cfg.servers[g.A3.instance_uuid].zone, 'z3')

    local distances = {
        z1 = {z1 = 0, z2 = 200, z3 = 100},
        z2 = {z1 = 1, z2 = nil, z3 = 100},
        z3 = {z1 = 2, z2 =  50, z3 = box.NULL},
        z4 = {--[[defaults to 0]]},
    }
    local ok, err = set_distances(distances)
    t.assert_equals({ok, err}, {true, nil})
    t.assert_items_equals(get_config('zone_distances'), distances)

    local uuid = g.cluster.main_server.replicaset_uuid

    t.assert_equals(
        g.A1.net_box:eval(q_get_priority, {uuid}),
        {'z1', 'z3', 'z2'}
    )
    t.assert_equals(
        g.A2.net_box:eval(q_get_priority, {uuid}),
        {'z2', 'z1', 'z3'}
    )
    t.assert_equals(
        g.A3.net_box:eval(q_get_priority, {uuid}),
        {'z3', 'z1', 'z2'}
    )

    -- vshard doesn't handle box.NULL, so the cartridge should
    -- omit it before calling vshard.cfg()
    distances.z3.z3 = nil

    local a1_cfg = g.A1.net_box:eval([[
        local conf = require('cartridge').config_get_readonly()
        local utils = require('cartridge.vshard-utils')
        return utils.get_vshard_config('default', conf)
    ]])
    t.assert_covers(a1_cfg, {zone = 'z1', weights = distances})
    local replicas = a1_cfg.sharding[g.A1.replicaset_uuid].replicas
    t.assert_equals(replicas[g.A1.instance_uuid].zone, 'z1')
    t.assert_equals(replicas[g.A2.instance_uuid].zone, 'z2')
    t.assert_equals(replicas[g.A3.instance_uuid].zone, 'z3')
end

function g.test_validation()
    t.assert_equals({set_distances()}, {true, nil})
    t.assert_equals({set_distances(box.NULL)}, {true, nil})

    local ok, err = set_distances('foo')
    t.assert_equals(ok, nil)
    t.assert_equals(err.err, 'zone_distances must be a table, got string')

    local ok, err = set_distances({'z1'})
    t.assert_equals(ok, nil)
    t.assert_equals(err.err, 'Zone label must be a string, got number')

    local ok, err = set_distances({z1 = {'z1'}})
    t.assert_equals(ok, nil)
    t.assert_equals(err.err, 'Zone label must be a string, got number')

    local ok, err = set_distances({z1 = true})
    t.assert_equals(ok, nil)
    t.assert_equals(err.err,
        'Zone z1 must be a map of relative weights' ..
        ' of other zones, got boolean'
    )

    local ok, err = set_distances({z1 = {z2 = -7}})
    t.assert_equals(ok, nil)
    t.assert_equals(err.err,
        'Distance z1-z2 must be nil or non-negative number, got -7'
    )

    local ok, err = set_distances({z2 = {z2 = 2}})
    t.assert_equals(ok, nil)
    t.assert_equals(err.err,
        'Distance of own zone z2 must be either nil or 0, got 2'
    )
end
