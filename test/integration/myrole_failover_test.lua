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

function g.test_confapplier_race()
    -- Sequence of actions:
    --
    -- m|s: prepare_2pc (ok)
    -- m  : Trigger failover
    -- m  : ConfiguringRoles, sleep 0.5
    --   s: apply_2pc (ok)
    -- m  : Don't apply_2pc yet (state is inappropriate)
    -- m  : RolesConfigured
    -- m  : apply_config

    g.master.net_box:eval('f, arg = ...; loadstring(f)(arg)', {
        string.dump(function(uri)
            local myrole = require('mymodule')

            -- Monkeypatch validate_config to trigger failover
            myrole._validate_config_backup = myrole.validate_config
            myrole.validate_config = function()
                local member = require('membership').get_member(uri)
                require('membership.events').generate(
                    member.uri,
                    require('membership.options').DEAD,
                    100, -- incarnation, spread false rumor only once
                    member.payload
                )
                return true
            end

            -- Monkeypatch apply_config to be slower
            local slowdown_once = true
            myrole._apply_config_backup = myrole.apply_config
            myrole.apply_config = function()
                if slowdown_once then
                    require('fiber').sleep(0.5)
                    slowdown_once = false
                end
            end
        end),
        g.slave.advertise_uri
    })

    -- Trigger patch_clusterwide
    -- It should succeed
    g.master:graphql({query = [[
        mutation{ cluster{
            config(sections: [{filename: "x.txt", content: "XD"}]){}
        }}
    ]]})
end

function g.test_leader_death()
    -- Sequence of actions:
    --
    -- m|s: prepare_2pc (ok)
    -- m  : ConfiguringRoles, sleep 0.2
    --   s: ConfiguringRoles, sleep 0.5
    -- m  : dies
    --   s: Don't trigger failover yet (state is inappropriate)
    --   s: RolesConfigured
    --   s: Trigger failover

    -- Monkeypatch apply_config on master to faint death
    g.master.net_box:eval('loadstring(...)()', {
        string.dump(function()
            local myrole = require('mymodule')
            myrole.apply_config = function()
                require('fiber').sleep(0.2)

                 -- faint death
                local membership = require('membership')
                membership.leave()
                membership.set_payload = function() end

                error("Apply fails sometimes, who'd have thought?", 0)
            end
        end)
    })

    -- Monkeypatch apply_config on slave to be slow
    g.slave.net_box:eval('loadstring(...)()', {
        string.dump(function()
            local myrole = require('mymodule')

            myrole._apply_config_backup = myrole.apply_config
            myrole.apply_config = function(conf, opts)
                require('fiber').sleep(0.5)
                require('log').warn('I am %s',
                    opts.is_master and 'leader' or 'looser'
                )
                return myrole._apply_config_backup(conf, opts)
            end
        end),
        g.slave.advertise_uri
    })

    -- Trigger patch_clusterwide
    t.assert_error_msg_equals(
        "Apply fails sometimes, who'd have thought?",
        function()
            return g.master:graphql({query = [[
                mutation{ cluster{
                    config(sections: [{filename: "y.txt", content: "XD"}]){}
                }}
            ]]})
        end
    )

    t.helpers.retrying({},
        function()
            local is_master = g.slave.net_box:eval(
                "return require('mymodule').is_master()"
            )
            t.assert_equals(is_master, true)
        end
    )
end
