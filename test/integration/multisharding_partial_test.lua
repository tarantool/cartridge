local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_multisharding'),
        cookie = 'secret',
        replicasets = {
            {
                alias = 'storage-hot',
                roles = {'vshard-storage'},
                vshard_group = 'hot',
                servers = 1
            },
            {
                alias = 'router',
                roles = {'vshard-router'},
                servers = 1
            }
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
    t.helpers.retrying({}, function()
        g.server:graphql({query = '{ servers { uri } }'})
    end)
end

g.after_all = function()
    g.cluster:stop()
    g.server:stop()
    fio.rmtree(g.cluster.datadir)
end

g.test_bootstrap_vshard_by_group = function()
    g.cluster:bootstrap_vshard()

    g.cluster:join_server(g.server)
    g.server:setup_replicaset({
        roles = {'vshard-storage'},
        vshard_group = 'cold',
        uuid = g.server.replicaset_uuid,
        alias = 'storage-cold',
        master = {g.server.instance_uuid},
        weight = 1,
    })
end
