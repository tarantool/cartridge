local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local fio = require('fio')

g.before_each(function()
    g.server = t.Server:new({
        command = helpers.entrypoint('srv_empty'),
        workdir = fio.tempdir(),
        net_box_port = 13301,
        net_box_credentials = {user = 'admin', password = ''},
    })

    g.server:start()
    helpers.retrying({}, t.Server.connect_net_box, g.server)
end)

g.after_each(function()
    g.server:stop()
    fio.rmtree(g.server.workdir)
end)

local M = {}
local function test_remotely(fn_name, fn)
    M[fn_name] = fn
    g[fn_name] = function()
        g.server:eval([[
            local test = require('test.unit.cartridge_failover_test')
            test[...]()
        ]], {fn_name})
    end
end

------------------------------------------------------------------------

test_remotely('test_empty_state', function()
    -- cartridge isn't initialized
    local failover = require('cartridge.failover')

    t.assert_equals(failover.is_rw(), false)
    t.assert_equals(failover.is_leader(), false)
    t.assert_equals(failover.get_active_leaders(), {})
end)

test_remotely('test_unconfigured_state', function()
    local cartridge = require('cartridge')
    local failover = require('cartridge.failover')
    local confapplier = require('cartridge.confapplier')
    local remote_control = require('cartridge.remote-control')

    remote_control.stop()
    cartridge.cfg({roles = {}})
    local state, err = confapplier.get_state()

    t.assert_equals(state, 'Unconfigured')
    t.assert_equals(err, nil)
    t.assert_equals(failover.is_rw(), false)
    t.assert_equals(failover.is_leader(), false)
    t.assert_equals(failover.get_active_leaders(), {})
end)

test_remotely('test_switch_to_manual_fails_when_local_election_mode_is_manual', function()
    local failover = require('cartridge.lua-api.failover')
    local vars = require('cartridge.vars').new('cartridge.failover')

    vars.clusterwide_config = {
        get_readonly = function(_, section_name)
            t.assert_equals(section_name, 'topology')
            return {
                failover = {
                    mode = 'stateful',
                    state_provider = 'tarantool',
                },
                replicasets = {
                    rs1 = {all_rw = false},
                },
                servers = {},
            }
        end,
    }
    vars.enable_synchro_mode = true
    vars.failover_suppressed = false
    vars.instance_uuid = 'instance-1'
    vars.replicaset_uuid = 'rs1'
    vars.cache = {is_leader = true}

    rawset(_G, 'old_box', box)
    _G.box = {
        info = {
            ro = false,
        },
        cfg = {
            election_mode = 'manual',
            election_fencing_mode = 'off',
        },
        ctl = {
            promote = function() end,
        },
        error = _G.old_box.error,
    }

    local ok, err = failover.switch_to_manual_election_mode()
    t.assert_equals(ok, nil)
    t.assert_str_contains(
        tostring(err),
        'Local election_mode must be "off", got "manual"'
    )

    rawset(_G, 'box', _G.old_box)
    rawset(_G, 'old_box', nil)
end)

return M
