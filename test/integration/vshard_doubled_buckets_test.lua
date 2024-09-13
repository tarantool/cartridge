local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        use_vshard = true,
        replicasets = {
            {
                alias = 'router',
                roles = {'vshard-router'},
                servers = 1,
            },
            {
                alias = 'storage-1',
                roles = {'vshard-storage'},
                servers = 1,
            },
            {
                alias = 'storage-2',
                roles = {'vshard-storage'},
                servers = 1,
            },
        },
        env = {
            TARANTOOL_CHECK_DOUBLED_BUCKETS = 'true',
            TARANTOOL_CHECK_DOUBLED_BUCKETS_PERIOD = '10',
        },
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_doubled_buckets()
    local bucket = g.cluster:server('storage-2-1'):exec(function()
        return box.space._bucket:select(nil, {limit = 1})[1]
    end)

    g.cluster:server('storage-1-1'):exec(function(bucket)
        box.space._bucket:run_triggers(false)
        return box.space._bucket:insert(bucket)
    end, {bucket})

    t.helpers.retrying({timeout = 20}, function()
        t.assert_covers(helpers.list_cluster_issues(g.cluster.main_server), {
            {
                level = 'warning',
                topic = 'vshard',
                message = "Cluster has 1 doubled buckets. " ..
                "Call require('cartridge.vshard-utils').find_doubled_buckets() for details",
            },
        })
    end)

    g.cluster:server('storage-1-1'):exec(function(bucket)
        return box.space._bucket:delete(bucket[1])
    end, {bucket})

    t.helpers.retrying({timeout = 20}, function()
        t.assert_covers(helpers.list_cluster_issues(g.cluster.main_server), {})
    end)
end
