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

-- timeouts -------------------------------------------------------------------
-------------------------------------------------------------------------------

g.test_timeouts = function()
    g.server:exec(function()
        local t = require('luatest')
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
