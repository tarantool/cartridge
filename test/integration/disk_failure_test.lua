local fio = require('fio')
local fun = require('fun')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        use_vshard = true,
        replicasets = { {
                alias = 'router',
                roles = {'vshard-router'},
                servers = 1,
            }, {
                alias = 'sharded-storage',
                roles = {'vshard-storage'},
                servers = 2
            }, {
                alias = 'simple-storage',
                roles = {},
                servers = 2
            }
        }
    })
    g.cluster:start()
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_disk_failure_disable()
    local router = g.cluster.main_server
    local sharded_storage_1 = g.cluster:server('sharded-storage-1')
    local sharded_storage_2 = g.cluster:server('sharded-storage-2')
    local simple_storage_1 = g.cluster:server('simple-storage-1')

    -- before disk failure everything is ok
    t.assert(sharded_storage_1:exec(function()
        return _G.vshard.storage.internal.is_enabled
    end))

    -- first DC disk is down
    sharded_storage_1:exec(function()
        rawset(_G, 'old_lstat', package.loaded.fio.lstat)
        package.loaded.fio.lstat = function () return nil end
    end)
    simple_storage_1:exec(function()
        rawset(_G, 'old_lstat', package.loaded.fio.lstat)
        package.loaded.fio.lstat = function () return nil end
    end)

    -- check disabled instances
    -- only two issue is produced
    t.helpers.retrying({}, function()
        local issues = fun.map(function(x) x.message = nil; return x end,
            helpers.list_cluster_issues(router)):totable()

        table.sort(issues, function(a, b) return a.instance_uuid < b.instance_uuid end)
        local expected_issues = {
            {
                level = 'critical',
                replicaset_uuid = sharded_storage_1.replicaset_uuid,
                instance_uuid = sharded_storage_1.instance_uuid,
                topic = 'disk_failure',
            }, {
                level = 'critical',
                replicaset_uuid = simple_storage_1.replicaset_uuid,
                instance_uuid = simple_storage_1.instance_uuid,
                topic = 'disk_failure',
            }
        }
        table.sort(expected_issues, function(a, b) return a.instance_uuid < b.instance_uuid end)
        t.assert_covers(issues, expected_issues)
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
        {
            uri = 'localhost:13304',
            disabled = true,
        },
        {
            uri = 'localhost:13305',
            disabled = false,
        },
    })
    -- first storage is disabled
    t.assert_not(sharded_storage_1:exec(function()
        return _G.vshard.storage.internal.is_enabled
    end))
    -- second storage is ok
    t.assert(sharded_storage_2:exec(function()
        return _G.vshard.storage.internal.is_enabled
    end))

    -- first DC disk is alright
    sharded_storage_1:exec(function()
        package.loaded.fio.lstat = _G.old_lstat
    end)
    simple_storage_1:exec(function()
        package.loaded.fio.lstat = _G.old_lstat
    end)

    -- enable it back
    g.cluster.main_server:graphql({query = ([[
        mutation {
            cluster { enable_servers(uuids: ["%s", "%s"]) { uri } }
        }
    ]]):format(sharded_storage_1.instance_uuid, simple_storage_1.instance_uuid)})

    -- restart router to remove issues
    router:restart()
    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(router), {})
    end)

    -- vshard is enabled again
    t.assert(sharded_storage_1:exec(function()
        return _G.vshard.storage.internal.is_enabled
    end))
end
