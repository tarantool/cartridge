local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local replicaset_uuid = helpers.uuid('b')
local storage_1_uuid = helpers.uuid('b', 'b', 1)
local storage_2_uuid = helpers.uuid('b', 'b', 2)
local storage_3_uuid = helpers.uuid('b', 'b', 3)

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        failover = 'eventual',
        replicasets = {
            {
                alias = 'router',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router', 'myrole'},
                servers = {
                    {instance_uuid = helpers.uuid('a', 'a', 1)},
                },
            },
            {
                alias = 'storage',
                uuid = replicaset_uuid,
                roles = {'vshard-router', 'vshard-storage', 'myrole'},
                servers = {
                    {alias = 'storage1', instance_uuid = storage_1_uuid},
                    {alias = 'storage2', instance_uuid = storage_2_uuid},
                    {alias = 'storage3', instance_uuid = storage_3_uuid},
                },
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
    local command = [[
        return package.loaded['mymodule'].get_master_switches()
    ]]
    t.assert_equals({
        g.cluster:server('storage1'):eval(command),
        g.cluster:server('storage2'):eval(command),
        g.cluster:server('storage3'):eval(command),
    },
    {{true}, {false}, {false}})
end