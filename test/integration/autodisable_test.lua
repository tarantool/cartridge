local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = helpers.random_cookie(),
        replicasets = { {
                alias = 'router',
                roles = {'vshard-router'},
                servers = 1,
            }, {
                alias = 'storage',
                roles = {'vshard-storage'},
                servers = 2
            },
        },
        env = {
            TARANTOOL_DISABLE_UNRECOVERABLE_INSTANCES = 'true',
        }
    })
    g.cluster:start()
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_autodisable()
    local router = g.cluster.main_server
    local storage_1 = g.cluster:server('storage-1')

    -- this leads to InitError
    fio.rename(storage_1.workdir..'/config', storage_1.workdir..'/config-tmp')

    storage_1:restart()

    -- check disabled instances
    -- only two issue is produced
    t.helpers.retrying({}, function()
        t.assert_covers(helpers.list_cluster_issues(router), {
            {
                level = 'warning',
                instance_uuid = storage_1.instance_uuid,
                topic = 'autodisable',
                message = 'Instance localhost:13302 (storage-1) had InitError and was disabled',
            },
        })
    end)

    local resp = router:graphql({
        query = [[
            {
                servers {
                    uri
                    disabled
                }
            }
        ]]
    })

    table.sort(resp['data']['servers'], function(a, b) return a.uri < b.uri end)

    t.assert_items_equals(resp['data']['servers'], {
        {
            uri = 'localhost:13301',
            disabled = false,
        },
        {
            uri = 'localhost:13302',
            disabled = true,
        },
        {
            uri = 'localhost:13303',
            disabled = false,
        },
    })

    -- restart instance without InitError
    fio.rename(storage_1.workdir..'/config-tmp', storage_1.workdir..'/config')
    storage_1:restart()

    -- enable it back
    g.cluster.main_server:graphql({query = ([[
        mutation {
            cluster { enable_servers(uuids: ["%s"]) { uri } }
        }
    ]]):format(storage_1.instance_uuid)})

    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(router), {})
    end)
end
