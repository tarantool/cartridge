local log = require('log')
local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local storage_uuid = helpers.uuid('b')
local storage_1_uuid = helpers.uuid('b', 'b', 1)
local storage_2_uuid = helpers.uuid('b', 'b', 2)
local storage_3_uuid = helpers.uuid('b', 'b', 3)

g.before_all(function()
    g.datadir = fio.tempdir()

    fio.mktree(fio.pathjoin(g.datadir, 'kingdom'))
    local kvpassword = require('digest').urandom(6):hex()
    g.kingdom = require('luatest.server'):new({
        command = fio.pathjoin(helpers.project_root, 'kingdom.lua'),
        workdir = fio.pathjoin(g.datadir, 'kingdom'),
        net_box_port = 14401,
        net_box_credentials = {
            user = 'client',
            password = kvpassword,
        },
        env = {
            TARANTOOL_LOCK_DELAY = 1,
            TARANTOOL_PASSWORD = kvpassword,
        },
    })
    g.kingdom:start()
    helpers.retrying({}, function()
        g.kingdom:connect_net_box()
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
                uuid = helpers.uuid('a'),
                roles = {'vshard-router', 'failover-coordinator'},
                servers = {
                    {alias = 'router', instance_uuid = helpers.uuid('a', 'a', 1)},
                },
            },
            {
                alias = 'storage',
                uuid = storage_uuid,
                roles = {'vshard-router', 'vshard-storage'},
                servers = {
                    {alias = 'storage-1', instance_uuid = storage_1_uuid},
                    {alias = 'storage-2', instance_uuid = storage_2_uuid},
                    {alias = 'storage-3', instance_uuid = storage_3_uuid},
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
                uri = g.kingdom.net_box_uri,
                password = kvpassword,
            },
        }}
    )
    helpers.retrying({}, function()
        g.kingdom:connect_net_box()
        t.assert_covers(
            g.kingdom.net_box:call('get_leaders'),
            {[storage_uuid] = storage_1_uuid}
        )
    end)
end)

g.after_all(function()
    g.cluster:stop()
    g.kingdom:stop()
    fio.rmtree(g.datadir)
end)

local q_leadership = string.format([[
    local failover = require('cartridge.failover')
    return failover.get_active_leaders()[%q]
]], storage_uuid)
local q_readonliness = [[
    return box.info.ro
]]
local function eval(alias, ...)
    return g.cluster:server(alias).net_box:eval(...)
end

function g.test_kingdom_restart()
    fio.rmtree(g.kingdom.workdir)
    g.kingdom:stop()

    helpers.retrying({}, function()
        local res, err = eval('router', [[
            return require('cartridge.failover').get_coordinator()
        ]])
        t.assert_not(res)
        t.assert_covers(err, {
            class_name = 'StateProviderError',
            err = 'State provider unavailable'
        })
    end)

    g.kingdom:start()
    helpers.retrying({}, function()
        g.kingdom:connect_net_box()
        t.assert_covers(
            g.kingdom.net_box:call('get_leaders'),
            {[storage_uuid] = storage_1_uuid}
        )
    end)

    helpers.retrying({}, function()
        t.assert_equals(
            eval('router', "return require('cartridge.failover').get_coordinator()"), {
                uri = 'localhost:13301',
                uuid = 'aaaaaaaa-aaaa-0000-0000-000000000001'
            }
        )
    end)

    helpers.retrying({}, function()
        t.assert_equals(eval('router',    q_leadership), storage_1_uuid)
        t.assert_equals(eval('storage-1', q_leadership), storage_1_uuid)
        t.assert_equals(eval('storage-2', q_leadership), storage_1_uuid)
        t.assert_equals(eval('storage-3', q_leadership), storage_1_uuid)
    end)

    t.assert_equals(eval('storage-1', q_readonliness), false)
    t.assert_equals(eval('storage-2', q_readonliness), true)
    t.assert_equals(eval('storage-3', q_readonliness), true)
end

function g.test_leader_restart()
    t.assert_equals(
        g.kingdom.net_box:call('longpoll', {0}),
        {
            [helpers.uuid('a')] = helpers.uuid('a', 'a', 1),
            [storage_uuid] = storage_1_uuid,
        }
    )

    -----------------------------------------------------
    g.cluster:server('storage-1'):stop()
    t.assert_equals(
        g.kingdom.net_box:call('longpoll', {3}),
        {[storage_uuid] = storage_2_uuid}
    )

    helpers.retrying({}, function()
        t.assert_equals(eval('router',    q_leadership), storage_2_uuid)
        t.assert_equals(eval('storage-2', q_leadership), storage_2_uuid)
        t.assert_equals(eval('storage-3', q_leadership), storage_2_uuid)
    end)

    t.assert_equals(eval('router',    q_readonliness), false)
    t.assert_equals(eval('storage-2', q_readonliness), false)
    t.assert_equals(eval('storage-3', q_readonliness), true)

    -----------------------------------------------------
    -- After old s1 recovers it doesn't take leadership
    g.cluster:server('storage-1'):start()
    g.cluster:wait_until_healthy(g.cluster.main_server)

    t.assert_equals(eval('router',    q_leadership), storage_2_uuid)
    t.assert_equals(eval('storage-1', q_leadership), storage_2_uuid)
    t.assert_equals(eval('storage-2', q_leadership), storage_2_uuid)
    t.assert_equals(eval('storage-3', q_leadership), storage_2_uuid)

    t.assert_equals(eval('router',    q_readonliness), false)
    t.assert_equals(eval('storage-1', q_readonliness), true)
    t.assert_equals(eval('storage-2', q_readonliness), false)
    t.assert_equals(eval('storage-3', q_readonliness), true)

    -----------------------------------------------------
    -- And even applying config doesn't change leadership
    g.cluster.main_server:graphql({
        query = [[
            mutation(
                $uuid: String!
                $master_uuid: [String!]!
            ) {
                edit_replicaset(
                    uuid: $uuid
                    master: $master_uuid
                )
            }
        ]],
        variables = {
            uuid = storage_uuid,
            master_uuid = {storage_3_uuid},
        },
    })

    t.assert_equals(eval('router',    q_leadership), storage_2_uuid)
    t.assert_equals(eval('storage-1', q_leadership), storage_2_uuid)
    t.assert_equals(eval('storage-2', q_leadership), storage_2_uuid)
    t.assert_equals(eval('storage-3', q_leadership), storage_2_uuid)

    -----------------------------------------------------
    -- Switching leadership is accomplised by the coordinator rpc

    log.info('--------------------------------------------------------')
    local ok, err = eval('router', [[
        local cartridge = require('cartridge')
        local coordinator = cartridge.service_get('failover-coordinator')
        return coordinator.appoint_leaders(...)
    ]], {{[storage_uuid] = storage_1_uuid}})
    t.assert_equals({ok, err}, {true, nil})

    helpers.retrying({}, function()
        t.assert_equals(eval('router',    q_leadership), storage_1_uuid)
        t.assert_equals(eval('storage-1', q_leadership), storage_1_uuid)
        t.assert_equals(eval('storage-2', q_leadership), storage_1_uuid)
        t.assert_equals(eval('storage-3', q_leadership), storage_1_uuid)
    end)
end

function g.test_leaderless()
    g.kingdom:stop()
    local router = g.cluster:server('router')
    -- restart both router (which is a failover coordinator)
    -- and storage-1 (which is a leader among storages)
    for _, s in pairs({'router', 'storage-1'}) do
        g.cluster:server(s):stop()
        g.cluster:server(s):start()
    end

    -----------------------------------------------------
    -- Chack that replicaset without leaders can exist
    g.cluster:wait_until_healthy(g.cluster.main_server)
    t.assert_equals(eval('router',    q_leadership), box.NULL)
    t.assert_equals(eval('storage-1', q_leadership), box.NULL)
    t.assert_equals(eval('storage-2', q_leadership), storage_1_uuid)
    t.assert_equals(eval('storage-3', q_leadership), storage_1_uuid)

    t.assert_equals(eval('router',    q_readonliness), true)
    t.assert_equals(eval('storage-1', q_readonliness), true)
    t.assert_equals(eval('storage-2', q_readonliness), true)
    t.assert_equals(eval('storage-3', q_readonliness), true)

    local ret, err = g.cluster.main_server.net_box:call(
        'package.loaded.vshard.router.callrw',
        {1, 'box.space.test:insert', {{1, 'one'}}}
    )
    t.assert_equals(ret, nil)
    t.assert_covers(err, {
        name = "MISSING_MASTER",
        type = "ShardingError",
        replicaset_uuid = storage_uuid,
        message = "Master is not configured for replicaset " .. storage_uuid,
    })

    t.assert_items_equals(
        router:graphql({
            query = [[{
                replicasets {
                    uuid
                    master { uuid }
                    active_master { uuid }
                }
            }]]
        }).data.replicasets,
        {{
            uuid = router.replicaset_uuid,
            master = {uuid = 'void'},
            active_master = {uuid = 'void'},
        }, {
            uuid = storage_uuid,
            master = {uuid = 'void'},
            active_master = {uuid = 'void'},
        }}
    )

    -----------------------------------------------------
    -- Check cluster repairs

    g.kingdom:start()
    local q_waitrw = 'return {pcall(box.ctl.wait_rw, 3)}'

    t.assert_equals(eval('router',    q_waitrw), {true})
    t.assert_equals(eval('storage-1', q_waitrw), {true})

    t.assert_equals(eval('router',    q_leadership), storage_1_uuid)
    t.assert_equals(eval('storage-1', q_leadership), storage_1_uuid)
    t.assert_equals(eval('storage-2', q_leadership), storage_1_uuid)
    t.assert_equals(eval('storage-3', q_leadership), storage_1_uuid)

    t.assert_equals(eval('router',    q_readonliness), false)
    t.assert_equals(eval('storage-1', q_readonliness), false)
    t.assert_equals(eval('storage-2', q_readonliness), true)
    t.assert_equals(eval('storage-3', q_readonliness), true)
end
