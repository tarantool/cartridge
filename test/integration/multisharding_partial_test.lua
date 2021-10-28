local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_each(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_multisharding'),
        cookie = 'secret',
        replicasets = {
            {
                alias = 'router',
                roles = {'vshard-router'},
                servers = 1
            },
            {
                alias = 'storage-hot',
                roles = {'vshard-storage'},
                vshard_group = 'hot',
                servers = 1
            },
        },
    })

    g.server = helpers.Server:new({
        alias = 'storage-cold',
        workdir = fio.pathjoin(g.cluster.datadir, 'spare'),
        command = helpers.entrypoint('srv_multisharding'),
        replicaset_uuid = helpers.uuid('d'),
        instance_uuid = helpers.uuid('d', 'd', 1),
        http_port = 8085,
        vshard_group = nil,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13305,

    })

    g.cluster:start()
    g.server:start()
end)

g.after_each(function()
    g.cluster:stop()
    g.server:stop()
    fio.rmtree(g.cluster.datadir)
end)

g.test_bootstrap_vshard_by_group = function()
    local main = g.cluster.main_server

    -- bootstrap only hot group
    g.cluster:bootstrap_vshard()

    t.assert_equals(helpers.list_cluster_issues(main), {{
        level = 'warning',
        topic = 'vshard',
        message = [[Group "cold" wasn't bootstrapped: Sharding config is empty. ]] ..
            [[Maybe you have no instances with such group?]],
        instance_uuid = main.instance_uuid,
        replicaset_uuid = main.replicaset_uuid,
    }})

    -- join server with cold group
    g.cluster:join_server(g.server)
    g.server:setup_replicaset({
        roles = {'vshard-storage'},
        vshard_group = 'cold',
        uuid = g.server.replicaset_uuid,
        alias = 'storage-cold',
        master = {g.server.instance_uuid},
        weight = 1,
    })

    -- bootstrap cold group
    g.cluster:bootstrap_vshard()
    t.assert_equals(helpers.list_cluster_issues(main), {})
end

g.test_bootstrap_twice = function()
    local main = g.cluster.main_server

    -- bootstrap only hot group
    g.cluster:bootstrap_vshard()

    t.assert_equals(helpers.list_cluster_issues(main), {{
        level = 'warning',
        topic = 'vshard',
        message = [[Group "cold" wasn't bootstrapped: Sharding config is empty. ]] ..
            [[Maybe you have no instances with such group?]],
        instance_uuid = main.instance_uuid,
        replicaset_uuid = main.replicaset_uuid,
    }})

    -- try again
    t.assert_error_msg_contains('already bootstrapped', g.cluster.bootstrap_vshard, g.cluster)
end
