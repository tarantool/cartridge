local fio = require('fio')
local fun = require('fun')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local replicaset_uuid = helpers.uuid('b')
local storage_1_uuid = helpers.uuid('b', 'b', 1)
local storage_2_uuid = helpers.uuid('b', 'b', 2)
local storage_3_uuid = helpers.uuid('b', 'b', 3)
local storage_4_uuid = helpers.uuid('b', 'b', 4)

g.before_all = function()
    g.cluster1 = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = 'cookieA',
        base_http_port = 8080,
        base_advertise_port = 3300,
        replicasets = {
            {
                alias = 'router-A',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = {
                    {instance_uuid = helpers.uuid('a', 'a', 1)},
                },
            },
            {
                alias = 'storage-A',
                uuid = replicaset_uuid,
                roles = {'vshard-storage'},
                servers = {
                    {instance_uuid = storage_1_uuid},
                    {instance_uuid = storage_2_uuid},
                },
            },
        },
    })
    g.cluster1:start()
    g.cluster1:wait_until_healthy()

    g.cluster1:server('storage-A-1'):exec(function()
        box.schema.create_space('test')
        box.space.test:create_index('pk')
        box.space.test:insert{1}
    end)

    g.cluster2 = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = 'cookieB',
        base_http_port = 8090,
        base_advertise_port = 13300,
        replicasets = {
            {
                alias = 'router-B',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router', 'failover-coordinator'},
                servers = {
                    {
                        instance_uuid = helpers.uuid('a', 'a', 2),
                        env = { TARANTOOL_BOOTSTRAP_FROM = 'admin:cookieA@localhost:3301' }
                    },
                },
            },
            {
                alias = 'storage-B',
                uuid = replicaset_uuid,
                roles = {'vshard-storage'},
                servers = {
                    {
                        instance_uuid = storage_3_uuid,
                        env = { TARANTOOL_BOOTSTRAP_FROM = 'admin:cookieA@localhost:3302' }
                    },
                    {
                        instance_uuid = storage_4_uuid,
                        env = { TARANTOOL_BOOTSTRAP_FROM = 'admin:cookieA@localhost:3302' }
                    },
                },
            },
        },
    })

    g.cluster2:start()
    g.cluster2:wait_until_healthy()
end

g.after_all = function()
    g.cluster1:stop()
    fio.rmtree(g.cluster1.datadir)
    g.cluster2:stop()
    fio.rmtree(g.cluster2.datadir)
end

g.test_bootstrap_from = function()
    helpers.retrying({}, function()
        g.cluster2:server('storage-B-1'):exec(function()
            assert(box.space.test)
            assert(box.space.test:get(1))
        end)
    end)

    g.cluster2:server('storage-B-1'):exec(function()
        box.space.test:insert{2}
        assert(#box.space.test:select() == 2)
    end)

    g.cluster1:server('storage-A-1'):exec(function()
        assert(#box.space.test:select() == 1)
    end)


    local repl1 = g.cluster1:server('storage-A-1'):exec(function()
        return box.cfg.replication
    end)

    t.assert_items_equals(repl1, {"admin:cookieA@localhost:3302", "admin:cookieA@localhost:3303"})

    local repl2 = g.cluster2:server('storage-B-1'):exec(function()
        return box.cfg.replication
    end)

    t.assert_items_equals(repl2, {"admin:cookieB@localhost:13302", "admin:cookieB@localhost:13303"})


    local repl1 = fun.iter(g.cluster1:server('storage-A-1'):exec(function()
        return box.info.replication
    end)):map(function(x) return x.uuid end):totable()

   t.assert_items_equals(repl1, {storage_1_uuid, storage_2_uuid, storage_3_uuid, storage_4_uuid})

    local repl2 = fun.iter(g.cluster1:server('storage-A-2'):exec(function()
        return box.info.replication
    end)):map(function(x) return x.uuid end):totable()

    t.assert_items_equals(repl2, {storage_1_uuid, storage_2_uuid, storage_3_uuid, storage_4_uuid})

    local repl3 = fun.iter(g.cluster2:server('storage-B-1'):exec(function()
        return box.info.replication
    end)):map(function(x) return x.uuid end):totable()

    t.assert_items_equals(repl3, {storage_1_uuid, storage_2_uuid, storage_3_uuid, storage_4_uuid})

    local repl4 = fun.iter(g.cluster2:server('storage-B-2'):exec(function()
        return box.info.replication
    end)):map(function(x) return x.uuid end):totable()

    t.assert_items_equals(repl4, {storage_1_uuid, storage_2_uuid, storage_3_uuid, storage_4_uuid})
end

g.test_bootstrap_from_restart = function()
    g.cluster2:stop()

    g.cluster2:start()

    g.cluster2:wait_until_healthy()

    local repl = fun.iter(g.cluster2:server('storage-B-1'):exec(function()
        return box.info.replication
    end)):map(function(x) return x.uuid end):totable()

    t.assert_items_equals(repl, {storage_1_uuid, storage_2_uuid, storage_3_uuid, storage_4_uuid})
end
