local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.setup = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {
                    {
                        alias = 'server-1',
                        instance_uuid = helpers.uuid('a', 'a', 1),
                        advertise_port = 13301,
                    },
                    {
                        alias = 'server-2',
                        instance_uuid = helpers.uuid('a', 'a', 2),
                        advertise_port = 13303,
                    }
                },
            },
        },
    })
    g.cluster:start()
end

g.teardown = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function eval(alias, ...)
    return g.cluster:server(alias).net_box:eval(...)
end

function g.test_membership_leave()
    t.skip_if(box.ctl.on_shutdown == nil,
            'box.ctl.on_shutdown is not supported on Tarantool ' .. _TARANTOOL)

    local server2 = g.cluster:server('server-2')

    local status = eval('server-1', [[
        local uri = ...
        local membership = require('membership')
        local member = membership.members()[uri]
        return member.status
    ]], {server2.advertise_uri})
    t.assert_equals(status, 'alive')

    server2:stop()

    local status = eval('server-1', [[
        local uri = ...
        local membership = require('membership')
        local member = membership.members()[uri]
        return member.status
    ]], {server2.advertise_uri})

    helpers.retrying({}, function()
        t.assert_equals(status, 'left')
    end)
end
