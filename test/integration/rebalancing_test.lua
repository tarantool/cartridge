local fio = require('fio')
local t = require('luatest')
local g = t.group('rebalancing')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        use_vshard = true,
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = {
                    {
                        alias = 'router',
                        http_port = 8081,
                        advertise_port = 13301,
                        instance_uuid = helpers.uuid('a', 'a', 1)
                    }
                },
            },
            {
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                servers = {
                    {
                        alias = 'storage-1',
                        http_port = 8082,
                        advertise_port = 13302,
                        instance_uuid = helpers.uuid('b', 'b', 1)
                    }
                },
            },
            {
                uuid = helpers.uuid('c'),
                roles = {'vshard-storage'},
                servers = {
                    {
                        alias = 'storage-2',
                        http_port = 8083,
                        advertise_port = 13303,
                        instance_uuid = helpers.uuid('c', 'c', 1)
                    }
                },
            },
            {
                uuid = helpers.uuid('d'),
                roles = {'vshard-storage'},
                servers = {
                    {
                        alias = 'storage-3',
                        http_port = 8084,
                        advertise_port = 13304,
                        instance_uuid = helpers.uuid('d', 'd', 1)
                    }
                },
            },
            {
                uuid = helpers.uuid('e'),
                roles = {'vshard-storage'},
                servers = {
                    {
                        alias = 'storage-4',
                        http_port = 8085,
                        advertise_port = 13305,
                        instance_uuid = helpers.uuid('e', 'e', 1)
                    }
                },
            },
        },
    })
    g.cluster:start()


    g.set_zero_weight = function(uuid)
        g.cluster.main_server:graphql({query = [[
            mutation ($uuid: String!) {
                edit_replicaset(
                    uuid: $uuid
                    weight: 0
                )
            }]],
            variables = {uuid = uuid}
        })
    end
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_nonzero_weight()
    -- It's prohibited to disable vshard-storage role with non-zero weight
    local remove_storage = function()
        return g.cluster.main_server:graphql({query = [[
            mutation {
                edit_replicaset(
                    uuid: "cccccccc-0000-0000-0000-000000000000"
                    roles: []
                )
            }
        ]]})
    end

    t.assert_error_msg_contains(
        "replicasets[cccccccc-0000-0000-0000-000000000000] is a vshard-storage which can't be removed",
        remove_storage
    )

    -- It's prohibited to expel storage with non-zero weight
    local expel_server = function()
        g.cluster.main_server:graphql({query = [[
            mutation {
                expel_server(
                    uuid: "cccccccc-cccc-0000-0000-000000000001"
                )
            }
        ]]})
    end
    t.assert_error_msg_contains(
        "replicasets[cccccccc-0000-0000-0000-000000000000] is a vshard-storage which can't be removed",
        expel_server
    )
end

function g.test_rebalancing_unfinished()
    g.set_zero_weight(helpers.uuid('d'))

    -- It's prohibited to disable vshard-storage role until rebalancing finishes
    local edit_replicaset = function()
        return g.cluster.main_server:graphql({query = [[
            mutation {
                edit_replicaset(
                    uuid: "dddddddd-0000-0000-0000-000000000000"
                    roles: []
                )
            }
        ]]})
    end
    t.assert_error_msg_contains(
        "replicasets[dddddddd-0000-0000-0000-000000000000] rebalancing isn't finished yet",
        edit_replicaset
    )

    -- It's prohibited to expel storage until rebalancing finishes
    local expel_server = function()
        return g.cluster.main_server:graphql({query = [[
            mutation {
                expel_server(
                    uuid: "dddddddd-dddd-0000-0000-000000000001"
                )
            }
        ]]})
    end
    t.assert_error_msg_contains(
        "replicasets[dddddddd-0000-0000-0000-000000000000] rebalancing isn't finished yet",
        expel_server
    )
end

function g.test_success()
    g.set_zero_weight(helpers.uuid('b'))

    -- Speed up rebalancing
    g.cluster:server('storage-1').net_box:eval([[
        while vshard.storage.buckets_count() > 0 do
            vshard.storage.rebalancer_wakeup()
            require('fiber').sleep(0.1)
        end
    ]])

    -- Now it's possible to disable vshard-storage role
    g.cluster.main_server:graphql({query = [[
        mutation {
            edit_replicaset(
                uuid: "bbbbbbbb-0000-0000-0000-000000000000"
                roles: []
            )
        }
    ]]})

    -- Now it's possible to expel the storage
    g.cluster.main_server:graphql({query = [[
        mutation {
            expel_server(
                uuid: "bbbbbbbb-bbbb-0000-0000-000000000001"
            )
        }
    ]]})
end
