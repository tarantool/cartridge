local t = require('luatest')
local h = require('test.helper')
local g = t.group()

local fio = require('fio')

g.before_all(function()
    g.cluster = h.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = h.entrypoint('srv_basic'),
        cookie = h.random_cookie(),
        replicasets = {{
            alias = 'A',
            roles = {},
            servers = 2,
        }},
    })
    g.cluster:start()
    g.A1 = g.cluster:server('A-1')
    g.A2 = g.cluster:server('A-2')
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_suggestion()
    -- Trigger replication issue
    g.A1:call('box.cfg', {{replication = box.NULL}})

    local replication_issue = {
        level = 'critical',
        topic = 'replication',
        instance_uuid = g.A1.instance_uuid,
        replicaset_uuid = g.A1.replicaset_uuid,
        message = "Replication from localhost:13302 (A-2)" ..
            " to localhost:13301 (A-1) isn't running",
    }
    t.helpers.retrying({}, function()
        t.assert_equals(h.list_cluster_issues(g.A1), {replication_issue})
        t.assert_items_equals(
            h.get_suggestions(g.A1).restart_replication,
            {{uuid = g.A1.instance_uuid}}
        )
    end)

    g.A2.process:kill('STOP')

t.assert_equals(h.list_cluster_issues(g.A1), {replication_issue})
t.assert_equals(h.get_suggestions(g.A1).restart_replication, nil)

    g.A2.process:kill('CONT')

    t.helpers.retrying({}, function()
        t.assert_equals(h.list_cluster_issues(g.A1), {replication_issue})
        t.assert_items_equals(
            h.get_suggestions(g.A1).restart_replication,
            {{uuid = g.A1.instance_uuid}}
        )
    end)

    g.A1:graphql({
        query = [[
            mutation ($uuids : [String!]) {
                cluster {
                    restart_replication(uuids: $uuids)
                }
            }
        ]],
        variables = {uuids = {g.A1.instance_uuid}}
    })

    t.helpers.retrying({}, function()
        t.assert_equals(h.list_cluster_issues(g.A1), {})
        t.assert_equals(h.get_suggestions(g.A1).restart_replication, nil)
    end)
end

g.after_test('test_suggestion', function()
    g.A2.process:kill('CONT')
end)

g.before_test('test_errors', function()
    g.unconfigured = h.Server:new({
        alias = 'unconfigured',
        workdir = fio.pathjoin(g.cluster.datadir, 'unconfigured'),
        command = h.entrypoint('srv_basic'),
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13309,
        http_port = 8089,
    })
end)

function g.test_errors()
    local _, err = g.A1:call(
        'package.loaded.cartridge.admin_restart_replication',
        {{'1-0-1-0'}}
    )
    t.assert_covers(err, {err = 'Server 1-0-1-0 not in clusterwide config'})

    g.A1:eval([[
        package.loaded.cartridge.admin_disable_servers({...})
    ]], {g.A2.instance_uuid})
    local _, err = g.A1:call(
        'package.loaded.cartridge.admin_restart_replication',
        {{g.A2.instance_uuid}}
    )
    t.assert_covers(err, {
        err = 'Server ' .. g.A2.instance_uuid .. ' is disabled,' ..
            ' not suitable for restarting replication',
    })

    g.A1:eval([[
        package.loaded.cartridge.admin_enable_servers({...})
    ]], {g.A2.instance_uuid})

    g.unconfigured:start()
    local _, err = g.unconfigured:call(
        'package.loaded.cartridge.admin_restart_replication',
        {{g.unconfigured.instance_uuid}}
    )
    t.assert_covers(err, {err = 'Current instance isn\'t bootstrapped yet'})
end

g.after_test('test_errors', function()
    g.unconfigured:stop()
end)
