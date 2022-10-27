local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local log = require('log')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = helpers.random_cookie(),

        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = {
                    {
                        alias = 'router',
                        instance_uuid = helpers.uuid('a', 'a', 1),
                        advertise_port = 13301,
                        http_port = 8081
                    }
                }
            }, {
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                all_rw = true,
                servers = {
                    {
                        alias = 'storage',
                        instance_uuid = helpers.uuid('b', 'b', 1),
                        advertise_port = 13302,
                        http_port = 8082
                    }, {
                        alias = 'storage-2',
                        instance_uuid = helpers.uuid('b', 'b', 2),
                        advertise_port = 13304,
                        http_port = 8084
                    }
                }
            }
        }
    })
    g.cluster:start()

    g.cluster:server('router'):graphql({
        query = [[
            mutation($uuid: String!) {
                expelServerResponse: cluster{edit_topology(
                    servers: [{
                        uuid: $uuid
                        expelled: true
                    }]
                ) {
                    servers{status}
                }}
            }
        ]],
        variables = {
            uuid = g.cluster:server('expelled').instance_uuid
        }
    })

    g.server = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'spare',
        command = helpers.entrypoint('srv_basic'),
        replicaset_uuid = helpers.uuid('b'),
        instance_uuid = helpers.uuid('b', 'b', 1),
        http_port = 8083,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13303,
        env = {
            TARANTOOL_WEBUI_BLACKLIST = '/cluster/code:/cluster/schema',
        }
    })

    g.server:start()
    t.helpers.retrying({timeout = 5}, function()
        g.server:graphql({query = '{ servers { uri } }'})
        g.cluster.main_server:graphql({
            query = 'mutation($uri: String!) { probe_server(uri:$uri) }',
            variables = {uri = g.server.advertise_uri},
        })
    end)
end)

g.before_each(function()
    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.cluster.main_server), {})
    end)
end)

g.after_all(function()
    g.cluster:stop()
    g.server:stop()
    fio.rmtree(g.cluster.datadir)
    fio.rmtree(g.server.workdir)
end)



function g.test_replicasets()
    local resp = g.cluster:server('router'):graphql({
        query = [[
            {
                replicasets {
                    uuid
                    alias
                    roles
                    status
                    master { uuid }
                    active_master { uuid }
                    servers { uri priority }
                    all_rw
                    weight
                }
            }
        ]]
    })

    t.assert_items_equals(resp.data.replicasets, {{
            uuid = helpers.uuid('a'),
            alias = 'unnamed',
            roles = {'vshard-router'},
            status = 'healthy',
            master = {uuid = helpers.uuid('a', 'a', 1)},
            active_master = {uuid = helpers.uuid('a', 'a', 1)},
            servers = {{uri = 'localhost:13301', priority = 1}},
            all_rw = false,
            weight = box.NULL,
        }, {
            uuid = helpers.uuid('b'),
            alias = 'unnamed',
            roles = {'vshard-storage'},
            status = 'healthy',
            master = {uuid = helpers.uuid('b', 'b', 1)},
            active_master = {uuid = helpers.uuid('b', 'b', 1)},
            weight = 1,
            all_rw = true,
            servers = {
                {uri = 'localhost:13302', priority = 1},
                {uri = 'localhost:13304', priority = 2},
            }
        }
    })
end
