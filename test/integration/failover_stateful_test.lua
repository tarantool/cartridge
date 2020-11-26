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
        cookie = require('digest').urandom(6):hex(),
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
    R1.net_box:eval([[
        local vars = require('cartridge.vars').new('cartridge.roles.coordinator')
        vars.options.IMMUNITY_TIMEOUT = 1
        vars.options.RECONNECT_PERIOD = 1
        require('log').info('Coordinator options updated')
    ]])

    g.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{failover_timeout = 0}}
    )
end

g_stateboard.before_all(function()
    local g = g_stateboard
    g.datadir = fio.tempdir()

    g.kvpassword = require('digest').urandom(6):hex()
    g.state_provider = require('luatest.server'):new({
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

    t.assert(g.cluster.main_server.net_box:call(
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

    t.assert(g.cluster.main_server.net_box:call(
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


add('test_state_provider_restart', function(g)
    g.state_provider:stop()

    helpers.retrying({}, function()
        local res, err = R1.net_box:eval([[
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
            R1.net_box:eval("return require('cartridge.failover').get_coordinator()"), {
                uri = 'localhost:13301',
                uuid = 'aaaaaaaa-aaaa-0000-0000-000000000001'
            }
        )
        t.assert_equals(helpers.list_cluster_issues(R1), {})
    end)

    helpers.retrying({}, function()
        t.assert_equals(R1.net_box:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S1.net_box:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S2.net_box:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S3.net_box:eval(q_leadership), storage_1_uuid)
    end)

    t.assert_equals(S1.net_box:eval(q_readonliness), false)
    t.assert_equals(S2.net_box:eval(q_readonliness), true)
    t.assert_equals(S3.net_box:eval(q_readonliness), true)
end)

add('test_coordinator_restart', function(g)
    R1.net_box:eval([[
        local cartridge = require('cartridge')
        local coordinator = cartridge.service_get('failover-coordinator')
        return coordinator.stop()
    ]])

    helpers.retrying({}, function()
        t.assert_equals(g.client:get_session():get_coordinator(), nil)
    end)

    R1.net_box:eval([[
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
        t.assert_equals(R1.net_box:eval(q_leadership), storage_2_uuid)
        t.assert_equals(S2.net_box:eval(q_leadership), storage_2_uuid)
        t.assert_equals(S3.net_box:eval(q_leadership), storage_2_uuid)
    end)

    helpers.retrying({}, function()
        t.assert_equals(R1.net_box:eval(q_readonliness), false)
        t.assert_equals(S2.net_box:eval(q_readonliness), false)
        t.assert_equals(S3.net_box:eval(q_readonliness), true)
    end)

    -----------------------------------------------------
    -- After old s1 recovers it doesn't take leadership
    S1:start()
    helpers.protect_from_rw(S1)

    g.cluster:wait_until_healthy(g.cluster.main_server)

    t.assert_equals(R1.net_box:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S1.net_box:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S2.net_box:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S3.net_box:eval(q_leadership), storage_2_uuid)

    t.assert_equals(R1.net_box:eval(q_readonliness), false)
    t.assert_equals(S1.net_box:eval(q_readonliness), true)
    t.assert_equals(S2.net_box:eval(q_readonliness), false)
    t.assert_equals(S3.net_box:eval(q_readonliness), true)

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

    t.assert_equals(R1.net_box:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S1.net_box:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S2.net_box:eval(q_leadership), storage_2_uuid)
    t.assert_equals(S3.net_box:eval(q_leadership), storage_2_uuid)

    helpers.unprotect(S1)
    -----------------------------------------------------
    -- Switching leadership is accomplished by the coordinator rpc

    log.info('--------------------------------------------------------')
    g.cluster:wait_until_healthy(g.cluster.main_server)
    local ok, err = R1.net_box:eval([[
        local cartridge = require('cartridge')
        local coordinator = cartridge.service_get('failover-coordinator')
        return coordinator.appoint_leaders(...)
    ]], {{[storage_uuid] = storage_1_uuid}})
    t.assert_equals({ok, err}, {true, nil})

    helpers.retrying({}, function()
        t.assert_equals(R1.net_box:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S1.net_box:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S2.net_box:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S3.net_box:eval(q_leadership), storage_1_uuid)
    end)
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
        t.assert_equals(R1.net_box:eval(q_leadership), storage_2_uuid)
        t.assert_equals(S1.net_box:eval(q_leadership), storage_2_uuid)
        t.assert_equals(S2.net_box:eval(q_leadership), storage_2_uuid)
        t.assert_equals(S3.net_box:eval(q_leadership), storage_2_uuid)
    end)

    S2:stop()
    log.info('------------------------------------------------------')
    helpers.retrying({}, function()
        t.assert(g.client:get_session():get_coordinator())
        t.assert_equals(R1.net_box:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S1.net_box:eval(q_leadership), storage_1_uuid)
        t.assert_equals(S3.net_box:eval(q_leadership), storage_1_uuid)
    end)

    S2:start()
    helpers.retrying({}, function()
        t.assert_equals(S2.net_box:eval(q_leadership), storage_1_uuid)
    end)

    -------------------------------------------------------

    local ok, err = S1.net_box:eval(q_promote, {{[storage_uuid] = 'invalid_uuid'}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'AppointmentError',
        err = [[Server "invalid_uuid" doesn't exist]],
    })

    local ok, err = S1.net_box:eval(q_promote, {{['invalid_uuid'] = storage_1_uuid}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'AppointmentError',
        err = [[Replicaset "invalid_uuid" doesn't exist]],
    })

    local ok, err = S1.net_box:eval(q_promote, {{[router_uuid] = storage_1_uuid}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'AppointmentError',
        err = string.format(
            [[Server %q doesn't belong to replicaset %q]],
            storage_1_uuid, router_uuid
        ),
    })

    -------------------------------------------------------

    g.state_provider:stop()
    helpers.retrying({}, function()
        local ok, err = S1.net_box:eval(q_promote, {{[router_uuid] = storage_1_uuid}})
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

    local ok, err = S1.net_box:eval(q_promote, {{[router_uuid] = storage_1_uuid}})
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
    t.assert_equals(R1.net_box:eval(q_leadership), box.NULL)
    t.assert_equals(S1.net_box:eval(q_leadership), box.NULL)
    t.assert_equals(S2.net_box:eval(q_leadership), storage_1_uuid)
    t.assert_equals(S3.net_box:eval(q_leadership), storage_1_uuid)

    t.assert_equals(R1.net_box:eval(q_readonliness), true)
    t.assert_equals(S1.net_box:eval(q_readonliness), true)
    t.assert_equals(S2.net_box:eval(q_readonliness), true)
    t.assert_equals(S3.net_box:eval(q_readonliness), true)

    local ret, err = R1.net_box:call(
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

    t.assert_equals(R1.net_box:eval(q_waitrw), {true})
    t.assert_equals(S1.net_box:eval(q_waitrw), {true})

    t.assert_equals(R1.net_box:eval(q_leadership), storage_1_uuid)
    t.assert_equals(S1.net_box:eval(q_leadership), storage_1_uuid)
    t.assert_equals(S2.net_box:eval(q_leadership), storage_1_uuid)
    t.assert_equals(S3.net_box:eval(q_leadership), storage_1_uuid)

    t.assert_equals(R1.net_box:eval(q_readonliness), false)
    t.assert_equals(S1.net_box:eval(q_readonliness), false)
    t.assert_equals(S2.net_box:eval(q_readonliness), true)
    t.assert_equals(S3.net_box:eval(q_readonliness), true)
    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(R1), {})
    end)
end)

add('test_issues', function(g)
    -- kill coordinator
    R1.net_box:eval([[
        local cartridge = require('cartridge')
        local coordinator = cartridge.service_get('failover-coordinator')
        coordinator.stop()
    ]])
    -- kill failover fiber on storage
    S3.net_box:eval([[
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
    g.cluster.main_server:graphql({query = [[
        mutation { cluster { schema(as_yaml: "{}") {} } }
    ]]})

    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(S1), {})
    end)
end)
