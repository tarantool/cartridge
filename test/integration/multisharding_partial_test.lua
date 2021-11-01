local fio = require('fio')
local t = require('luatest')
local g = t.group()
local h = require('test.helper')


g.before_each(function()
    g.cluster = h.Cluster:new({
        datadir = fio.tempdir(),
        server_command = h.entrypoint('srv_multisharding'),
        cookie = h.random_cookie(),
        replicasets = {
            {
                alias = 'storage-hot',
                roles = {'vshard-storage'},
                vshard_group = 'hot',
                servers = 1
            },
        },
    })

    g.router = h.Server:new({
        alias = 'router',
        workdir = fio.pathjoin(g.cluster.datadir, 'router'),
        command = h.entrypoint('srv_multisharding'),
        replicaset_uuid = h.uuid('c'),
        instance_uuid = h.uuid('c', 'c', 1),
        http_port = 8084,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13304,
    })

    g.storage = h.Server:new({
        alias = 'storage-cold',
        workdir = fio.pathjoin(g.cluster.datadir, 'storage-cold'),
        command = h.entrypoint('srv_multisharding'),
        replicaset_uuid = h.uuid('d'),
        instance_uuid = h.uuid('d', 'd', 1),
        http_port = 8085,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13305,
    })

    g.cluster:start()
    g.storage:start()
    g.router:start()
end)

g.after_each(function()
    g.cluster:stop()
    g.storage:stop()
    fio.rmtree(g.cluster.datadir)
end)

g.test_bootstrap_vshard_by_group = function()
    local main = g.cluster.main_server

    -- try to bootsrap vshard without router
    t.assert_error_msg_contains('No remotes with role "vshard-router" available',
        g.cluster.bootstrap_vshard, g.cluster)

    -- join router
    g.cluster:join_server(g.router)
    g.router:setup_replicaset({
        roles = {'vshard-router'},
        uuid = g.router.replicaset_uuid,
        alias = 'router',
        master = {g.router.instance_uuid},
    })

    -- bootstrap only hot group
    g.cluster:bootstrap_vshard()

    t.assert_equals(h.list_cluster_issues(main), {{
        level = 'warning',
        topic = 'vshard',
        message = [[Group "cold" wasn't bootstrapped: Sharding config is empty. ]] ..
            [[Maybe you have no instances with such group?]],
        instance_uuid = g.router.instance_uuid,
        replicaset_uuid = g.router.replicaset_uuid,
    }})

    -- try to bootstrap again
    t.assert_error_msg_contains('already bootstrapped', g.cluster.bootstrap_vshard, g.cluster)

    -- join server with cold group
    g.cluster:join_server(g.storage)
    g.storage:setup_replicaset({
        roles = {'vshard-storage'},
        vshard_group = 'cold',
        uuid = g.storage.replicaset_uuid,
        alias = 'storage-cold',
        master = {g.storage.instance_uuid},
        weight = 1,
    })

    -- bootstrap cold group
    g.cluster:bootstrap_vshard()
    t.assert_equals(h.list_cluster_issues(main), {})

    -- try to bootstrap again
    t.assert_error_msg_contains('already bootstrapped', g.cluster.bootstrap_vshard, g.cluster)
end
