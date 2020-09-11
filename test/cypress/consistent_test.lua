local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.setup = function()
    g.datadir = fio.tempdir()

    fio.mktree(fio.pathjoin(g.datadir, 'stateboard'))
    g.kvpassword = 'password'
    g.stateboard = require('luatest.server'):new({
        command = helpers.entrypoint('srv_stateboard'),
        workdir = fio.pathjoin(g.datadir, 'stateboard'),
        net_box_port = 14401,
        net_box_credentials = {
            user = 'client',
            password = g.kvpassword,
        },
        env = {
            TARANTOOL_LOCK_DELAY = 1,
            TARANTOOL_PASSWORD = g.kvpassword,
        },
    })
    g.stateboard:start()
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
    end)
end

local servers = {}

g.before_all = function()
    g.tempdir = fio.tempdir()
    local function add_server(i)
        local http_port = 8080 + i
        local advertise_port = 13310 + i
        local alias = 'server' .. tostring(i)

        servers[i] = helpers.Server:new({
            alias = alias,
            command = helpers.entrypoint('srv_basic'),
            workdir = fio.pathjoin(g.tempdir, alias),
            cluster_cookie = 'test-cluster-cookie',
            http_port = http_port,
            advertise_port = advertise_port,
            instance_uuid = helpers.uuid('a', 'a', i),
            replicaset_uuid = helpers.uuid('a'),
            env = {
                TARANTOOL_INSTANCE_NAME = alias,
            },
        })
    end

    add_server(1)
    add_server(2)
    add_server(3)
    add_server(4)
    add_server(5)

    for _, server in pairs(servers) do
        server:start()
    end
end

g.after_all = function()
    for _, server in pairs(servers) do
        server:stop()
    end

    fio.rmtree(g.tempdir)
end

function g.test_consistent_promotion()
    local code = os.execute(
        "cd webui && npx cypress run --spec" ..
        ' cypress/integration/consistent-promotion.spec.js'
    )
    t.assert_equals(code, 0)
end
