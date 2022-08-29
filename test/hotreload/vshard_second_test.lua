local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local function reload(srv)
    local ok, err = srv.net_box:eval([[
        return require("cartridge.roles").reload()
    ]])

    t.assert_equals({ok, err}, {true, nil})
end

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {
            {alias = 'R', roles = {'vshard-router','vshard-storage'}, servers = 1},
        },
    })
    g.cluster:start()
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

g.test_fackup = function()
    reload(g.cluster:server('R-1'))

    local ok, err = g.cluster:server('R-1'):exec(function()
        return _G.vshard.router.callrw(1, 'box.info')
    end)

    t.assert(ok, err)
end
