local log = require('log')
local fio = require('fio')
local t = require('luatest')
local helpers = require('test.helper')

local etcd2_client = require('cartridge.etcd2-client')
local stateboard_client = require('cartridge.stateboard-client')

local g_etcd2 = t.group('integration.failover_stateful.etcd2')
local g_stateboard = t.group('integration.failover_stateful.stateboard')

local storage_uuid = helpers.uuid('b')
local S1; local storage_1_uuid = helpers.uuid('b', 'b', 1)
local S2; local storage_2_uuid = helpers.uuid('b', 'b', 2)
local S3; local storage_3_uuid = helpers.uuid('b', 'b', 3)

local router_uuid = helpers.uuid('a')
local R1; local router_1_uuid = helpers.uuid('a', 'a', 1)

local function setup_cluster(g)
    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        env = {
            TARANTOOL_SWIM_PROTOCOL_PERIOD_SECONDS = 0.2,
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

    R1 = g.cluster:server('router')
    S1 = g.cluster:server('storage-1')
    S2 = g.cluster:server('storage-2')
    S3 = g.cluster:server('storage-3')

    g.cluster:start()
    R1:eval([[
        local vars = require('cartridge.vars').new('cartridge.roles.coordinator')
        vars.options.IMMUNITY_TIMEOUT = 1
        vars.options.RECONNECT_PERIOD = 1
        require('log').info('Coordinator options updated')
    ]])

    g.cluster.main_server:call(
        'package.loaded.cartridge.failover_set_params',
        {{failover_timeout = 0}}
    )
end

g_stateboard.before_all(function()
    local g = g_stateboard
    g.datadir = fio.tempdir()

    g.kvpassword = helpers.random_cookie()
    g.state_provider = helpers.Stateboard:new({
        command = helpers.entrypoint('srv_stateboard'),
        workdir = fio.pathjoin(g.datadir, 'stateboard'),
        net_box_port = 14401,
        net_box_credentials = {
            user = 'client',
            password = g.kvpassword,
        },
        env = {
            TARANTOOL_LOCK_DELAY = 2,
            TARANTOOL_PASSWORD = g.kvpassword,
        },
    })

    g.state_provider:start()
    g.client = stateboard_client.new({
        uri = 'localhost:' .. g.state_provider.net_box_port,
        password = g.kvpassword,
        call_timeout = 1,
    })

    setup_cluster(g)

    t.assert(g.cluster.main_server:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            mode = 'stateful',
            state_provider = 'tarantool',
            tarantool_params = {
                uri = g.state_provider.net_box_uri,
                password = g.kvpassword,
            },
        }}
    ))
end)

g_etcd2.before_all(function()
    local g = g_etcd2
    local etcd_path = os.getenv('ETCD_PATH')
    t.skip_if(etcd_path == nil, 'etcd missing')

    local URI = 'http://127.0.0.1:14001'
    g.datadir = fio.tempdir()
    g.state_provider = helpers.Etcd:new({
        workdir = fio.tempdir('/tmp'),
        etcd_path = etcd_path,
        peer_url = 'http://127.0.0.1:17001',
        client_url = 'http://127.0.0.1:14001',
    })

    g.state_provider:start()
    g.client = etcd2_client.new({
        prefix = 'failover_stateful_test',
        endpoints = {URI},
        lock_delay = 3,
        username = '',
        password = '',
        request_timeout = 1,
    })

    setup_cluster(g)

    t.assert(g.cluster.main_server:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            mode = 'stateful',
            state_provider = 'etcd2',
            etcd2_params = {
                prefix = 'failover_stateful_test',
                endpoints = {URI},
                lock_delay = 3,
            },
        }}
    ))
end)

local function after_all(g)
    g.cluster:stop()
    g.state_provider:stop()
    fio.rmtree(g.state_provider.workdir)
    fio.rmtree(g.datadir)
end
g_stateboard.after_all(function() after_all(g_stateboard) end)
g_etcd2.after_all(function() after_all(g_etcd2) end)

local function before_each(g)
    helpers.retrying({}, function()
        t.assert_equals(
            g.client:get_session():get_coordinator(),
            {
                uri = R1.advertise_uri,
                uuid = R1.instance_uuid,
            }
        )
        t.assert_equals(
            g.client:get_session():get_leaders(),
            {
                [router_uuid] = router_1_uuid,
                [storage_uuid] = storage_1_uuid,
            }
        )
    end)
    g.cluster:wait_until_healthy()
end
g_stateboard.before_each(function() before_each(g_stateboard) end)
g_etcd2.before_each(function() before_each(g_etcd2) end)

local q_leadership = string.format([[
    local failover = require('cartridge.failover')
    return failover.get_active_leaders()[%q]
]], storage_uuid)
local q_readonliness = [[
    return box.info.ro
]]

local function add(name, fn)
    g_stateboard[name] = fn
    g_etcd2[name] = fn
end

local function after_each(g)
    g.cluster:wait_until_healthy(g.cluster.main_server)
    helpers.retrying({}, function()
        local ok, err = R1:eval([[
            local cartridge = require('cartridge')
            local coordinator = cartridge.service_get('failover-coordinator')
            return coordinator.appoint_leaders(...)
        ]], {{[storage_uuid] = storage_1_uuid}})
        t.assert_equals({ok, err}, {true, nil})
    end)

    helpers.retrying({}, function()
        t.assert_equals(R1:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S1:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S2:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S3:eval(q_leadership), storage_1_uuid)
    end)
end
g_stateboard.after_each(function() after_each(g_stateboard) end)
g_etcd2.after_each(function() after_each(g_etcd2) end)

add('test_state_provider_restart', function(g)
    g.state_provider:stop()

    helpers.retrying({}, function()
        local res, err = R1:eval([[
            return require('cartridge.failover').get_coordinator()
        ]])
        t.assert_not(res)
        t.assert_covers(err, {
            class_name = 'StateProviderError',
            err = 'State provider unavailable'
        })

        t.assert_items_include(helpers.list_cluster_issues(R1), {{
            level = 'warning',
            topic = 'failover',
            message = "Can't obtain failover coordinator:" ..
                " State provider unavailable",
            instance_uuid = box.NULL,
            replicaset_uuid = box.NULL,
        }})
    end)

    fio.rmtree(g.state_provider.workdir)
    g.state_provider:start()

    helpers.retrying({}, function()
        t.assert_covers(
            g.client:get_session():get_leaders(),
            {[storage_uuid] = storage_1_uuid}
        )
    end)

    helpers.retrying({}, function()
        t.assert_equals(
            R1:eval("return require('cartridge.failover').get_coordinator()"), {
                uri = 'localhost:13301',
                uuid = 'aaaaaaaa-aaaa-0000-0000-000000000001'
            }
        )
        t.assert_equals(helpers.list_cluster_issues(R1), {})
    end)

    helpers.retrying({}, function()
        t.assert_equals(R1:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S1:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S2:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S3:eval(q_leadership), storage_1_uuid)
    end)

    t.assert_equals(S1:eval(q_readonliness), false)
    t.assert_equals(S2:eval(q_readonliness), true)
    t.assert_equals(S3:eval(q_readonliness), true)
end)

add('test_coordinator_restart', function(g)
    R1:eval([[
        local cartridge = require('cartridge')
        local coordinator = cartridge.service_get('failover-coordinator')
        return coordinator.stop()
    ]])

    helpers.retrying({}, function()
        t.assert_equals(g.client:get_session():get_coordinator(), nil)
    end)

    R1:eval([[
        local confapplier = require('cartridge.confapplier')
        local state = confapplier.wish_state('RolesConfigured')
        assert(state == 'RolesConfigured', state)
        return confapplier.apply_config(confapplier.get_active_config())
    ]])

    helpers.retrying({}, function()
        t.assert_equals(
            g.client:get_session():get_coordinator(),
            {
                uri = R1.advertise_uri,
                uuid = R1.instance_uuid,
            }
        )
        t.assert_equals(helpers.list_cluster_issues(R1), {})
    end)
end)

add('test_leader_restart', function(g)
    -----------------------------------------------------
    g.client:longpoll(0)
    S1:stop()
    helpers.retrying({}, function()
        t.assert_covers(
            g.client:longpoll(3),
            {[storage_uuid] = storage_2_uuid}
        )
    end)

    helpers.retrying({}, function()
        t.assert_equals(R1:eval(q_leadership), storage_2_uuid)
        t.assert_equals(S2:eval(q_leadership), storage_2_uuid)
        t.assert_equals(S3:eval(q_leadership), storage_2_uuid)
    end)

    helpers.retrying({}, function()
        t.assert_equals(R1:eval(q_readonliness), false)
        t.assert_equals(S2:eval(q_readonliness), false)
        t.assert_equals(S3:eval(q_readonliness), true)
    end)

    -----------------------------------------------------
    -- After old s1 recovers it doesn't take leadership
    S1:start()
    helpers.protect_from_rw(S1)

    g.cluster:wait_until_healthy(g.cluster.main_server)

    t.assert_equals(R1:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S1:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S2:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S3:eval(q_leadership), storage_2_uuid)

    t.assert_equals(R1:eval(q_readonliness), false)
    t.assert_equals(S1:eval(q_readonliness), true)
    t.assert_equals(S2:eval(q_readonliness), false)
    t.assert_equals(S3:eval(q_readonliness), true)

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
            master_uuid = {storage_1_uuid, storage_2_uuid, storage_3_uuid},
        },
    })

    t.assert_equals(R1:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S1:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S2:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S3:eval(q_leadership), storage_2_uuid)

    helpers.unprotect(S1)
end)

add('test_leader_in_operation_error', function(g)
    g.client:longpoll(0)

    -- imitate OperationError
    local ok, err = pcall(S1.exec, S1, function()
        local confapplier = require('cartridge.confapplier')
        confapplier.set_state('ConfiguringRoles')
        local state = confapplier.wish_state('ConfiguringRoles')
        assert(state == 'ConfiguringRoles', state)
        confapplier.set_state('OperationError')
        local state = confapplier.wish_state('OperationError')
        assert(state == 'OperationError', state)
    end)

    t.xfail_if(not ok, 'Flaky test')
    t.assert(ok, err)

    helpers.retrying({}, function()
        t.assert_covers(
            g.client:longpoll(3),
            {[storage_uuid] = storage_2_uuid}
        )
    end)

    helpers.retrying({}, function()
        t.assert_equals(R1:eval(q_leadership), storage_2_uuid)
        t.assert_equals(S2:eval(q_leadership), storage_2_uuid)
        t.assert_equals(S3:eval(q_leadership), storage_2_uuid)
    end)

    helpers.retrying({}, function()
        t.assert_equals(R1:eval(q_readonliness), false)
        t.assert_equals(S2:eval(q_readonliness), false)
        t.assert_equals(S3:eval(q_readonliness), true)
    end)

    -- Since instance is in OperationError, we shoud force reapply config
    g.cluster.main_server:graphql({
        query = [[
            mutation ($uuids: [String!]) {
                cluster { config_force_reapply(uuids: $uuids) }
            }
        ]],
        variables = {uuids = {
            S1.instance_uuid,
        }}
    })

    helpers.protect_from_rw(S1)

    g.cluster:wait_until_healthy(g.cluster.main_server)

    t.assert_equals(R1:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S1:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S2:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S3:eval(q_leadership), storage_2_uuid)

    t.assert_equals(R1:eval(q_readonliness), false)
    t.assert_equals(S1:eval(q_readonliness), true)
    t.assert_equals(S2:eval(q_readonliness), false)
    t.assert_equals(S3:eval(q_readonliness), true)

    helpers.unprotect(S1)
end)

local q_promote = [[
    return require('cartridge').failover_promote(...)
]]

add('test_leader_promote', function(g)
    helpers.retrying({}, function()
        t.assert(g.client:get_session():get_coordinator())
    end)

    -------------------------------------------------------

    local resp = S1:graphql({
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
        t.assert_equals(R1:eval(q_leadership), storage_2_uuid)
        t.assert_equals(S1:eval(q_leadership), storage_2_uuid)
        t.assert_equals(S2:eval(q_leadership), storage_2_uuid)
        t.assert_equals(S3:eval(q_leadership), storage_2_uuid)
    end)

    S2:stop()
    log.info('------------------------------------------------------')
    helpers.retrying({}, function()
        t.assert(g.client:get_session():get_coordinator())
        t.assert_equals(R1:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S1:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S3:eval(q_leadership), storage_1_uuid)
    end)

    S2:start()
    helpers.retrying({}, function()
        t.assert_equals(S2:eval(q_leadership), storage_1_uuid)
    end)

    -------------------------------------------------------

    local ok, err = S1:eval(q_promote, {{[storage_uuid] = 'invalid_uuid'}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'AppointmentError',
        err = [["localhost:13301": Server "invalid_uuid" doesn't exist]],
    })

    local ok, err = S1:eval(q_promote, {{['invalid_uuid'] = storage_1_uuid}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'AppointmentError',
        err = [["localhost:13301": Replicaset "invalid_uuid" doesn't exist]],
    })

    local ok, err = S1:eval(q_promote, {{[router_uuid] = storage_1_uuid}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'AppointmentError',
        err = string.format(
            [["localhost:13301": Server %q doesn't belong to replicaset %q]],
            storage_1_uuid, router_uuid
        ),
    })

    -------------------------------------------------------

    g.state_provider:stop()
    helpers.retrying({}, function()
        local ok, err = S1:eval(q_promote, {{[router_uuid] = storage_1_uuid}})
        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'StateProviderError',
            err = 'State provider unavailable',
        })
    end)

    g.state_provider:start()
    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(S1), {})
    end)
    -------------------------------------------------------

    R1:stop()

    helpers.retrying({}, function()
        t.assert_equals(g.client:get_session():get_coordinator(), nil)
    end)

    local ok, err = S1:eval(q_promote, {{[router_uuid] = storage_1_uuid}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'PromoteLeaderError',
        err = 'There is no active coordinator',
    })

    R1:start()
end)

add('test_leaderless', function(g)
    g.state_provider:stop()
    -- restart both router (which is a failover coordinator)
    -- and storage-1 (which is a leader among storages)
    for _, s in pairs({'router', 'storage-1'}) do
        g.cluster:server(s):stop()
        g.cluster:server(s):start()
    end

    -----------------------------------------------------
    -- Check that replicaset without leaders can exist
    g.cluster:wait_until_healthy(g.cluster.main_server)
    t.assert_equals(R1:eval(q_leadership), box.NULL)
    t.assert_equals(S1:eval(q_leadership), box.NULL)
    t.assert_equals(S2:eval(q_leadership), storage_1_uuid)
    t.assert_equals(S3:eval(q_leadership), storage_1_uuid)

    t.assert_equals(R1:eval(q_readonliness), true)
    t.assert_equals(S1:eval(q_readonliness), true)
    t.assert_equals(S2:eval(q_readonliness), true)
    t.assert_equals(S3:eval(q_readonliness), true)

    local ret, err = R1:call(
        'package.loaded.vshard.router.callrw',
        {1, 'box.space.test:insert', {{1, 'one'}}}
    )
    t.assert_equals(ret, nil)
    t.assert_covers(err, {
        name = "MISSING_MASTER",
        type = "ShardingError",
        replicaset = storage_uuid,
        message = "Master is not configured for replicaset " .. storage_uuid,
    })

    t.assert_items_equals(
        R1:graphql({
            query = [[{
                replicasets {
                    uuid
                    master { uuid }
                    active_master { uuid }
                }
            }]]
        }).data.replicasets,
        {{
            uuid = router_uuid,
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

    g.state_provider:start()
    local q_waitrw = 'return {pcall(box.ctl.wait_rw, 3)}'

    t.assert_equals(R1:eval(q_waitrw), {true})
    t.assert_equals(S1:eval(q_waitrw), {true})

    t.assert_equals(R1:eval(q_leadership), storage_1_uuid)
    t.assert_equals(S1:eval(q_leadership), storage_1_uuid)
    t.assert_equals(S2:eval(q_leadership), storage_1_uuid)
    t.assert_equals(S3:eval(q_leadership), storage_1_uuid)

    t.assert_equals(R1:eval(q_readonliness), false)
    t.assert_equals(S1:eval(q_readonliness), false)
    t.assert_equals(S2:eval(q_readonliness), true)
    t.assert_equals(S3:eval(q_readonliness), true)
    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(R1), {})
    end)
end)

add('test_issues', function(g)
    -- kill coordinator
    R1:eval([[
        local cartridge = require('cartridge')
        local coordinator = cartridge.service_get('failover-coordinator')
        coordinator.stop()
    ]])
    -- kill failover fiber on storage
    S3:eval([[
        local vars = require('cartridge.vars').new('cartridge.failover')
        vars.client:drop_session()
        vars.failover_fiber:cancel()
    ]])

    helpers.retrying({}, function()
        t.assert_items_equals(helpers.list_cluster_issues(R1), {{
            level = 'warning',
            topic = 'failover',
            message = "There is no active failover coordinator",
            replicaset_uuid = box.NULL,
            instance_uuid = box.NULL,
        }, {
            level = 'warning',
            topic = 'failover',
            message = "Failover is stuck on " .. S3.advertise_uri ..
                " (storage-3): Failover fiber is dead!",
            replicaset_uuid = box.NULL,
            instance_uuid = storage_3_uuid,
        }})
    end)

    -- Trigger apply_config
    g.cluster.main_server:graphql({
        query = [[
            mutation ($uuids: [String!]) {
                cluster { config_force_reapply(uuids: $uuids) }
            }
        ]],
        variables = {uuids = {
            R1.instance_uuid,
            S3.instance_uuid,
        }}
    })

    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(S1), {})
    end)
end)

add('test_force_promote_timeout', function(g)
    -- Failover may sleep waiting for a vclockkeeper. If an old vclockkeeper
    -- was stopped and the current instance was promoted consistently, it'll
    -- attempt to get old vclockkeepers info and subsequently fail. However,
    -- it should react fast enough to the change of the vclockkeeper
    -- (e.g. `force_inconsistency = true`).
    --
    -- ## Before the patch

    --                            reconfigure_all():
    -- [------ 4 sec ------]        constitute_oneself():
    -- |                              get_vsckockkeeper
    -- [===================]          get_lsn
    --
    -- 0----1----2----3----4----5---- (t)
    --                   ^
    --   [---- 3 sec ----]        promote({force_inconsistency = true}):
    --   |                          get_coordinator (~0 sec)
    --   |                          force_inconsistency (~0 sec)
    --   [===============]          wait_rw (3 sec)
    --                   X          "WaitRwError: timed out"
    --
    -- In the example above the vclockkeeper is unresponsive. Before the fix,
    -- it would wait for ~7 seconds before fetching the correct vclockkeeper.
    -- However, if during this wait user initiates inconsistent promotion with
    -- a timeout of 3 seconds, `wait_rw` will fail with this timeout.
    -- That's why `constitute_oneself + fiber_sleep` should have the same
    -- period/timeout as `wait_rw`, which is `WAITLSN_TIMEOUT=3`.
    --
    -- ## After the patch (change get_lsn timeout calculation)
    --
    --                            reconfigure_all():
    --
    -- [---- 3 sec ---]             constitute_oneself():
    -- []                             get_vsckockkeeper (~0 sec)
    --  [=============]               get_lsn (till the deadline)
    --
    --                [-]           constitute_oneself()
    --                []              get_vsckockkeeper (~0 sec)
    --                 []             set_vclockkeeper (~0 sec)
    --                  ^             become rw
    --
    -- 0----1----2----3----4----5---- (t)
    --
    --   [---- 3 sec ----]        promote({force_inconsistency = true}):
    --   |                          get_coordinator (~0 sec)
    --   |                          force_inconsistency (~0 sec)
    --   [===============]          wait_rw (3 sec)
    --                  ^           "ok"
    --
    -- When `constitute_oneself + fiber_sleep` has a 3s period the gap when
    -- instance deals with two different vclockkeepers is less than 3s. As a
    -- result, `wait_rw` won't fail anymore since `constitute_oneself` gets
    -- the actual vclockkeeper and sets instance to rw.

    S1.process:kill('STOP')

    -- Speed up the test
    S2:eval([[
        local vars = require('cartridge.vars').new('cartridge.failover')
        vars.options.WAITLSN_TIMEOUT = 0.5
    ]])

    helpers.retrying({}, function()
        local res, err = S2:call('package.loaded.cartridge.failover_promote', {
            {[g.cluster.replicasets[2].uuid] = S2.instance_uuid},
            {force_inconsistency = false}
        })

        t.assert_equals(res, nil)
        t.assert_equals(err.str, 'WaitRwError: \"localhost:13303\": timed out')
    end)

    require('fiber').sleep(1) -- NETBOX_CALL_TIMEOUT

    helpers.retrying({}, function()
        local res, err = S2:call('package.loaded.cartridge.failover_promote', {
            {[g.cluster.replicasets[2].uuid] = S2.instance_uuid},
            {force_inconsistency = true}
        })

        t.assert_equals(err, nil)
        t.assert_equals(res, true)
    end)
    S1.process:kill('CONT')
end)

add('test_invalid_params', function(g)
    local _, err = g.cluster.main_server:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            mode = 'stateful',
            state_provider = 'etcd3',
            etcd2_params = {
                prefix = 'failover_stateful_test',
                endpoints = {},
                lock_delay = 3,
            },
        }}
    )
    t.assert_str_contains(err.err, 'unknown state_provider "etcd3"')
    t.assert_equals(g.cluster.main_server:exec(function()
        return require('cartridge.confapplier').get_state()
    end), 'RolesConfigured')
end)
