local fio = require('fio')
local t = require('luatest')
local g = t.group('myrole_failover')

local log = require('log')

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
                        http_port = 8081,
                        advertise_port = 13301,
                        instance_uuid = helpers.uuid('a', 'a', 1)
                    },
                    {
                        alias = 'slave',
                        http_port = 8082,
                        advertise_port = 13302,
                        instance_uuid = helpers.uuid('a', 'a', 2)
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

function g.test_failover()
    g.cluster:server('master'):graphql({query = [[
        mutation {
            cluster { failover(enabled: true) }
        }
    ]]})
    log.warn('Failover enabled')

    g.cluster:server('slave').net_box:eval([[
        assert(package.loaded['mymodule'].is_master() == false)
    ]])

    g.cluster:server('master').net_box:eval([[
        assert(box.cfg.read_only == false)
    ]])

    g.cluster:server('slave').net_box:eval([[
        assert(box.cfg.read_only == true)
    ]])

    g.cluster:server('master'):stop()
    t.helpers.retrying({}, function()
        g.cluster:server('slave').net_box:eval([[
            assert(package.loaded['mymodule'].is_master() == true)
        ]])
    end)

    g.cluster:server('slave').net_box:eval([[
        assert(box.cfg.read_only == false)
    ]])
end
