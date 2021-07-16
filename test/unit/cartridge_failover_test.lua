local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local fio = require('fio')

function g.setup()
    g.server = t.Server:new({
        command = helpers.entrypoint('srv_empty'),
        workdir = fio.tempdir(),
        net_box_port = 13301,
        net_box_credentials = {user = 'admin', password = ''},
    })

    g.server:start()
    helpers.retrying({}, t.Server.connect_net_box, g.server)
end

function g.teardown()
    g.server:stop()
    fio.rmtree(g.server.workdir)
end

local M = {}
local function test_remotely(fn_name, fn)
    M[fn_name] = fn
    g[fn_name] = function()
        g.server.net_box:eval([[
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

return M
