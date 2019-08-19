local fio = require('fio')
local t = require('luatest')
local g = t.group('replicaset-alias')

local test_helper = require('test.helper')

local helpers = require('cluster.test_helpers')

local cluster

local replicaset_uuid = helpers.uuid('a')

g.before_all = function()
    cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = test_helper.server_command,
        replicasets = {
            {
                alias = 'router',
                uuid = replicaset_uuid,
                roles = {'vshard-router', 'vshard-storage'},
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

    local alias = 'check_my_alias'

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
            uuid = replicaset_uuid,
            alias = alias
        }
    })

    local res = server:graphql({
        query = [[
query { replicasets { uuid, alias } }
        ]]
    }).data.replicasets

    for _, replicaset in pairs(res) do
        if replicaset.uuid == replicaset_uuid then
            t.assert_equals(replicaset.alias, alias)
        end
    end
end
