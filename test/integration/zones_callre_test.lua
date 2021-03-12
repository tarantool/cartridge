local fio = require('fio')
local log = require('log')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = "secret-cluster-cookie",
        replicasets = {{
                           alias = 'r1',
                           roles = {'vshard-router'},
                           servers = 1,
                       },
                       {
                           alias = 's1',
                           roles = {'vshard-storage'},
                           servers = 3,
                       },
        },
    })
    g.cluster:start()

    g.r1 = g.cluster:server('r1-1')
    g.s1_zone_2_master = g.cluster:server('s1-1')
    g.s1_zone_1_replica = g.cluster:server('s1-2')
    g.s1_zone_3_replica = g.cluster:server('s1-3')
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

local function get_distances()
    return g.cluster.main_server:graphql({query = [[{
        cluster { config(sections: ["zone_distances.yml"]) {content} }
    }]]}).data.cluster.config[1].content
end

function g.test_spec()
    local ok, err = set_zones({
        [g.r1.instance_uuid] = 'z1',
        [g.s1_zone_1_replica.instance_uuid] = 'z1',
        [g.s1_zone_2_master.instance_uuid] = 'z2',
        [g.s1_zone_3_replica.instance_uuid] = 'z3',
    })
    t.assert_equals({ok, err}, {true, nil})

    local topology_cfg = get_config('topology')
    t.assert_equals(topology_cfg.servers[g.r1.instance_uuid].zone, 'z1')
    t.assert_equals(topology_cfg.servers[g.s1_zone_1_replica.instance_uuid].zone, 'z1')
    t.assert_equals(topology_cfg.servers[g.s1_zone_2_master.instance_uuid].zone, 'z2')
    t.assert_equals(topology_cfg.servers[g.s1_zone_3_replica.instance_uuid].zone, 'z3')

    local distances = {
        z1 = {z2 = 10, z3 = 1},
        z2 = {z1 = 10, z3 = 12},
        z3 = {z1 = 1, z2 =  12},
    }
    local ok, err = set_distances(distances)
    t.assert_equals({ok, err}, {true, nil})
    t.assert_items_equals(get_config('zone_distances'), distances)


    local res = g.r1.net_box:eval([[
        local vshard = require('vshard')
        local replicaset_uuid = ...
        return vshard.router.routeall()[replicaset_uuid]:callre("box.info")
    ]], {g.s1_zone_3_replica.replicaset_uuid})


    log.info("res: " .. res.uuid)
    log.info("s1_zone_1_replica: " .. g.s1_zone_1_replica.instance_uuid)
    log.info("s1_zone_2_master: " .. g.s1_zone_2_master.instance_uuid)
    log.info("s1_zone_3_replica: " .. g.s1_zone_3_replica.instance_uuid)
    -- always goes to master
    -- it will be wrong:
    t.assert_equals(res.uuid, g.s1_zone_3_replica.instance_uuid)



end
