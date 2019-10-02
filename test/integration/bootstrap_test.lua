local fio = require('fio')
local t = require('luatest')
local g = t.group('bootstrap')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'myrole'},
                servers = {
                    {
                        alias = 'master',
                        instance_uuid = helpers.uuid('a', 'a', 1)
                    }
                },
            },
            {
                uuid = helpers.uuid('b'),
                roles = {'myrole'},
                servers = {
                    {
                        alias = 'replica',
                        instance_uuid = helpers.uuid('b', 'b', 1)
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

function g.test_restart_one()
    local master = g.cluster:server('master')
    master:stop()
    master:start()

    t.helpers.retrying({timeout = 5}, function()
        master:graphql({query = '{}'})
    end)
end

function g.test_restart_two()
    local master = g.cluster:server('master')
    local replica = g.cluster:server('replica')

    master:stop()
    replica:stop()
    master:start()
    replica:start()

    t.helpers.retrying({timeout = 5}, function()
        master:graphql({query = '{}'})
    end)

    t.helpers.retrying({timeout = 5}, function()
        replica:graphql({query = '{}'})
    end)
end
