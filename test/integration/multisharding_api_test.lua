local fio = require('fio')
local t = require('luatest')
local g = t.group('multisharding_api')

local test_helper = require('test.helper')

local helpers = require('cartridge.test-helpers')

local cluster

g.before_all = function()
    local server_command = fio.pathjoin(test_helper.root,
        'test', 'integration', 'srv_multisharding.lua'
    )

    cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = server_command,
        replicasets = {
            {
                alias = 'hot-master',
                uuid = helpers.uuid('a'),
                roles = {'vshard-storage', 'vshard-router'},
                vshard_group = 'hot',
                servers = {{
                    http_port = 8081,
                    advertise_port = 13301,
                    instance_uuid = helpers.uuid('a', 'a', 1)
                }},
            }
        },
    })

    cluster:start()
end

g.after_all = function()
    cluster:stop()

    fio.rmtree(cluster.datadir)
    cluster = nil
end

g.test_query = function()
    local ret = cluster.main_server:graphql({
        query = [[{
            replicasets(uuid: "aaaaaaaa-0000-0000-0000-000000000000") {
                uuid
                vshard_group
            }
        }]]
    })

    t.assert_equals(ret['data']['replicasets'][1], {
        uuid = helpers.uuid('a'),
        vshard_group = 'hot',
    })
end

g.test_mutations = function()
    t.assert_error_msg_contains(
        "replicasets[aaaaaaaa-0000-0000-0000-000000000000].vshard_group" ..
        " can't be modified",
        function()
            return cluster.main_server:graphql({
                query = [[mutation {
                    edit_replicaset(
                        uuid: "aaaaaaaa-0000-0000-0000-000000000000"
                        vshard_group: "cold"
                    )
                }]]
            })
        end
    )

    -- Do nothing and check it doesn't raise an error
    cluster.main_server:graphql({
        query = [[mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-0000-0000-000000000000"
            )
        }]]
    })
end
