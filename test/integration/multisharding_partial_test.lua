local fio = require('fio')
local t = require('luatest')
local g = t.group()
local h = require('test.helper')


g.before_each(function()
    g.cluster = h.Cluster:new({
        datadir = fio.tempdir(),
        server_command = h.entrypoint('srv_multisharding'),
        cookie = h.random_cookie(),
        replicasets = {
            {
                alias = 'router',
                roles = {},
                servers = 1
            },
            {
                alias = 'storage-hot',
                roles = {},
                servers = 1
            },
            {
                alias = 'storage-cold',
                roles = {},
                servers = 1
            },
        },
    })

    g.cluster:start()
    g.storage_hot = g.cluster:server('storage-hot-1')
    g.storage_cold = g.cluster:server('storage-cold-1')
end)

g.after_each(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

local function build_issue_msg(main, group)
    return {
        level = 'warning',
        topic = 'vshard',
        message = ([[Group "%s" wasn't bootstrapped: Sharding config is empty. ]] ..
            [[There may be no instances in this group.]]):format(group),
        instance_uuid = main.instance_uuid,
        replicaset_uuid = main.replicaset_uuid,
    }
end

g.test_bootstrap_vshard_by_group = function()
    local main = g.cluster.main_server

    -- try to bootsrap vshard without vshard-router
    t.assert_error_msg_contains('No remotes with role "vshard-router" available',
    g.cluster.bootstrap_vshard, g.cluster)

    -- setup vshard-router
    main:setup_replicaset({
        roles = {'vshard-router'},
        uuid = main.replicaset_uuid,
    })

    -- bootstrap without storages
    g.cluster:bootstrap_vshard()

    t.assert_equals(h.list_cluster_issues(main), {
        build_issue_msg(main, 'cold'),
        build_issue_msg(main, 'hot'),
    })

    -- setup storage-hot
    main:setup_replicaset({
        roles = {'vshard-storage'},
        vshard_group = 'hot',
        uuid = g.storage_hot.replicaset_uuid,
        weight = 1,
    })

    -- bootstrap only hot group
    g.cluster:bootstrap_vshard()

    t.assert_equals(h.list_cluster_issues(main), {
        build_issue_msg(main, 'cold')
    })

    -- setup server with cold group
    g.storage_cold:setup_replicaset({
        roles = {'vshard-storage'},
        vshard_group = 'cold',
        uuid = g.storage_cold.replicaset_uuid,
        weight = 1,
    })

    -- bootstrap cold group
    g.cluster:bootstrap_vshard()
    t.assert_equals(h.list_cluster_issues(main), {})

    -- try to bootstrap again
    t.assert_error_msg_contains('already bootstrapped', g.cluster.bootstrap_vshard, g.cluster)
end
