local t = require('luatest')
local g = t.group()

local fio = require('fio')
local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {},
            servers = {{
                alias = 'master',
                instance_uuid = helpers.uuid('a', 'a', 1)
            }, {
                alias = 'replica',
                instance_uuid = helpers.uuid('a', 'a', 2)
            }},
        }},
    })
    g.cluster:start()
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_eventloop_speed()
    local log = require('log')
    local server = g.cluster:server('master')
    local replica = g.cluster:server('replica')
    local rc = server.net_box:call("os.execute", {"sleep 5"})
    local rc = server.net_box:call("os.execute", {"sleep 5"})
    local p = server.net_box:eval("return require('membership').myself().payload")
    t.assert_equals(p.slow, true)
    t.helpers.retrying({timeout=10}, function()
        local p = replica.net_box:eval("return require('membership').get_member(...).payload", {server.advertise_uri})
        t.assert_equals(p.slow, true)
    end)

    t.helpers.retrying({timeout=10}, function()
        local p = replica.net_box:eval("return require('membership').get_member(...).payload", {server.advertise_uri})
        t.assert_not_equals(p.slow, true)

        local p = server.net_box:eval("return require('membership').myself().payload")
        t.assert_not_equals(p.slow, true)
    end)
end