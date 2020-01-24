local t = require('luatest')
local g = t.group()

local fio = require('fio')
local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = test_helper.server_command,
        replicasets = {
            {
                alias = 'initial-alias',
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {
                    {
                        alias = 'master',
                        instance_uuid = helpers.uuid('a', 'a', 1)
                    }, {
                        alias = 'replica1',
                        instance_uuid = helpers.uuid('a', 'a', 2)
                    }, {
                        alias = 'replica2',
                        instance_uuid = helpers.uuid('a', 'a', 3)
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

function g.test_broken_replica()
    local master = g.cluster.main_server
    local replica1 = g.cluster:server('replica1')

    master.net_box:eval([[
        __replication = box.cfg.replication
        box.cfg{replication = box.NULL}
    ]])

    replica1.net_box:eval([[
        box.cfg{read_only = false}
        box.schema.space.create('test')
    ]])

    master.net_box:eval([[
        box.schema.space.create('test')
        pcall(box.cfg, {replication = __replication})
        __replication = nil
    ]])


    t.helpers.retrying({}, function()
        local warnings = master:graphql({query = [[{
            cluster {
                warnings{
                    replicaset_uuid
                    message
                    instance_uuid
                }
            }
        }]]}).data.cluster.warnings

        t.assert_equals(
            test_helper.table_find_by_attr(
                warnings, 'instance_uuid', helpers.uuid('a', 'a', 2)
            ), {
                instance_uuid = helpers.uuid('a', 'a', 2),
                replicaset_uuid = helpers.uuid('a'),
                message = [[Replication from localhost:13301 ]] ..
                    [[to localhost:13302: Duplicate key exists ]] ..
                    [[in unique index 'primary' in space '_space' ("stopped")]]
            }
        )
        t.assert_equals(
            test_helper.table_find_by_attr(
                warnings, 'instance_uuid', helpers.uuid('a', 'a', 3)
            ), {
                instance_uuid = helpers.uuid('a', 'a', 3),
                replicaset_uuid = helpers.uuid('a'),
                message = [[Replication from localhost:13301 to ]] ..
                    [[localhost:13303: Duplicate key exists ]] ..
                    [[in unique index 'primary' in space '_space' ("stopped")]]
            }
        )
        if #warnings ~= 4 then
            t.assert_not(warnings)
        end
    end)
end
