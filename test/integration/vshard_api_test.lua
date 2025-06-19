local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local function get_config()
    local vshard = require('cartridge.lua-api.vshard')
    return vshard.get_config()
end

g.before_test('test_get_cfg', function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = 'qwerty123',
        replicasets = { {
                alias = 'A',
                roles = {'vshard-router'},
                servers = 1,
            }, {
                alias = 'B',
                roles = {'vshard-storage'},
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
            connection_fetch_schema = true,
            read_only = false,
            rebalancer_disbalance_threshold = 1,
            rebalancer_mode = 'auto',
            rebalancer_max_receiving = 100,
            rebalancer_max_sending = 1,
            sched_move_quota = 1,
            sched_ref_quota = 300,
            sharding = {
                [g.cluster.replicasets[2].uuid] = {
                    replicas = {
                        [g.B1.instance_uuid] = {
                            master = true,
                            name = "localhost:13302",
                            uri = "admin:qwerty123@localhost:13302",
                        },
                        [g.B2.instance_uuid] = {
                            master = false,
                            name = "localhost:13303",
                            uri = "admin:qwerty123@localhost:13303",
                        },
                    },
                    weight = 1,
                },
            },
            sync_timeout = 1,
        },
    }

    local cfg = g.A1:exec(get_config)
    t.assert_equals(cfg, expected_cfg)

    local cfg = g.B1:exec(get_config)
    t.assert_equals(cfg, expected_cfg)

    expected_cfg.default.read_only = true
    local cfg = g.B2:exec(get_config)
    t.assert_equals(cfg, expected_cfg)
end


g.before_test('test_get_cfg_multisharding', function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_multisharding'),
        cookie = 'ytrewq321',
        use_vshard = true,
        replicasets = {
            {
                alias = 'router',
                roles = {'vshard-router'},
                servers = 1,
            }, {
                alias = 'storage-hot',
                roles = {'vshard-storage'},
                vshard_group = 'hot',
                servers = 1,
            }, {
                alias = 'storage-cold',
                roles = {'vshard-storage'},
                vshard_group = 'cold',
                servers = 1,
            },
        },
    })
    g.cluster:start()
    g.router = assert(g.cluster:server('router-1'))
    g.storage_hot = assert(g.cluster:server('storage-hot-1'))
    g.storage_cold = assert(g.cluster:server('storage-cold-1'))
end)

g.after_test('test_get_cfg_multisharding', function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_get_cfg_multisharding()
    local expected_cfg = {
        hot = {
            bucket_count = 30000,
            collect_lua_garbage = false,
            connection_fetch_schema = true,
            read_only = false,
            rebalancer_disbalance_threshold = 1,
            rebalancer_mode = 'auto',
            rebalancer_max_receiving = 100,
            rebalancer_max_sending = 1,
            sched_move_quota = 1,
            sched_ref_quota = 300,
            sharding = {
                [g.cluster.replicasets[2].uuid] = {
                    replicas = {
                        [g.storage_hot.instance_uuid] = {
                            master = true,
                            name = "localhost:13302",
                            uri = "admin:ytrewq321@localhost:13302",
                        },
                    },
                    weight = 1,
                },
            },
            sync_timeout = 1,
        },
        cold = {
            bucket_count = 2000,
            collect_lua_garbage = false,
            connection_fetch_schema = true,
            read_only = false,
            rebalancer_disbalance_threshold = 1,
            rebalancer_max_receiving = 100,
            rebalancer_mode = 'auto',
            rebalancer_max_sending = 1,
            sched_move_quota = 1,
            sched_ref_quota = 300,
            sharding = {
                [g.cluster.replicasets[3].uuid] = {
                    replicas = {
                        [g.storage_cold.instance_uuid] = {
                            master = true,
                            name = "localhost:13303",
                            uri = "admin:ytrewq321@localhost:13303",
                        },
                    },
                    weight = 1,
                },
            },
            sync_timeout = 1,
        },
    }

    local cfg = g.router:exec(get_config)
    t.assert_equals(cfg, expected_cfg)

    local cfg = g.storage_hot:exec(get_config)
    t.assert_equals(cfg, expected_cfg)

    local cfg = g.storage_cold:exec(get_config)
    t.assert_equals(cfg, expected_cfg)
end
