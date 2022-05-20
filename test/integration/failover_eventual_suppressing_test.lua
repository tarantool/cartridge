local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {
            {
                alias = 'router',
                roles = {'vshard-router'},
                servers = 1,
            },
            {
                alias = 'storage',
                roles = {'vshard-router', 'vshard-storage'},
                servers = 2,
            },
        },
        env = {
            TARANTOOL_SUPPRESS_FAILOVER = 'true',
        }
    })

    g.cluster:server('storage-2').env.TARANTOOL_FAILOVER_SUPPRESS_THRESHOLD = 1
    g.cluster:server('storage-2').env.TARANTOOL_FAILOVER_SUPPRESS_TIMEOUT = 5

    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function set_master(uuid, master_uuid)
    g.cluster.main_server:graphql({
        query = [[
            mutation(
                $uuid: String!
                $master_uuid: [String!]!
            ) {
                edit_replicaset(
                    uuid: $uuid
                    master: $master_uuid
                )
            }
        ]],
        variables = {uuid = uuid, master_uuid = {master_uuid}}
    })
end

local function set_failover(enabled)
    local response = g.cluster.main_server:graphql({
        query = [[
            mutation($enabled: Boolean!) {
                cluster { failover(enabled: $enabled) }
            }
        ]],
        variables = {enabled = enabled}
    })
    return response.data.cluster.failover
end

g.test_failover_suppressed = function()
    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.cluster.main_server), {})
        t.assert_equals(helpers.get_suggestions(g.cluster.main_server), {})
    end)

    set_failover(true)
    set_master(g.cluster.replicasets[2].uuid, g.cluster:server('storage-1').instance_uuid )
    g.cluster:wait_until_healthy()

    -- 1) stop server-1 -> server-2 becomes a leader
    g.cluster:server('storage-1'):stop()
    helpers.retrying({timeout = 10}, function()
        t.assert_not(g.cluster:server('storage-2'):exec(function()
            assert(box.info.ro == false)
        end))
    end)

    -- 2) start server-1 -> server-1 returns leadership
    g.cluster:server('storage-1'):start()
    g.cluster:wait_until_healthy()
    helpers.retrying({timeout = 10}, function()
        g.cluster:server('storage-1'):exec(function()
            assert(box.info.ro == false)
        end)
        g.cluster:server('storage-2'):exec(function()
            assert(box.info.ro)
        end)
    end)

    -- 3) wait suppress_timeout -> now every change for storage-2 will be suppressed
    helpers.retrying({timeout = g.cluster:server('storage-2').env.TARANTOOL_FAILOVER_SUPPRESS_TIMEOUT}, function()
        g.cluster:server('storage-1'):exec(function()
            assert(box.info.ro == false)
        end)
        g.cluster:server('storage-2'):exec(function()
            assert(require('cartridge.failover').is_suppressed())
            assert(box.info.ro)
        end)
    end)
    -- 4) stop storage-1 again -> storage-2 is suppressed and won't become a leader
    g.cluster:server('storage-1'):stop()
    g.cluster:server('storage-2'):exec(function()
        assert(require('cartridge.failover').is_suppressed())
        assert(box.info.ro)
    end)
end
