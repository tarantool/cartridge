local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {
                    {
                        alias = 'master',
                        instance_uuid = helpers.uuid('a', 'a', 1),
                        http_port = 8081,
                        advertise_port = 13301,
                    }
                },
            },
        },
    })
    g.cluster:start()

    g.server = helpers.Server:new({
        workdir = fio.pathjoin(g.cluster.datadir, 'server'),
        alias = 'server',
        command = helpers.entrypoint('srv_basic'),
        replicaset_uuid = helpers.uuid('b'),
        instance_uuid = helpers.uuid('b', 'b', 1),
        http_port = 8082,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13302,
    })
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

function g.test_call()
    -- RPC calls must work properly right after synchronous join
    local res = g.cluster.main_server:graphql({query = [[
        mutation {
            join_server(
                uri: "localhost:13302"
                instance_uuid: "bbbbbbbb-bbbb-0000-0000-000000000001"
                replicaset_uuid: "bbbbbbbb-0000-0000-0000-000000000000"
                roles: ["myrole"]
                timeout: 5
            )
        }
    ]]})
    t.assert_equals(res['data']['join_server'], true)

    t.helpers.retrying({}, function() g.server:connect_net_box() end)
    local res, err = g.cluster.main_server:eval([[
        local rpc = require('cartridge.rpc')
        return rpc.call(...)
    ]], {'myrole', 'get_state'})
    t.assert_equals(err, nil)
    t.assert_equals(res, 'initialized')
end
