local log = require('log')
local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local storage_uuid = helpers.uuid('b')
local storage_1_uuid = helpers.uuid('b', 'b', 1)
local storage_2_uuid = helpers.uuid('b', 'b', 2)
local storage_3_uuid = helpers.uuid('b', 'b', 3)

local router_uuid = helpers.uuid('a')
local router_1_uuid = helpers.uuid('a', 'a', 1)

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
                uri = g.stateboard.net_box_uri,
                password = g.kvpassword,
            },
        }}
    )
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
        t.assert_covers(
            g.stateboard.net_box:call('get_leaders'),
            {[storage_uuid] = storage_1_uuid}
        )
    end)
end)

g.after_all(function()
    g.cluster:stop()
    g.stateboard:stop()
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

function g.test_stateboard_restart()
    fio.rmtree(g.stateboard.workdir)
    g.stateboard:stop()

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

    g.stateboard:start()
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
        t.assert_covers(
            g.stateboard.net_box:call('get_leaders'),
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
        t.assert_equals(helpers.list_cluster_issues(g.cluster:server('router')), {})
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

function g.test_coordinator_restart()
    eval('router', [[
        local cartridge = require('cartridge')
        local coordinator = cartridge.service_get('failover-coordinator')
        return coordinator.stop()
    ]])

    helpers.retrying({}, function()
        t.assert_equals(
            g.stateboard.net_box:call('get_coordinator'),
            nil
        )
    end)

    eval('router', [[
        local confapplier = require('cartridge.confapplier')
        return confapplier.apply_config(confapplier.get_active_config())
    ]])

    helpers.retrying({}, function()
        t.assert_equals(
            g.stateboard.net_box:call('get_coordinator'),
            {
                uri = g.cluster:server('router').advertise_uri,
                uuid = g.cluster:server('router').instance_uuid,
            }
        )
    end)
end

function g.test_leader_restart()
    t.assert_equals(
        g.stateboard.net_box:call('longpoll', {0}),
        {
            [router_uuid] = router_1_uuid,
            [storage_uuid] = storage_1_uuid,
        }
    )

    -----------------------------------------------------
    g.cluster:server('storage-1'):stop()
    t.assert_equals(
        g.stateboard.net_box:call('longpoll', {3}),
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
            master_uuid = {storage_1_uuid, storage_3_uuid, storage_2_uuid},
        },
    })

    t.assert_equals(eval('router',    q_leadership), storage_2_uuid)
    t.assert_equals(eval('storage-1', q_leadership), storage_2_uuid)
    t.assert_equals(eval('storage-2', q_leadership), storage_2_uuid)
    t.assert_equals(eval('storage-3', q_leadership), storage_2_uuid)

    -----------------------------------------------------
    -- Switching leadership is accomplished by the coordinator rpc

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

local q_promote = [[
    return require('cartridge').failover_promote(...)
]]

function g.test_leader_promote()
    g.stateboard:connect_net_box()
    helpers.retrying({}, function()
        t.assert(g.stateboard.net_box:call('get_coordinator') ~= nil)
    end)

    -------------------------------------------------------

    local storage_1 = g.cluster:server('storage-1')
    local resp = storage_1:graphql({
        query = [[
        mutation(
                $replicaset_uuid: String!
                $instance_uuid: String!
            ) {
            cluster {
                failover_promote(
                    replicaset_uuid: $replicaset_uuid
                    instance_uuid: $instance_uuid
                )
            }
        }]],
        variables = {
            replicaset_uuid = storage_uuid,
            instance_uuid = storage_2_uuid,
        }
    })
    t.assert_type(resp['data'], 'table')
    t.assert_equals(resp['data']['cluster']['failover_promote'], true)

    helpers.retrying({}, function()
        t.assert_equals(eval('router',    q_leadership), storage_2_uuid)
        t.assert_equals(eval('storage-1', q_leadership), storage_2_uuid)
        t.assert_equals(eval('storage-2', q_leadership), storage_2_uuid)
        t.assert_equals(eval('storage-3', q_leadership), storage_2_uuid)
    end)

    local storage_2 = g.cluster:server('storage-2')
    storage_2:stop()

    helpers.retrying({}, function()
        t.assert_equals(eval('router',    q_leadership), storage_1_uuid)
        t.assert_equals(eval('storage-1', q_leadership), storage_1_uuid)
        t.assert_equals(eval('storage-3', q_leadership), storage_1_uuid)
    end)

    storage_2:start()
    -- g.cluster:wait_until_healthy(g.cluster.main_server)

    helpers.retrying({}, function()
        t.assert_equals(eval('storage-2', q_leadership), storage_1_uuid)
    end)

    -------------------------------------------------------
    helpers.assert_error_tuple({
        class_name = 'AppointmentError',
        err = [[Server "invalid_uuid" doesn't exist]],
    }, eval('storage-1', q_promote, {{[storage_uuid] = 'invalid_uuid'}}))

    helpers.assert_error_tuple({
        class_name = 'AppointmentError',
        err = [[Replicaset "invalid_uuid" doesn't exist]],
    }, eval('storage-1', q_promote, {{['invalid_uuid'] = storage_1_uuid}}))

    helpers.assert_error_tuple({
        class_name = 'AppointmentError',
        err = string.format(
            [[Server %q doesn't belong to replicaset %q]],
            storage_1_uuid, router_uuid
        ),
    }, eval('storage-1', q_promote, {{[router_uuid] = storage_1_uuid}}))

    -------------------------------------------------------

    g.stateboard:stop()
    helpers.retrying({}, function()
        helpers.assert_error_tuple({
            class_name = 'StateProviderError',
            err = 'State provider unavailable',
        }, eval('storage-1', q_promote, {{[router_uuid] = storage_1_uuid}}))
    end)

    g.stateboard:start()
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
    end)

    -------------------------------------------------------

    local router = g.cluster:server('router')
    router:stop()

    helpers.assert_error_tuple({
        class_name = 'StateProviderError',
        err = 'State provider unavailable',
    }, eval('storage-1', q_promote, {{[router_uuid] = storage_1_uuid}}))

    router:start()
end

function g.test_leaderless()
    g.stateboard:stop()
    local router = g.cluster:server('router')
    -- restart both router (which is a failover coordinator)
    -- and storage-1 (which is a leader among storages)
    for _, s in pairs({'router', 'storage-1'}) do
        g.cluster:server(s):stop()
        g.cluster:server(s):start()
    end

    -----------------------------------------------------
    -- Check that replicaset without leaders can exist
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

    g.stateboard:start()
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
    end)
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
    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.cluster:server('router')), {})
    end)
end

function g.test_issues()
    -- kill coordinator
    eval('router', [[
        local cartridge = require('cartridge')
        local coordinator = cartridge.service_get('failover-coordinator')
        coordinator.stop()
    ]])
    -- kill failover fiber on storage
    eval('storage-3', [[
        local vars = require('cartridge.vars').new('cartridge.failover')
        vars.client:drop_session()
        vars.failover_fiber:cancel()
    ]])

    helpers.retrying({}, function()
        t.assert_items_equals(helpers.list_cluster_issues(g.cluster:server('router')), {{
            level = 'warning',
            topic = 'failover',
            message = "There is no active failover coordinator",
            replicaset_uuid = box.NULL,
            instance_uuid = box.NULL,
        }, {
            level = 'warning',
            topic = 'failover',
            message = "Failover is stuck on " ..
                g.cluster:server('storage-3').advertise_uri ..
                ": Failover fiber is dead!",
            replicaset_uuid = box.NULL,
            instance_uuid = storage_3_uuid,
        }})
    end)

    -- Trigger apply_config
    g.cluster.main_server:graphql({query = [[
        mutation { cluster { schema(as_yaml: "{}") {} } }
    ]]})

    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.cluster:server('storage-1')), {})
    end)
end
