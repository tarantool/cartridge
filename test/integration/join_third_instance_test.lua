local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        failover = 'stateful',
        stateboard_entrypoint = helpers.entrypoint('srv_stateboard'),
        replicasets = {
            {
                alias = 'storage',
                uuid = helpers.uuid('a'),
                roles = {'failover-coordinator'},
                servers = 2,
            },
        },
    })

    g.server = helpers.Server:new({
        workdir = fio.tempdir(),
        command = helpers.entrypoint('srv_basic'),
        alias = 'storage-3',
        cluster_cookie = g.cluster.cookie,
        replicaset_uuid = helpers.uuid('a'),
        instance_uuid = helpers.uuid('a', 'a', 3),
        http_port = 8083,
        advertise_port = 13303,
    })

    g.server:start()
    g.cluster:start()
end)

g.after_all(function()
    g.server:stop()
    g.cluster:stop()
    fio.rmtree(g.server.workdir)
    fio.rmtree(g.cluster.datadir)
end)

g.test_join_third_storage = function()
    g.cluster.main_server:graphql({
        query = [[
            mutation(
                $replicaset_uuid: String!
                $instance_uuid: String!
                $force: Boolean
            ) {
            cluster {
                failover_promote(
                    replicaset_uuid: $replicaset_uuid
                    instance_uuid: $instance_uuid
                    force_inconsistency: $force
                )
            }
        }]],
        variables = {
            replicaset_uuid = helpers.uuid('a'),
            instance_uuid = g.cluster.servers[2].instance_uuid,
            force = true,
        },
    })
    g.cluster:join_server(g.server)
    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.cluster.main_server), {})
    end)
end
