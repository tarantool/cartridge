local t = require('luatest')
local h = require('test.helper')
local g = t.group()

local fio = require('fio')

g.before_all(function()
    g.cluster = h.Cluster:new({
        datadir = fio.tempdir(),
        server_command = h.entrypoint('srv_basic'),
        replicasets = {{
            alias = 'A',
            uuid = h.uuid('a'),
            roles = {},
            servers = 3,
        }},
    })
    g.cluster:start()
    g.main = g.cluster.main_server

    for _, server in pairs(g.cluster.servers) do
        server.env['TARANTOOL_CLUSTER_COOKIE'] = nil
    end

    h.retrying({}, function()
        t.assert_equals(h.list_cluster_issues(g.main), {})
    end)
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

local q_set_cookie = [[
    local cluster_cookie = require('cartridge.cluster-cookie')

    local new_cookie = ...
    cluster_cookie.set_cookie(new_cookie)

    require('membership').set_encryption_key(cluster_cookie.cookie())

    if require('cartridge.failover').is_leader() then
        box.schema.user.passwd(new_cookie)
    end
]]

local q_get_cookie = [[
    return require('cartridge.cluster-cookie').cookie()
]]

local function set_cookie(server, cookie)
    server:eval(q_set_cookie, {cookie})
    server.net_box_credentials.password = cookie
    server.cluster_cookie = nil
end

local function set_cookie_clusterwide(cluster, cookie)
    for _, server in pairs(cluster.servers) do
        set_cookie(server, cookie)
    end
    for _, server in pairs(cluster.servers) do
        local ok, err = server:eval([[
            local confapplier = require('cartridge.confapplier')
            local clusterwide_config = confapplier.get_active_config()
            return confapplier.apply_config(clusterwide_config)
        ]])

        t.assert_equals({ok, err}, {true, nil})
    end
    for _, server in pairs(cluster.servers) do
        local new_cookie = server:eval(q_get_cookie)
        t.assert_equals(new_cookie, cookie)
        h.retrying({}, function()
            t.assert_equals(h.list_cluster_issues(server), {})
        end)
    end
end

function g.test_cluster_restart()
    local new_cookie = 'test_cluster_restart_cookie'
    set_cookie_clusterwide(g.cluster, new_cookie)

    g.cluster:stop()
    g.cluster:start()

    for _, server in pairs(g.cluster.servers) do
        local cookie = server:eval(q_get_cookie)
        t.assert_equals(cookie, new_cookie)
    end
    h.retrying({}, function()
        t.assert_equals(h.list_cluster_issues(g.main), {})
    end)
end

function g.test_server_restart()
    local new_cookie = 'test_server_restart_cookie'
    local target = g.cluster:server('A-2')
    set_cookie_clusterwide(g.cluster, new_cookie)

    target:stop()
    target:start()

    local cookie = target:eval(q_get_cookie)
    t.assert_equals(cookie, new_cookie)

    h.retrying({}, function()
        t.assert_equals(h.list_cluster_issues(g.main), {})
    end)
end
