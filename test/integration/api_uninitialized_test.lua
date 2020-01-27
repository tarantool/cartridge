local fio = require('fio')
local t = require('luatest')
local g = t.group()

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.server = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'dummy',
        command = test_helper.server_command,
        http_port = 8181,
        cluster_cookie = 'test-cluster-cookie',
        advertise_port = 13301,
        env = {
            TARANTOOL_CUSTOM_PROC_TITLE = 'test-title',
        },
    })

    g.server:start()

    t.helpers.retrying({timeout = 5}, function()
        g.server:graphql({query = '{}'})
    end)
end

g.after_all = function()
    g.server:stop()
    fio.rmtree(g.server.workdir)
end

function g.test_uninitialized()
    local resp = g.server:graphql({
        query = [[
            {
                servers {
                    uri
                    replicaset { roles }
                }
                replicasets {
                    status
                }
                cluster {
                    self {
                        uri
                        uuid
                        alias
                    }
                    can_bootstrap_vshard
                    vshard_bucket_count
                }
            }
        ]]
    })

    local servers = resp['data']['servers']
    t.assert_equals(#servers, 1)
    t.assert_equals(servers[1], {
        uri = 'localhost:13301',
        replicaset = box.NULL
    })
    t.assert_almost_equals(
        g.server:graphql({
            query = [[{ servers { uri clock_delta } }]]
        }).data.servers[1].clock_delta,
        0, 1e-2
    )

    local replicasets = resp['data']['replicasets']
    t.assert_equals(#replicasets, 0)

    t.assert_equals(resp['data']['cluster']['self'], {
        uri = 'localhost:13301',
        alias = 'dummy',
        uuid = box.NULL
    })

    t.assert_equals(resp['data']['cluster']['can_bootstrap_vshard'], false)
    t.assert_equals(resp['data']['cluster']['vshard_bucket_count'], 3000)

    t.assert_error_msg_contains(
        [[Invalid attempt to call join_server().]] ..
        [[ This instance isn't bootstrapped yet]] ..
        [[ and advertises uri="localhost:13301"]] ..
        [[ while you are joining uri="127.0.0.1:13301".]],
        function()
            g.server:graphql({
                query = [[
                    mutation {
                        join_server(uri: "127.0.0.1:13301")
                    }
                ]]
            })
        end
    )

    local resp = g.server:graphql({
        query = [[{
            cluster { failover }
        }]]
    })

    t.assert_equals(resp['data']['cluster']['failover'], false)

    t.assert_error_msg_contains(
        'Not bootstrapped yet',
        function()
            return g.server:graphql({
                query = [[
                    mutation {
                        cluster { failover(enabled: false) }
                    }
                ]]
            })
        end
    )

    t.assert_error_msg_contains(
        "Cluster isn't bootstrapped yet",
        function()
            return g.server:graphql({
                query = [[
                    mutation { cluster { config(sections: []) {} } }
                ]]
            })
        end
    )
    t.assert_error_msg_contains(
        "Cluster isn't bootstrapped yet",
        function()
            return g.server:graphql({
                query = [[
                    query { cluster { config {} } }
                ]]
            })
        end
    )


    t.assert_error_msg_contains(
        "Cluster isn't bootstrapped yet",
        function()
            return g.server:graphql({
                query = [[
                    mutation { cluster { schema(as_yaml: "") {} } }
                ]]
            })
        end
    )
    t.assert_error_msg_contains(
        "Cluster isn't bootstrapped yet",
        function()
            return g.server:graphql({
                query = [[
                    query { cluster { schema {as_yaml} } }
                ]]
            })
        end
    )

    t.assert_equals(
        g.server.net_box:eval([[return require('title').get()]]),
        'tarantool srv_basic.lua: test-title',
        "Instance's title wasn't set")
end
