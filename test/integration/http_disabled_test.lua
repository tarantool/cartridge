local fio = require('fio')
local t = require('luatest')
local g = t.group()
local h = require('test.helper')

g.before_all = function()
    g.cluster = h.Cluster:new({
        datadir = fio.tempdir(),
        server_command = h.entrypoint('srv_basic'),
        use_vshard = false,
        cookie = h.random_cookie(),

        replicasets = {
            {
                roles = {},
                alias = 'A',
                servers = {
                    {
                        env = {
                            TARANTOOL_WEBUI_PREFIX = 'def_prefix',
                        },
                    }
                }
            }, {
                roles = {},
                alias = 'B',
                servers = {
                    {
                        env = {
                            TARANTOOL_HTTP_ENABLED = 'false',
                            TARANTOOL_WEBUI_PREFIX = 'def_prefix',
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
            { servers { boxinfo { general { http_port http_host webui_prefix } } } }
        ]]
    })

    t.assert_items_equals(resp['data']['servers'], {{
            boxinfo = {
                general = { http_port = 8081, http_host = "0.0.0.0", webui_prefix = "/def_prefix" },
            },
        }, {
            boxinfo = {
                general = { http_port = box.NULL, http_host = box.NULL, webui_prefix = box.NULL },
            },
        },
    })
end
