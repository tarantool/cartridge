local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = {{
                    alias = 'A1',
                    instance_uuid = helpers.uuid('a', 'a', 1),
                    advertise_port = 13301,
                    http_port = 8081,
                }}
            }, {
                uuid = helpers.uuid('b'),
                roles = {'myrole'},
                servers = {
                    {
                        alias = 'B1',
                        instance_uuid = helpers.uuid('b', 'b', 1),
                        advertise_port = 13302,
                        http_port = 8082,
                    },{
                        alias = 'B2',
                        instance_uuid = helpers.uuid('b', 'b', 2),
                        advertise_port = 13303,
                        http_port = 8083,
                    }
                }
            }
        }
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_get_cfg()
    local A1 = g.cluster:server('A1')
    local B1 = g.cluster:server('B1')

    local cfg = A1:call('vshard_get_cfg', {})
    t.assert_equals(cfg, {
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
    })

    local cfg = B1:call('vshard_get_cfg', {})
    t.assert_equals(cfg, {
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
    })
end
