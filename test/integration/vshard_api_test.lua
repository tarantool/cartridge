local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_test('test_get_cfg', function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = { {
                alias = 'A',
                roles = {'vshard-router'},
                servers = 1,
            }, {
                alias = 'B',
                roles = {'myrole'},
                servers = 2,
            },
        }
    })
    g.cluster:start()
    g.A1 = assert(g.cluster:server('A-1'))
    g.B1 = assert(g.cluster:server('B-1'))
    g.B2 = assert(g.cluster:server('B-2'))
end)

g.after_test('test_get_cfg', function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_get_cfg()
    local expected_cfg = {
        default = {
            bucket_count = 3000,
            collect_lua_garbage = false,
            read_only = false,
            rebalancer_disbalance_threshold = 1,
            rebalancer_max_receiving = 100,
            rebalancer_max_sending = 1,
            sched_move_quota = 1,
            sched_ref_quota = 300,
            sharding = {},
            sync_timeout = 1,
        },
    }

    local cfg = g.A1:call('cartridge_vshard_get_config', {})
    t.assert_equals(cfg, expected_cfg)

    local cfg = g.B1:call('cartridge_vshard_get_config', {})
    t.assert_equals(cfg, expected_cfg)

    expected_cfg.default.read_only = true
    local cfg = g.B2:call('cartridge_vshard_get_config', {})
    t.assert_equals(cfg, expected_cfg)
end


g.before_test('test_get_cfg_multisharding', function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_multisharding'),
        cookie = helpers.random_cookie(),
        replicasets = { {
                alias = 'R',
                roles = {'vshard-router'},
                servers = 1,
            },
        }
    })
    g.cluster:start()
    g.R1 = assert(g.cluster:server('R-1'))
end)

g.after_test('test_get_cfg_multisharding', function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_get_cfg_multisharding()
    local expected_cfg = {
        cold = {
            bucket_count = 2000,
            collect_lua_garbage = false,
            read_only = false,
            rebalancer_disbalance_threshold = 1,
            rebalancer_max_receiving = 100,
            rebalancer_max_sending = 1,
            sched_move_quota = 1,
            sched_ref_quota = 300,
            sharding = {},
            sync_timeout = 1,
        },
        hot = {
            bucket_count = 30000,
            collect_lua_garbage = false,
            read_only = false,
            rebalancer_disbalance_threshold = 1,
            rebalancer_max_receiving = 100,
            rebalancer_max_sending = 1,
            sched_move_quota = 1,
            sched_ref_quota = 300,
            sharding = {},
            sync_timeout = 1,
        },
    }

    local cfg = g.R1:call('cartridge_vshard_get_config', {})
    t.assert_equals(cfg, expected_cfg)
end
