local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local storage_A_uuid = helpers.uuid('a')
local storage_A_1_uuid = helpers.uuid('a', 'a', 1)
local storage_A_2_uuid = helpers.uuid('a', 'a', 2)

local storage_B_uuid = helpers.uuid('b')
local storage_B_1_uuid = helpers.uuid('b', 'b', 1)
local storage_B_2_uuid = helpers.uuid('b', 'b', 2)

local router_uuid = helpers.uuid('c')
local router_1_uuid = helpers.uuid('c', 'c', 1)

g.before_all(function()
    g.datadir = fio.tempdir()

    fio.mktree(fio.pathjoin(g.datadir, 'stateboard'))
    g.kvpassword = require('digest').urandom(6):hex()
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

    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        env = {
            TARANTOOL_SWIM_SUSPECT_TIMEOUT_SECONDS = 0,
        },
        replicasets = {
            {
                alias = 'router',
                uuid = router_uuid,
                roles = {'vshard-router', 'failover-coordinator'},
                servers = {
                    {alias = 'router', instance_uuid = router_1_uuid},
                },
            },
            {
                alias = 'storage-A',
                uuid = storage_A_uuid,
                roles = {'vshard-router', 'vshard-storage'},
                servers = {
                    {alias = 'storage-A-1', instance_uuid = storage_A_1_uuid},
                    {alias = 'storage-A-2', instance_uuid = storage_A_2_uuid},
                },
            },
            {
                alias = 'storage-B',
                uuid = storage_B_uuid,
                roles = {'vshard-router', 'vshard-storage'},
                servers = {
                    {alias = 'storage-B-1', instance_uuid = storage_B_1_uuid},
                    {alias = 'storage-B-2', instance_uuid = storage_B_2_uuid},
                },
            },
        },
    })

    g.cluster:start()
    g.cluster.main_server.net_box:eval([[
        local vars = require('cartridge.vars').new('cartridge.roles.coordinator')
        vars.options.IMMUNITY_TIMEOUT = 0
    ]])
    g.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            mode = 'stateful',
            state_provider = 'tarantool',
            tarantool_params = {
                uri = g.stateboard.net_box_uri,
                password = g.kvpassword,
            },
        }}
    )
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
        t.assert_covers(
            g.stateboard.net_box:call('get_leaders'),
            {
                [storage_A_uuid] = storage_A_1_uuid,
                [storage_B_uuid] = storage_B_1_uuid,
            }
        )
    end)
end)

g.after_all(function()
    g.cluster:stop()
    g.stateboard:stop()
    fio.rmtree(g.datadir)
end)

local q_promote = [[
    return require('cartridge').failover_promote(...)
]]
local q_readonliness = [[
    return box.info.ro
]]
local q_leadership = [[
    local failover = require('cartridge.failover')
    return failover.get_active_leaders()[...]
]]
local function eval(alias, ...)
    return g.cluster:server(alias).net_box:eval(...)
end

function g.test_change_failover_mode()
    -- Changing failover mode: disabled -> stateful. Stateboard unavailable

    -- Stateboard contains info about the current vclockeeper A1
    local vclockkeeper = g.stateboard.net_box:call('get_vclockkeeper', {storage_A_uuid})
    t.assert_covers(vclockkeeper, {instance_uuid = storage_A_1_uuid})

    -- Stateboard goes down
    g.stateboard:stop()
    fio.rmtree(g.stateboard.workdir)
    helpers.retrying({}, function()
        local res, err = eval('router', [[
            return require('cartridge.failover').get_coordinator()
        ]])
        t.assert_not(res)
        t.assert_covers(err, {
            class_name = 'StateProviderError',
            err = 'State provider unavailable'
        })

        t.assert_items_include(helpers.list_cluster_issues(g.cluster:server('router')), {{
            level = 'warning',
            topic = 'failover',
            message = "Can't obtain failover coordinator:" ..
                " State provider unavailable",
            instance_uuid = box.NULL,
            replicaset_uuid = box.NULL,
        }})
    end)

    -- And failover disabled
    g.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params', {{mode = 'disabled'}})

    -- New leader A2 is set
    -- But it will be promoted inconsistently
    -- No vclockkeeper will be set
    -- Old vclockkeeper A1 will remain in the disabled state provider
    g.cluster:server('router'):graphql({
        query = [[mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-0000-0000-000000000000"
                master: ["aaaaaaaa-aaaa-0000-0000-000000000002"]
            )
        }]]
    })

    local leader = eval('router', q_leadership, {storage_A_uuid})
    t.assert_equals(leader, storage_A_2_uuid)

    -- Stateful failover gets enabled
    g.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params', {{mode = 'stateful'}})

    -- Stateboard gets enabled as well
    g.stateboard:start()
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
        t.assert_covers(
            g.stateboard.net_box:call('get_leaders'),
            {[storage_A_uuid] = storage_A_2_uuid}
        )
    end)

    -- A2 still has leadership
    -- Coordinator updates vclockkeeper (it is A2 now)
    -- But vclock is set to {}, because vclockkeeper hasn't constituted itself
    local leader = eval('router', q_leadership, {storage_A_uuid})
    t.assert_equals(leader, storage_A_2_uuid)
    local vclockkeeper = g.stateboard.net_box:call('get_vclockkeeper', {storage_A_uuid})
    t.assert_covers(vclockkeeper, {
        instance_uuid = storage_A_2_uuid,
        vclock = {}
    })

    -- Next promotion will be consistent
    -- A1 will make itself known as a vclockkeeper
    -- Valid vclock (not {}) is a sign of a successful consistent switchover
    local ok, _ = eval('router', q_promote, {{[storage_A_uuid] = storage_A_1_uuid}})
    local vclock = eval('storage-A-1', [[ return box.info.vclock ]])
    t.assert_equals(ok, true)
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
        t.assert_covers(
            g.stateboard.net_box:call('get_vclockkeeper', {storage_A_uuid}),
            {
                instance_uuid = storage_A_1_uuid,
                vclock = vclock,
            }
        )
    end)
end

function g.test_force_promotion()

    g.stateboard:connect_net_box()
    local vclockkeeper = g.stateboard.net_box:call('get_vclockkeeper', {storage_A_uuid})
    t.assert_covers(vclockkeeper, {instance_uuid = storage_A_1_uuid})

    -- wait_lsn will be impossible due to the broken replication
    eval('storage-A-2', [[
        box.cfg{replication = {}}
    ]])
    eval('storage-A-1', [[
        box.schema.create_space('test')
    ]])

    -- A2 is promoted as a new leader
    local ok, _ = eval('router', q_promote, {{[storage_A_uuid] = storage_A_2_uuid}})
    t.assert_equals(ok, true)

    -- But it can't constitute itself because of the broken replication
    -- wait_lsn is failing
    t.assert_covers(
            g.stateboard.net_box:call('get_vclockkeeper', {storage_A_uuid}),
            {instance_uuid = storage_A_1_uuid}
        )
    t.assert_equals(eval('storage-A-2', q_readonliness), true)

    -- Assume wait_lsn will not succeed
    -- So, force promote it
    t.assert_equals(
        g.stateboard.net_box:call('set_vclockkeeper',
            {
                storage_A_uuid,
                storage_A_2_uuid,
                {}
            }), true)

    -- Finally A2 is a leader
    -- Though, promotion has been inconsistent
    helpers.retrying({}, function()
        t.assert_equals(eval('storage-A-2', q_readonliness), false)
    end)
    local leader = eval('router', q_leadership, {storage_A_uuid})
    t.assert_equals(leader, storage_A_2_uuid)
end
