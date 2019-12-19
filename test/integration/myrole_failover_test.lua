local fio = require('fio')
local t = require('luatest')
local g = t.group('myrole_failover')

local log = require('log')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.setup = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {'myrole'},
            servers = {{
                alias = 'master',
                instance_uuid = helpers.uuid('a', 'a', 1)
            },
            {
                alias = 'slave',
                instance_uuid = helpers.uuid('a', 'a', 2)
            }},
        }},
    })
    g.cluster:start()

    g.cluster.main_server:graphql({query = [[
        mutation {
            cluster { failover(enabled: true) }
        }
    ]]})
    log.warn('Failover enabled')

    g.master = g.cluster:server('master')
    g.slave = g.cluster:server('slave')
end

g.teardown = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_failover()
    local function _ro_map()
        local resp = g.cluster:server('slave'):graphql({query = [[{
            servers { alias boxinfo { general {ro} } }
        }]]})

        local ret = {}
        for _, srv in pairs(resp.data.servers) do
            if srv.boxinfo == nil then
                ret[srv.alias] = box.NULL
            else
                ret[srv.alias] = srv.boxinfo.general.ro
            end
        end

        return ret
    end

    --------------------------------------------------------------------
    g.slave.net_box:eval([[
        assert(package.loaded['mymodule'].is_master() == false)
    ]])
    t.assert_equals(_ro_map(), {
        master = false,
        slave = true,
    })

    --------------------------------------------------------------------
    g.master:stop()
    log.warn('Master killed')

    t.helpers.retrying({}, function()
        g.slave.net_box:eval([[
            assert(package.loaded['mymodule'].is_master() == true)
        ]])
    end)
    t.assert_equals(_ro_map(), {
        master = box.NULL,
        slave = false,
    })

    --------------------------------------------------------------------
    log.warn('Restarting master')
    g.master:start()
    g.cluster:retrying({}, function() g.master:connect_net_box() end)

    t.helpers.retrying({}, function()
        g.slave.net_box:eval([[
            assert(package.loaded['mymodule'].is_master() == false)
        ]])
    end)
    t.assert_equals(_ro_map(), {
        master = false,
        slave = true,
    })
end
