local fio = require('fio')
local t = require('luatest')
local fun = require('fun')
local g = t.group()

local helpers = require('test.helper')

local replicaset_uuid = helpers.uuid('b')
local storage_1_uuid = helpers.uuid('b', 'b', 1)
local storage_2_uuid = helpers.uuid('b', 'b', 2)
local storage_3_uuid = helpers.uuid('b', 'b', 3)

local cluster

g.before_all = function()
    cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {
            {
                alias = 'router',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = {
                    {instance_uuid = helpers.uuid('a', 'a', 1)},
                },
            },
            {
                alias = 'storage',
                uuid = replicaset_uuid,
                roles = {'vshard-router', 'vshard-storage'},
                servers = {
                    {instance_uuid = storage_1_uuid},
                    {instance_uuid = storage_2_uuid},
                    {instance_uuid = storage_3_uuid},
                },
            },
        },
    })
    cluster:start()
end

g.after_all = function()
    cluster:stop()
    fio.rmtree(cluster.datadir)
end


local function get_master(uuid)
    local response = cluster.main_server:graphql({
        query = [[
            query(
                $uuid: String!
            ){
                replicasets(uuid: $uuid) {
                    master { uuid }
                    active_master { uuid }
                }
            }
        ]],
        variables = {uuid = uuid}
    })
    local replicasets = response.data.replicasets
    t.assert_equals(#replicasets, 1)
    local replicaset = replicasets[1]
    return {replicaset.master.uuid, replicaset.active_master.uuid}
end

local function set_master(uuid, master_uuid)
    cluster.main_server:graphql({
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
        variables = {uuid = uuid, master_uuid = {master_uuid}}
    })
end

local function set_all_rw(uuid, all_rw)
    helpers.retrying({}, function()
        cluster.main_server:graphql({
            query = [[
                mutation(
                    $uuid: String!
                    $all_rw: Boolean!
                ) {
                    edit_replicaset(
                        uuid: $uuid
                        all_rw: $all_rw
                    )
                }
            ]],
            variables = {uuid = uuid, all_rw = all_rw}
        })
    end)
end

local function check_all_box_rw()
    for _, server in pairs(cluster.servers) do
        if server.net_box ~= nil then
            t.assert_equals(
                {[server.alias] = server:eval('return box.cfg.read_only')},
                {[server.alias] = false}
            )
        end
    end
end


local function get_failover()
    return cluster.main_server:graphql({query = [[
        {
            cluster { failover }
        }
    ]]}).data.cluster.failover
end

local function set_failover(enabled)
    local response = cluster.main_server:graphql({
        query = [[
            mutation($enabled: Boolean!) {
                cluster { failover(enabled: $enabled) }
            }
        ]],
        variables = {enabled = enabled}
    })
    return response.data.cluster.failover
end

local function get_failover_params()
    return cluster.main_server:graphql({query = [[
        {
            cluster { failover_params {
                mode
                state_provider
                failover_timeout
                tarantool_params {uri password}
                etcd2_params {
                    prefix
                    lock_delay
                    endpoints
                    username
                    password
                }
                fencing_enabled
                fencing_timeout
                fencing_pause
                leader_autoreturn
                autoreturn_delay
                check_cookie_hash
            }}
        }
    ]]}).data.cluster.failover_params
end

local function set_failover_params(vars)
    local response = cluster.main_server:graphql({
        query = [[
            mutation(
                $mode: String
                $state_provider: String
                $failover_timeout: Float
                $tarantool_params: FailoverStateProviderCfgInputTarantool
                $etcd2_params: FailoverStateProviderCfgInputEtcd2
                $fencing_enabled: Boolean
                $fencing_timeout: Float
                $fencing_pause: Float
            ) {
                cluster {
                    failover_params(
                        mode: $mode
                        state_provider: $state_provider
                        failover_timeout: $failover_timeout
                        tarantool_params: $tarantool_params
                        etcd2_params: $etcd2_params
                        fencing_enabled: $fencing_enabled
                        fencing_timeout: $fencing_timeout
                        fencing_pause: $fencing_pause
                    ) {
                        mode
                        state_provider
                        failover_timeout
                        tarantool_params {uri password}
                        etcd2_params {
                            prefix
                            lock_delay
                            endpoints
                            username
                            password
                        }
                        fencing_enabled
                        fencing_timeout
                        fencing_pause
                    }
                }
            }
        ]],
        variables = vars,
        raise = false,
    })
    if response.errors then
        error(response.errors[1].message, 2)
    end
    return response.data.cluster.failover_params
end

local function check_active_master(expected_uuid)
    -- Make sure active master uuid equals to the given uuid
    local response = cluster.main_server:eval([[
        return require('vshard').router.callrw(1, 'get_uuid')
    ]])
    t.assert_equals(response, expected_uuid)
end

g.test_api_master = function()
    set_master(replicaset_uuid, storage_2_uuid)
    t.assert_equals(get_master(replicaset_uuid), {storage_2_uuid, storage_2_uuid})
    set_master(replicaset_uuid, storage_1_uuid)
    t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_1_uuid})

    local invalid_uuid = helpers.uuid('b', 'b', 4)
    t.assert_error_msg_contains(
        string.format("replicasets[%s] leader %q doesn't exist", replicaset_uuid, invalid_uuid),
        function() set_master(replicaset_uuid, invalid_uuid) end
    )

    local response = cluster.main_server:graphql({query = [[
        {
            replicasets {
                uuid
                servers { uuid priority }
            }
        }
    ]]})
    t.assert_items_equals(response.data.replicasets, {
        {
            uuid = helpers.uuid('a'),
            servers = {{uuid = helpers.uuid('a', 'a', 1), priority = 1}},
        },
        {
            uuid = replicaset_uuid,
            servers = {
                {uuid = storage_1_uuid, priority = 1},
                {uuid = storage_2_uuid, priority = 2},
                {uuid = storage_3_uuid, priority = 3},
            }
        },
    })
end

g.test_api_failover = function()
    local function _call(name, ...)
        return cluster.main_server:call(
            'package.loaded.cartridge.' .. name, {...}
        )
    end

    -- Deprecated API tests
    -----------------------

    -- Set with deprecated GraphQL API
    t.assert_equals(set_failover(false), false)
    t.assert_equals(get_failover(), false)
    t.assert_covers(get_failover_params(), {mode = 'disabled'})
    t.assert_equals(_call('admin_get_failover'), false)
    t.assert_covers(_call('failover_get_params'), {mode = 'disabled'})

    -- Set with deprecated GraphQL API
    t.assert_equals(set_failover(true), true)
    t.assert_equals(get_failover(), true)
    t.assert_covers(get_failover_params(), {mode = 'eventual'})
    t.assert_equals(_call('admin_get_failover'), true)
    t.assert_covers(_call('failover_get_params'), {mode = 'eventual'})

    -- Set with deprecated Lua API
    t.assert_equals(_call('admin_disable_failover'), false)
    t.assert_equals(_call('admin_get_failover'), false)
    t.assert_covers(_call('failover_get_params'), {mode = 'disabled'})
    t.assert_equals(get_failover(), false)
    t.assert_covers(get_failover_params(), {mode = 'disabled'})

    -- Set with deprecated Lua API
    t.assert_equals(_call('admin_enable_failover'), true)
    t.assert_equals(_call('admin_get_failover'), true)
    t.assert_covers(_call('failover_get_params'), {mode = 'eventual'})
    t.assert_equals(get_failover(), true)
    t.assert_covers(get_failover_params(), {mode = 'eventual'})

    -- New failover API tests
    -------------------------

    -- Set with new GraphQL API
    t.assert_covers(set_failover_params({mode = 'disabled'}), {mode = 'disabled'})
    t.assert_covers(get_failover_params(), {mode = 'disabled'})
    t.assert_equals(get_failover(), false)
    t.assert_equals(_call('admin_get_failover'), false)
    t.assert_covers(_call('failover_get_params'), {mode = 'disabled'})

    -- Set with new GraphQL API
    t.assert_covers(set_failover_params({mode = 'eventual'}), {mode = 'eventual'})
    t.assert_covers(get_failover_params(), {mode = 'eventual'})
    t.assert_equals(get_failover(), true)
    t.assert_equals(_call('admin_get_failover'), true)
    t.assert_covers(_call('failover_get_params'), {mode = 'eventual'})

    t.assert_covers(set_failover_params(
        {failover_timeout = 0}),
        {failover_timeout = 0}
    )
    t.assert_covers(get_failover_params(), {failover_timeout = 0})
    t.assert_equals(
        cluster.main_server:eval([[
            return require('membership.options').SUSPECT_TIMEOUT_SECONDS
        ]]), 0
    )

    t.assert_covers(set_failover_params(
        {fencing_enabled = false}),
        {fencing_enabled = false}
    )
    t.assert_covers(get_failover_params(), {fencing_enabled = false})

    t.assert_covers(set_failover_params(
        {fencing_pause = 2}),
        {fencing_pause = 2}
    )
    t.assert_covers(get_failover_params(), {fencing_pause = 2})

    t.assert_covers(set_failover_params(
        {fencing_timeout = 4}),
        {fencing_timeout = 4}
    )
    t.assert_covers(get_failover_params(), {fencing_timeout = 4})

    -- Set with new GraphQL API
    t.assert_error_msg_equals(
        'topology_new.failover missing state_provider for mode "stateful"',
        set_failover_params, {mode = 'stateful'}
    )
    t.assert_error_msg_equals(
        'topology_new.failover.tarantool_params.uri: Invalid URI "!@#$"',
        set_failover_params, {tarantool_params = {uri = '!@#$', password = 'xxx'}}
    )
    t.assert_error_msg_contains(
        'Variable "tarantool_params.password" expected to be non-null',
        set_failover_params, {tarantool_params = {uri = 'localhost:9'}}
    )
    t.assert_error_msg_contains(
        'topology_new.failover.etcd2_params.endpoints[1]: Invalid URI "%^&*"',
        set_failover_params, {etcd2_params = {endpoints = {'%^&*'}}}
    )

    local tarantool_defaults = {
        uri = 'tcp://localhost:4401',
        password = '******',
    }

    local etcd2_params = {
        prefix = '/',
        lock_delay = 10,
        endpoints = {'goo.gl:9'},
        username = '',
        password = ''
    }

    local etcd2_params_masked = {
        prefix = '/',
        lock_delay = 10,
        endpoints = {'goo.gl:9'},
        username = '',
        password = '******',
    }

    t.assert_equals(
        set_failover_params({
            etcd2_params = {lock_delay = 36.6, prefix = 'kv'},
        }), {
            mode = 'eventual',
            failover_timeout = 0,
            tarantool_params = tarantool_defaults,
            etcd2_params = {
                prefix = 'kv',
                lock_delay = 36.6,
                username = '',
                password = '******',
                endpoints = {
                    'http://127.0.0.1:4001',
                    'http://127.0.0.1:2379',
                },
            },
            fencing_enabled = false,
            fencing_timeout = 4,
            fencing_pause = 2,
        }
    )
    t.assert_equals(
        set_failover_params({
            etcd2_params = {endpoints = {'goo.gl:9'}},
        }), {
            mode = 'eventual',
            failover_timeout = 0,
            tarantool_params = tarantool_defaults,
            etcd2_params = etcd2_params_masked,
            fencing_enabled = false,
            fencing_timeout = 4,
            fencing_pause = 2,
        }
    )

    t.assert_equals(
        get_failover_params(),
        {
            mode = 'eventual',
            failover_timeout = 0,
            tarantool_params = tarantool_defaults,
            etcd2_params = etcd2_params_masked,
            fencing_enabled = false,
            fencing_timeout = 4,
            fencing_pause = 2,
            leader_autoreturn = false,
            autoreturn_delay = 300,
            check_cookie_hash = true,
        }
    )

    local tarantool_params = {uri = 'stateboard.com:8', password = 'xxx'}
    local tarantool_params_masked = {uri = 'stateboard.com:8', password = '******'}
    t.assert_equals(
        set_failover_params({tarantool_params = tarantool_params}),
        {
            mode = 'eventual',
            failover_timeout = 0,
            etcd2_params = etcd2_params_masked,
            tarantool_params = tarantool_params_masked,
            fencing_enabled = false,
            fencing_timeout = 4,
            fencing_pause = 2,
        }
    )
    t.assert_equals(
        set_failover_params({mode = 'stateful', state_provider = 'tarantool'}),
        {
            mode = 'stateful',
            state_provider = 'tarantool',
            failover_timeout = 0,
            etcd2_params = etcd2_params_masked,
            tarantool_params = tarantool_params_masked,
            fencing_enabled = false,
            fencing_timeout = 4,
            fencing_pause = 2,
        }
    )

    t.assert_equals(
        get_failover_params(),
        {
            mode = 'stateful',
            state_provider = 'tarantool',
            failover_timeout = 0,
            etcd2_params = etcd2_params_masked,
            tarantool_params = tarantool_params_masked,
            fencing_enabled = false,
            fencing_timeout = 4,
            fencing_pause = 2,
            leader_autoreturn = false,
            autoreturn_delay = 300,
            check_cookie_hash = true,
        }
    )
    t.assert_equals(
        _call('failover_get_params'),
        {
            mode = 'stateful',
            state_provider = 'tarantool',
            failover_timeout = 0,
            etcd2_params = etcd2_params,
            tarantool_params = tarantool_params,
            fencing_enabled = false,
            fencing_timeout = 4,
            fencing_pause = 2,
            leader_autoreturn = false,
            autoreturn_delay = 300,
            check_cookie_hash = true,
        }
    )
    t.assert_equals(_call('admin_get_failover'), true)

    -- Set with new Lua API
    t.assert_equals(_call('failover_set_params', {
        mode = 'disabled',
        failover_timeout = 3,
        etcd2_params = {},
    }), true)

    local etcd2_defaults = {
        prefix = '/',
        lock_delay = 10,
        username = '',
        password = '',
        endpoints = {
            'http://127.0.0.1:4001',
            'http://127.0.0.1:2379',
        },
    }

    local etcd2_defaults_masked = {
        prefix = '/',
        lock_delay = 10,
        username = '',
        password = '******',
        endpoints = {
            'http://127.0.0.1:4001',
            'http://127.0.0.1:2379',
        },
    }

    t.assert_equals(
        get_failover_params(),
        {
            mode = 'disabled',
            state_provider = 'tarantool',
            failover_timeout = 3,
            etcd2_params = etcd2_defaults_masked,
            tarantool_params = tarantool_params_masked,
            fencing_enabled = false,
            fencing_timeout = 4,
            fencing_pause = 2,
            leader_autoreturn = false,
            autoreturn_delay = 300,
            check_cookie_hash = true,
        }
    )
    t.assert_equals(
        _call('failover_get_params'),
        {
            mode = 'disabled',
            state_provider = 'tarantool',
            failover_timeout = 3,
            etcd2_params = etcd2_defaults,
            tarantool_params = tarantool_params,
            fencing_enabled = false,
            fencing_timeout = 4,
            fencing_pause = 2,
            leader_autoreturn = false,
            autoreturn_delay = 300,
            check_cookie_hash = true,
        }
    )

    t.assert_error_msg_contains('failover unknown mode "unknown"', set_failover_params, {mode = 'unknown'})
    t.assert_equals(cluster.main_server:exec(function()
        return require('cartridge.confapplier').get_state()
    end), 'RolesConfigured')
end

g.test_switchover = function()
    set_failover(false)

    -- Switch to server1
    set_master(replicaset_uuid, storage_1_uuid)
    cluster:retrying({}, check_active_master, storage_1_uuid)
    t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_1_uuid})

    -- Switch to server2
    set_master(replicaset_uuid, storage_2_uuid)
    cluster:retrying({}, check_active_master, storage_2_uuid)
    t.assert_equals(get_master(replicaset_uuid), {storage_2_uuid, storage_2_uuid})
end

g.test_sigkill = function()
    set_failover(true)

    -- Switch to server1
    set_master(replicaset_uuid, storage_1_uuid)
    cluster:retrying({}, check_active_master, storage_1_uuid)
    t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_1_uuid})

    local server = cluster:server('storage-1')
    -- Send SIGKILL to server1
    server:stop()
    cluster:retrying({}, check_active_master, storage_2_uuid)
    t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_2_uuid})

    -- Restart server1
    server:start()
    cluster:retrying({}, function() server:connect_net_box() end)
    cluster:retrying({}, check_active_master, storage_1_uuid)
    t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_1_uuid})
end

g.test_all_rw_failover = function()
    cluster:retrying({}, function() set_failover(true) end)
    set_all_rw(replicaset_uuid, true)

    check_all_box_rw()

    -- Switch to server1
    set_master(replicaset_uuid, storage_1_uuid)
    cluster:retrying({}, check_active_master, storage_1_uuid)
    t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_1_uuid})

    local server = cluster:server('storage-1')
    -- Send SIGKILL to server1
    server:stop()
    cluster:retrying({}, check_active_master, storage_2_uuid)
    t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_2_uuid})

    check_all_box_rw()

    -- Restart server1
    server:start()
    cluster:retrying({}, function() server:connect_net_box() end)
    cluster:retrying({}, check_active_master, storage_1_uuid)

    set_all_rw(replicaset_uuid, false)
end

g.test_sigstop = function()
    -- Here we use retrying due to this tarantool bug
    -- See: https://github.com/tarantool/tarantool/issues/4668
    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(cluster.main_server), {})
        t.assert_equals(helpers.get_suggestions(cluster.main_server), {})
    end)

    set_failover(true)

    -- Switch to server1
    set_master(replicaset_uuid, storage_1_uuid)
    cluster:retrying({}, check_active_master, storage_1_uuid)
    t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_1_uuid})

    -- Send SIGSTOP to server1
    cluster:server('storage-1').process:kill('STOP')
    cluster:retrying({timeout = 60, delay = 2}, check_active_master, storage_2_uuid)
    t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_2_uuid})

    local response = cluster.main_server:graphql({query = [[
        {
            servers {
                uri
                statistics { vshard_buckets_count }
            }
        }
    ]]})

    t.assert_items_equals(response.data.servers, {
        {uri = cluster:server('storage-1').advertise_uri, statistics = box.NULL},
        {uri = cluster:server('storage-2').advertise_uri, statistics = {vshard_buckets_count = 3000}},
        {uri = cluster:server('storage-3').advertise_uri, statistics = {vshard_buckets_count = 3000}},
        {uri = cluster:server('router-1').advertise_uri, statistics={vshard_buckets_count = box.NULL}}
    })

    t.assert_covers(fun.map(function(x) x.message = nil; return x end,
        helpers.list_cluster_issues(cluster.main_server)):totable(),
    {{
        level = 'critical',
        replicaset_uuid = replicaset_uuid,
        instance_uuid = storage_2_uuid,
        topic = 'replication',
    }, {
        level = 'critical',
        replicaset_uuid = replicaset_uuid,
        instance_uuid = storage_3_uuid,
        topic = 'replication',
    }})

    t.assert_equals(helpers.get_suggestions(cluster.main_server).restart_replication, box.NULL)

    -- Send SIGCONT to server1
    cluster:server('storage-1').process:kill('CONT') -- SIGCONT
    cluster:wait_until_healthy()
    cluster:retrying({}, check_active_master, storage_1_uuid)
    t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_1_uuid})

    t.helpers.retrying({}, function()
        response = cluster.main_server:graphql({query = [[
            {
                servers {
                    uri
                    statistics { vshard_buckets_count }
                }
            }
        ]]})

        t.assert_items_equals(response.data.servers, {
            {uri = cluster:server('storage-1').advertise_uri, statistics = {vshard_buckets_count = 3000}},
            {uri = cluster:server('storage-2').advertise_uri, statistics = {vshard_buckets_count = 3000}},
            {uri = cluster:server('storage-3').advertise_uri, statistics = {vshard_buckets_count = 3000}},
            {uri = cluster:server('router-1').advertise_uri, statistics={vshard_buckets_count = box.NULL}}
        })
    end)

    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(cluster.main_server), {})
        t.assert_equals(helpers.get_suggestions(cluster.main_server), {})
    end)
end

g.after_test('test_sigstop', function()
    cluster:server('storage-1').process:kill('CONT') -- SIGCONT
    cluster:wait_until_healthy()
end)


function g.test_sync_spaces_is_prohibited()
    t.skip_if(not helpers.tarantool_version_ge('2.6.1'))
    local master = cluster:server('storage-1')
    master:exec(function()
        box.schema.space.create('test', {if_not_exists = true, is_sync=true})
    end)

    master:restart()

    helpers.retrying({}, function()
        t.assert_items_equals(helpers.list_cluster_issues(master), {
            {
                level = 'warning',
                topic = 'failover',
                message = 'Having sync spaces may cause failover errors. ' ..
                        'Consider to change failover type to stateful and enable synchro_mode or use ' ..
                        'raft failover mode. Sync spaces: test',
                instance_uuid = master.instance_uuid,
                replicaset_uuid = master.replicaset_uuid,
            },
        })
    end)
end

g.after_test('test_sync_spaces_is_prohibited', function()
    cluster:server('storage-1'):exec(function()
        box.space.test:drop()
    end)
    cluster:server('storage-1'):restart()
end)


local function failover_pause()
    cluster.main_server:graphql({
        query = [[
            mutation { cluster { failover_pause } }
        ]],
    })
end

local function failover_resume()
    cluster.main_server:graphql({
        query = [[
            mutation { cluster { failover_resume } }
        ]],
    })
end

g.test_failover_pause = function()
    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(cluster.main_server), {})
        t.assert_equals(helpers.get_suggestions(cluster.main_server), {})
    end)

    set_failover(true)
    set_master(replicaset_uuid, storage_1_uuid)
    cluster:wait_until_healthy()

    failover_pause()

    -- after pausing failover doesn't trigger, so
    -- if we kill master, nobody can become a master
    cluster:server('storage-1'):stop()

    cluster:server('storage-2'):exec(function()
        assert(box.info.ro)
    end)
    cluster:server('storage-3'):exec(function()
        assert(box.info.ro)
    end)

    cluster:server('storage-1'):start()
    cluster:wait_until_healthy()

    failover_resume()

    cluster:server('storage-1'):stop()

    -- after failover resuming, if we kill master,
    -- next storage in failover_priority will become a new master
    helpers.retrying({}, function()
        cluster:server('storage-2'):exec(function()
            assert(box.info.ro == false)
        end)
        cluster:server('storage-3'):exec(function()
            assert(box.info.ro)
        end)
    end)

    cluster:server('storage-1'):start()
end
