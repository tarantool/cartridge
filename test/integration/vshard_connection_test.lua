local fio = require('fio')
local t = require('luatest')
local netbox = require('net.box')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        use_vshard = true,
        replicasets = {
            {
                alias = 'router',
                roles = {'vshard-router', 'vshard-storage'},
                servers = 1,
            },
        },
        env = {TARANTOOL_CONNECTIONS_LIMIT = '5'},
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_limit_connections()
    local conn_pool = {}
    local can_connect = true
    for _ = 1, 5 do
        local conn = netbox.connect('localhost:13301',
            {user = 'admin', password = g.cluster.cookie, wait_connected = true} )
        table.insert(conn_pool, conn)
        can_connect = can_connect and conn:ping()
    end
    t.assert(not can_connect)
    for _, conn in ipairs(conn_pool) do
        conn:close()
    end
    local conn = netbox.connect('localhost:13301',
            {user = 'admin', password = g.cluster.cookie, wait_connected = true} )
    t.assert(conn:ping())
end
