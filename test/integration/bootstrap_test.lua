local fio = require('fio')
local log = require('log')
local t = require('luatest')
local g = t.group('bootstrap')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.setup = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'myrole'},
                servers = {
                    {
                        alias = 'master',
                        instance_uuid = helpers.uuid('a', 'a', 1)
                    }, {
                        alias = 'replica',
                        instance_uuid = helpers.uuid('a', 'a', 2)
                    }
                },
            },
        },
    })
    g.cluster:start()
end

g.teardown = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_cookie_change()
    local master = g.cluster:server('master')
    local replica = g.cluster:server('replica')

    g.cluster:stop()
    log.warn('Cluster stopped')

    local cc = 'new-cluster-cookie'
    for _, srv in pairs(g.cluster.servers) do
        srv.cluster_cookie = cc
        srv.env.TARANTOOL_CLUSTER_COOKIE = cc
        srv.net_box_credentials.password = cc
    end
    log.warn('Cluster cookie changed')


    master:start()
    replica:start()
    g.cluster:retrying({}, function()
        master:connect_net_box()
        replica:connect_net_box()
    end)
    log.warn('Cluster restarted')

    local cookie = master.net_box:eval([[
        local cluster_cookie = require('cartridge.cluster-cookie')
        return cluster_cookie.cookie()
    ]])

    t.assert_equals(cookie, 'new-cluster-cookie')
    g.cluster:wait_until_healthy()

    local resp = g.cluster.main_server:graphql({
        query = [[{
            servers {
                uuid
                boxinfo {
                    general { instance_uuid }
                }
            }
        }]]
    })

    t.assert_equals(resp.data.servers, {{
        boxinfo={general={instance_uuid=master.instance_uuid}},
        uuid=master.instance_uuid
    }, {
        boxinfo={general={instance_uuid=replica.instance_uuid}},
        uuid=replica.instance_uuid
    }})

end
