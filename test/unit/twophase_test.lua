local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local fio = require('fio')

g.server = t.Server:new({
    command = helpers.entrypoint('srv_empty'),
    workdir = fio.tempdir(),
    net_box_port = 13300,
    net_box_credentials = {user = 'admin', password = ''},
})

g.before_each(function()
    g.server:start()
    helpers.retrying({}, function() g.server:connect_net_box() end)
end)

g.after_each(function()
    g.server:stop()
    fio.rmtree(g.server.workdir)
end)

local function mock()
    local fiber = require('fiber')
    local fn_true = function() return true end

    package.loaded['membership'] = {
        init = fn_true,
        probe_uri = fn_true,
        broadcast = fn_true,
        set_payload = fn_true,
        set_encryption_key = fn_true,
        subscribe = function() return fiber.cond() end,
        myself = function()
            return {
                uri = '127.0.0.1:0',
                status = 1,
                incarnation = 1,
                payload = {},
            }
        end,
    }

    package.loaded['cartridge.remote-control'] = {
        bind = fn_true,
        accept = fn_true,
    }
end

-- timeouts -------------------------------------------------------------------
-------------------------------------------------------------------------------

g.test_timeouts = function()
    helpers.run_remotely(g.server, mock)
    helpers.run_remotely(g.server, function()

        local t = require('luatest')
                local ok, _ = require('cartridge').cfg({
                    advertise_uri = '127.0.0.1:0',
                    roles = {},
                })
                t.assert_equals(ok, true)

        local twophase = require('cartridge.twophase')

        twophase.set_netbox_call_timeout(222)
        t.assert_equals(twophase.get_netbox_call_timeout(), 222)

        twophase.set_upload_config_timeout(123)
        t.assert_equals(twophase.get_upload_config_timeout(), 123)

        twophase.set_validate_config_timeout(654)
        t.assert_equals(twophase.get_validate_config_timeout(), 654)

        twophase.set_apply_config_timeout(111)
        t.assert_equals(twophase.get_apply_config_timeout(), 111)
    end)
end