local fio = require('fio')
local t = require('luatest')
local g = t.group('vshard_weight')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {
                    {
                        alias = 'main',
                        http_port = 8081,
                        advertise_port = 13301,
                        instance_uuid = helpers.uuid('a', 'a', 1)
                    }
                },
            },
        },
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_storage_weight()
    -- Test that vshard storages can be disabled without any limitations
    -- unless it has already been bootstrapped

    g.cluster.main_server:graphql({query = [[
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-0000-0000-000000000000"
                roles: ["vshard-router", "vshard-storage"]
            )
        }
    ]]})

    local res = g.cluster.main_server:graphql({query = [[{
            replicasets(uuid: "aaaaaaaa-0000-0000-0000-000000000000") {
                weight
            }
        }
    ]]})
    local replicasets = res['data']['replicasets']
    t.assert_equals(replicasets[1]['weight'], 1)

    g.cluster.main_server:graphql({query = [[
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-0000-0000-000000000000"
                roles: []
            )
        }
    ]]})
end
