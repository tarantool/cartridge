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

g.after_all = function()
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

function g.test_confapplier_race()
    -- Monkeypatch validate_config to trigger failover
    -- Monkeypatch apply_config to be slower
    g.master.net_box:eval('f, arg = ...; loadstring(f)(arg)', {
        string.dump(function(uri)
            local myrole = require('mymodule')

            myrole._validate_config_backup = myrole.validate_config
            myrole.validate_config = function()
                local member = require('membership').get_member(uri)
                require('membership.events').generate(
                    member.uri,
                    require('membership.options').DEAD,
                    member.incarnation+1,
                    member.payload
                )
                return true
            end

            myrole._apply_config_backup = myrole.apply_config
            myrole.apply_config = function()
                require('fiber').sleep(0.5)
            end
        end),
        g.slave.advertise_uri
    })

    -- Trigger patch_clusterwide
    g.master:graphql({query = [[
        mutation{ cluster{
            config(sections: [{filename: "x.txt", content: "XD"}]){}
        }}
    ]]})

    g.master.net_box:eval([[
        local myrole = require('mymodule')
        if myrole._validate_config_backup ~= nil then
            myrole.validate_config = myrole._validate_config_backup
        end
        if myrole._apply_config_backup ~= nil then
            myrole.apply_config = myrole._apply_config_backup
        end
    ]])
end
