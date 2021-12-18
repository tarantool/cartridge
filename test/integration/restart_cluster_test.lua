local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        failover = 'eventual',
        replicasets = {
            {
                alias = 'storage',
                roles = {'myrole'},
                servers = 3,
            },
        },
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

g.test_cluster_restart_with_eventual_failover = function()
    g.cluster:stop()
    g.cluster:start()

    t.xfail('Must fail because all storages initialized as masters')
    local command = function()
        return package.loaded['mymodule'].get_master_switches()
    end

    t.assert_equals({
        g.cluster:server('storage-1'):exec(command),
        g.cluster:server('storage-2'):exec(command),
        g.cluster:server('storage-3'):exec(command),
    },
    {{true}, {false}, {false}})
end
