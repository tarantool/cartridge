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

local function get_replicaset()
    local res = g.cluster.main_server:graphql({
        query = [[{
            replicasets(uuid: "aaaaaaaa-0000-0000-0000-000000000000") {
                weight
                vshard_group
            }
        }]]
    })
    return res['data']['replicasets'][1]
end

local function set_replicaset_roles(roles)
    g.cluster.main_server:graphql({
        query = [[
            mutation ($roles: [String!]){
                edit_replicaset(
                    uuid: "aaaaaaaa-0000-0000-0000-000000000000"
                    roles: $roles
                )
            }
        ]],
        variables = {
            roles = roles,
        }
    })
end

function g.test()
    -- Test that vshard storages can be disabled without any limitations
    -- unless it has already been bootstrapped

    t.assert_equals(
        get_replicaset(),
        {
            weight = box.NULL,
            vshard_group = box.NULL,
        }
    )

    set_replicaset_roles({'vshard-router', 'vshard-storage'})

    t.assert_equals(
        get_replicaset(),
        {
            weight = 1,
            vshard_group = "default",
        }
    )

    set_replicaset_roles({})

    t.assert_equals(
        get_replicaset(),
        {
            weight = box.NULL,
            vshard_group = "default",
        }
    )
end
