local fio = require('fio')
local json = require('json')
local checks = require('checks')
local topology = require('cartridge.topology')

local t = require('luatest')
local g = t.group()

local topology_cfg = {
    replicasets = {
        ['A'] = {master = {'A1', 'A2', 'A4'}},
        ['B'] = {master = {'B1', 'E1'}},
        ['C'] = {master = 'C2'}
    },

    servers = {
        ['A1'] = {replicaset_uuid = 'A', disabled = false},
        ['A2'] = {replicaset_uuid = 'A', disabled = true},
        ['A3'] = {replicaset_uuid = 'A'},
        ['A4'] = {replicaset_uuid = 'A'},
        ['A5'] = {replicaset_uuid = 'A'},
        ['B1'] = {replicaset_uuid = nil},
        ['C1'] = {replicaset_uuid = 'C'},
        ['C2'] = {replicaset_uuid = 'C'},
        ['C3'] = {replicaset_uuid = 'C'},
        ['E1'] = 'expelled',
        ['E2'] = 'expelled',
    }
}

local function test_order(uuid, new_order, expected_order)
    checks('string', '?table', 'table')

    local leaders_order = topology.get_leaders_order(
        topology_cfg, uuid, new_order
    )

    t.assert_equals(
        leaders_order,
        expected_order,
        "Unexpected leaders order")
end


function g.before_all()
    g.tempdir = fio.tempdir()
end

function g.after_all()
    fio.rmtree(g.tempdir)
end

function g.test_leader_order()
    test_order('A',
        nil,
        {'A1', 'A2', 'A4', 'A3', 'A5'}
    )
    test_order('A',
        {},
        {'A1', 'A2', 'A4', 'A3', 'A5'}
    )
    test_order('A',
        {'A2'},
        {'A2', 'A1', 'A4', 'A3', 'A5'}
    )
    test_order('A',
        {'A3', 'A1'},
        {'A3', 'A1', 'A2', 'A4', 'A5'}
    )
    test_order('A',
        {'A4', 'A1'},
        {'A4', 'A1', 'A2', 'A3', 'A5'}
    )
    test_order('A',
        {'A5', 'A1'},
        {'A5', 'A1', 'A2', 'A4', 'A3'}
    )
    test_order('A',
        {'A1', 'A2', 'A3'},
        {'A1', 'A2', 'A3', 'A4', 'A5'}
    )
    test_order('A',
        {'A5', 'A4', 'A3', 'A2', 'A1', 'A0'},
        {'A5', 'A4', 'A3', 'A2', 'A1', 'A0'}
    )
    test_order('A',
        {'Z0'},
        {'Z0', 'A1', 'A2', 'A4', 'A3', 'A5'}
    )

    test_order('B',
        {},
        {'B1', 'E1'}
    )
    test_order('B',
        {'E1'},
        {'E1', 'B1'}
    )
    test_order('B',
        {'E2'},
        {'E2', 'B1', 'E1'}
    )
    test_order('B',
        {'Z0'},
        {'Z0', 'B1', 'E1'}
    )

    test_order('C',
        {},
        {'C2', 'C1', 'C3'}
    )

    test_order('C',
        {'C3'},
        {'C3', 'C2', 'C1'}
    )

    t.assert_error_msg_contains(
        'Inconsistent topology and uuid args provided',
        topology.get_leaders_order,
        topology_cfg,
        'D')

    topology_cfg.servers = {}
    test_order('A',
        {'A3', 'A2'},
        {'A3', 'A2', 'A1', 'A4'}
)
end
