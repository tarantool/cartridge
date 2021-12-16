local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    local cookie = helpers.random_cookie()
    g.cluster1 = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = cookie,
        replicasets = {
            {
                alias = 'master',
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {{
                    http_port = 8081,
                    advertise_port = 13301,
                    instance_uuid = helpers.uuid('a', 'a', 1)
                }},
            }
        },
    })

    g.cluster1:start()

    g.cluster2 = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = cookie,
        replicasets = {
            {
                alias = 'master',
                uuid = helpers.uuid('b'),
                roles = {},
                servers = {{
                    http_port = 8082,
                    advertise_port = 13302,
                    instance_uuid = helpers.uuid('b', 'b', 1)
                }},
            }
        },
    })

    g.cluster2:start()
end

g.after_all = function()
    g.cluster1:stop()
    fio.rmtree(g.cluster1.datadir)
    g.cluster2:stop()
    fio.rmtree(g.cluster2.datadir)
end

function g.test_two_clusters()
    local res = g.cluster1.main_server:graphql({query = [[
            mutation { join_server(uri: "localhost:13302") }
        ]],
        raise = false,
    })
    t.assert_str_contains(res.errors[1].message, "collision with another server")
end
