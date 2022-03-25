local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {{alias = 'A', roles = {}, servers = 1}},
        --env = {TARANTOOL_FORBID_HOTRELOAD = 'false'},
    })
    g.cluster:start()
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_errors()
    local ok, err = g.cluster.main_server.net_box:eval([[  
            package.loaded['cartridge.roles'].forbid_reload()
    ]]
    )
    t.assert_equals(ok, true)
    t.assert_equals(err, nil)

    local ok, err = g.cluster.main_server.net_box:call(
        'package.loaded.cartridge.reload_roles'
    )

    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'HotReloadError',
        err = 'Reloading roles forbidden',
    })

    local ok, err = g.cluster.main_server.net_box:eval([[  
            package.loaded['cartridge.roles'].allow_reload()
    ]]
    )
    t.assert_equals(ok, true)
    t.assert_equals(err, nil)

    local ok, err = g.cluster.main_server.net_box:call(
        'package.loaded.cartridge.reload_roles'
    )
    t.assert_equals(ok, true)
    t.assert_equals(err, nil)
end
