local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local M1, R1, R2

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'vshard-router', 'vshard-storage'},
                servers = {
                    {
                        alias = 'master1',
                        http_port = 8081,
                        advertise_port = 13301,
                        instance_uuid = helpers.uuid('a', 'a', 1)
                    },
                    {
                        alias = 'replica1',
                        http_port = 8082,
                        advertise_port = 13302,
                        instance_uuid = helpers.uuid('a', 'a', 2)
                    },
                    {
                        alias = 'replica2',
                        http_port = 8083,
                        advertise_port = 13303,
                        instance_uuid = helpers.uuid('a', 'a', 3)
                    }
                },
            },
        },
    })
    g.cluster:start()


    M1 = g.cluster:server('master1')
    R1 = g.cluster:server('replica1')
    R2 = g.cluster:server('replica2')
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function set_zones(zones)
    local servers = {}
    for key, value in pairs(zones) do
        table.insert(servers, {uuid = key, zone = value})
    end
    local err = M1.net_box:eval([[
        local servers = ...
        local res, err = require('cartridge').admin_edit_topology({
            servers = servers,
        })
        return err
    ]], {servers})

    return err
end

local function set_distances(distances)
    local _, err = M1.net_box:call(
        'package.loaded.cartridge.config_patch_clusterwide',
        {{zone_distances = distances}}
    )
    return err
end

local function get_config()
    return M1.net_box:eval([[
        return require('cartridge').config_get_readonly()
    ]])
end

function g.test_zones()
    local zones = {
        [M1.instance_uuid] = '1',
        [R1.instance_uuid] = '2'
    }
    set_zones(zones)

    local res = get_config()
    t.assert_equals(res.topology.servers[M1.instance_uuid].zone, '1')
    t.assert_equals(res.topology.servers[R1.instance_uuid].zone, '2')

    local zones = {
        [R1.instance_uuid] = ''
    }
    set_zones(zones)

    local res = get_config()
    t.assert_equals(res.topology.servers[M1.instance_uuid].zone, '1')
    t.assert_equals(res.topology.servers[R1.instance_uuid].zone, nil)

    local zones = {
        [R1.instance_uuid] = 1
    }
    t.assert_error_msg_contains (
        "bad argument params.zone to __edit_server"..
        " (?string expected, got number)",
        function() set_zones(zones) end
    )

end

local q_get_priority = [[
    local replicaset_uuid = ...
    local replicaset = require('vshard').router.routeall()
    replicaset = replicaset[replicaset_uuid]
    local priority_list = replicaset.priority_list
    local ret = {
        priority_list[1].uuid,
        priority_list[2].uuid,
        priority_list[3].uuid,
    }
    return ret
]]

function g.test_distances()
    -- distances:
    --     1   2   3

    -- 1   0   200 100
    -- 2   1   0   100
    -- 3   100 50  0
    --
    -- priorities:
    -- 1 zone: 1 3 2
    -- 2 zone: 2 1 3
    -- 3 zone: 3 2 1


    local distances = {
        ['1'] = {['1'] = 0, ['2'] = 200, ['3'] = 100},
        ['2'] = {['1'] = 1, ['2'] = 0, ['3'] = 100},
        ['3'] = {['1'] = 100, ['2'] = 50, ['3'] = 0},
    }

    local zones = {
        [M1.instance_uuid] = '1',
        [R1.instance_uuid] = '2',
        [R2.instance_uuid] = '3',
    }
    set_zones(zones)
    set_distances(distances)

    helpers.retrying({}, function()
        local res = get_config()
        t.assert_items_equals(res.zone_distances, distances)
        t.assert_equals(res.topology.servers[M1.instance_uuid].zone, '1')
        t.assert_equals(res.topology.servers[R1.instance_uuid].zone, '2')
        t.assert_equals(res.topology.servers[R2.instance_uuid].zone, '3')
    end)

    local response = M1.net_box:eval(q_get_priority, {helpers.uuid('a')})
    t.assert_equals(response,
    {
        M1.instance_uuid, -- 1
        R2.instance_uuid, -- 3
        R1.instance_uuid, -- 2
    })

    local response = R1.net_box:eval(q_get_priority, {helpers.uuid('a')})
    t.assert_equals(response,
    {
        R1.instance_uuid, -- 2
        M1.instance_uuid, -- 1
        R2.instance_uuid, -- 3
    })

    local response = R2.net_box:eval(q_get_priority, {helpers.uuid('a')})
    t.assert_equals(response,
    {
        R2.instance_uuid, -- 3
        R1.instance_uuid, -- 2
        M1.instance_uuid, -- 1
    })

    -- shuffle zones
    local zones = {
        [M1.instance_uuid] = '2',
        [R1.instance_uuid] = '1',
        [R2.instance_uuid] = '3',
    }
    set_zones(zones)
    helpers.retrying({}, function()
        local res = get_config()
        t.assert_equals(res.topology.servers[M1.instance_uuid].zone, '2')
        t.assert_equals(res.topology.servers[R1.instance_uuid].zone, '1')
        t.assert_equals(res.topology.servers[R2.instance_uuid].zone, '3')
    end)

    local response = M1.net_box:eval(q_get_priority, {helpers.uuid('a')})
    t.assert_equals(response,
    {
        M1.instance_uuid, -- 2
        R1.instance_uuid, -- 1
        R2.instance_uuid, -- 3
    })

    local response = R1.net_box:eval(q_get_priority, {helpers.uuid('a')})
    t.assert_equals(response,
    {
        R1.instance_uuid, -- 1
        R2.instance_uuid, -- 3
        M1.instance_uuid, -- 2
    })

    local response = R2.net_box:eval(q_get_priority, {helpers.uuid('a')})
    t.assert_equals(response,
    {
        R2.instance_uuid, -- 3
        M1.instance_uuid, -- 2
        R1.instance_uuid, -- 1
    })

end

function g.test_validation()
    local zones = {
        [M1.instance_uuid] = '1',
        [R1.instance_uuid] = '2',
        [R2.instance_uuid] = '3',
    }
    set_zones(zones)

    local distances = {['1'] = {['1'] = box.NULL}}
    local err = set_distances(distances)
    t.assert_equals(err, nil)

    local distances = {['1'] = 1}
    local err = set_distances(distances)
    t.assert_equals(err.err,
        "Zone must be map of relative weights"..
        " of other zones, got string"
    )

    local distances = {[1] = {['1'] = 1, ['2'] = 200}}
    local err = set_distances(distances)
    t.assert_equals(err.err,
        "Zone's label must be a string, got number"
    )

    local distances = {['1'] = {[1] = 1, ['2'] = 200}}
    local err = set_distances(distances)
    t.assert_equals(err.err,
        "Zone's label must be a string, got number"
    )

    local distances = {['1'] = {['1'] = 0, ['2'] = -200}}
    local err = set_distances(distances)
    t.assert_equals(err.err,
        "Distance must be nil or non-negative number"
    )

    local distances = {['1'] = {['1'] = 1, ['2'] = 200}}
    local err = set_distances(distances)
    t.assert_equals(err.err,
        "Distance of own zone must be either nil or 0"
    )
end
