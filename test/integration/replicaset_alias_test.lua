local fio = require('fio')
local t = require('luatest')
local g = t.group('replicaset_alias')

local test_helper = require('test.helper')

local helpers = require('cluster.test_helpers')

local cluster

g.before_all = function()
    cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = test_helper.server_command,
        replicasets = {
            {
                alias = 'initial-alias',
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {
                    {instance_uuid = helpers.uuid('a', 'a', 1)},
                },
            },
        },
    })
    cluster:start()
end
g.after_all = function()
    cluster:stop()
    fio.rmtree(cluster.datadir)
end

g.test_rename_replicaset = function()
    local server = cluster.main_server

    local function query()
        return server:graphql({
            query = ([[{
                replicasets(uuid: %q) { uuid, alias } }
            ]]):format(server.replicaset_uuid)
        }).data.replicasets[1]
    end

    t.assert_equals(query(), {
        uuid = server.replicaset_uuid,
        alias = 'initial-alias',
    })

    local alias = 'another-alias'
    server:graphql({
        query = [[
            mutation(
                $uuid: String!
                $alias: String!
            ){
                edit_replicaset(
                    uuid: $uuid
                    alias: $alias
                )
            }
        ]],
        variables = {
            uuid = server.replicaset_uuid,
            alias = alias
        }
    })

    t.assert_equals(query(), {
        uuid = server.replicaset_uuid,
        alias = 'another-alias',
    })
end
