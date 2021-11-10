local fio = require('fio')
local t = require('luatest')
local g = t.group()
local h = require('test.helper')

g.before_all = function()
    g.cluster = h.Cluster:new({
        datadir = fio.tempdir(),
        server_command = h.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = h.random_cookie(),

        replicasets = {
            {
                roles = {'vshard-router'},
                alias = 'router',
                servers = {
                    {
                        advertise_port = 13301,
                        http_port = 8081,
                    }
                }
            }, {
                roles = {'vshard-storage'},
                alias = 'storage',
                servers = {
                    {
                        advertise_port = 13302,
                        http_port = 8082,
                        env = {
                            TARANTOOL_HTTP_ENABLED = 'false',
                        },
                    },
                }
            }
        }
    })
    g.cluster:start()
end

g.before_each(function()
    h.retrying({}, function()
        t.assert_equals(h.list_cluster_issues(g.cluster.main_server), {})
    end)
end)

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_http_port()
    local router = g.cluster.main_server
    local resp = router:graphql({
        query = [[
            { servers { boxinfo { general { http_port } } } }
        ]]
    })

    t.assert_items_equals(resp['data']['servers'], {{
            boxinfo = {
                general = { http_port = 8081 },
            },
        }, {
            boxinfo = {
                general = { http_port = box.NULL },
            },
        },
    })
end
