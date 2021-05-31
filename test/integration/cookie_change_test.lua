local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        replicasets = {
            {
                alias = 'A',
                uuid = helpers.uuid('a'),
                roles = {},
                servers = 3,
            },
        },
    })
    g.cluster:start()
    for _, server in pairs(g.cluster.servers) do
        server.env['TARANTOOL_CLUSTER_COOKIE'] = nil
    end
end


g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

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
    server.net_box:eval(q_set_cookie, {cookie})
    server.net_box_credentials.password = cookie
end

local function set_cookie_clusterwide(cluster, cookie)
    for _, server in pairs(cluster.servers) do
        set_cookie(server, cookie)
    end
    for _, server in pairs(cluster.servers) do
        local new_cookie = server.net_box:eval(q_get_cookie)
        t.assert_equals(new_cookie, cookie)
        t.helpers.retrying({}, function()
            t.assert_equals(#helpers.list_cluster_issues(server), 0)
        end)
    end
end

function g.test_cluster_restart()
    local new_cookie = 'test_cluster_restart_cookie'
    set_cookie_clusterwide(g.cluster, new_cookie)

    g.cluster:stop()
    g.cluster:start()

    for _, server in pairs(g.cluster.servers) do
        local cookie = server.net_box:eval(q_get_cookie)
        t.assert_equals(cookie, new_cookie)
    end
end

function g.test_server_restart()
    local new_cookie = 'test_server_restart_cookie'
    local target = g.cluster:server('A-2')
    set_cookie_clusterwide(g.cluster, new_cookie)

    target:stop()
    target:start()

    local cookie = target.net_box:eval(q_get_cookie)
    t.assert_equals(cookie, new_cookie)

    t.helpers.retrying({}, function()
        local issues = target.net_box:call('_G.__cartridge_issues_list_on_instance')
        t.assert_equals(#issues, 0)
    end)

end
