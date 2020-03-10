local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        use_vshard = true,
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'vshard-router', 'vshard-storage'},
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
        },
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function set_weight(srv, weight)
    g.cluster.main_server:graphql({
        query = [[
            mutation ($uuid: String! $weight: Float!) {
                edit_replicaset(
                    uuid: $uuid
                    weight: $weight
                )
            }
        ]],
        variables = {
            uuid = srv.replicaset_uuid,
            weight = weight,
        },
    })
end

local function disable_storage_role(srv)
    g.cluster.main_server:graphql({
        query = [[
            mutation ($uuid: String!) {
                edit_replicaset(
                    uuid: $uuid
                    roles: []
                )
            }
        ]],
        variables = {
            uuid = srv.replicaset_uuid,
        },
    })
end

local function expel_server(srv)
    g.cluster.main_server:graphql({
        query = [[
            mutation ($uuid: String!) {
                expel_server(uuid: $uuid)
            }
        ]],
        variables = {
            uuid = srv.instance_uuid,
        },
    })
end

function g.test()
    local srv = g.cluster:server('storage-1')

    -- Can't disable vshard-storage role with non-zero weight
    t.assert_error_msg_contains(
        "replicasets[bbbbbbbb-0000-0000-0000-000000000000]" ..
        " is a vshard-storage which can't be removed",
        disable_storage_role, srv
    )

    -- It's prohibited to expel storage with non-zero weight
    t.assert_error_msg_contains(
        "replicasets[bbbbbbbb-0000-0000-0000-000000000000]" ..
        " is a vshard-storage which can't be removed",
        expel_server, srv
    )

    set_weight(srv, 0)

    -- Can't disable vshard-storage role until rebalancing finishes
    t.assert_error_msg_contains(
        "replicasets[bbbbbbbb-0000-0000-0000-000000000000]" ..
        " rebalancing isn't finished yet",
        disable_storage_role, srv
    )

    -- It's prohibited to expel storage until rebalancing finishes
    t.assert_error_msg_contains(
        "replicasets[bbbbbbbb-0000-0000-0000-000000000000]" ..
        " rebalancing isn't finished yet",
        expel_server, srv
    )

    -- Speed up rebalancing
    srv.net_box:eval([[
        while vshard.storage.buckets_count() > 0 do
            vshard.storage.rebalancer_wakeup()
            require('fiber').sleep(0.1)
        end
    ]])

    disable_storage_role(srv)
    expel_server(srv)
end
