local fio = require('fio')
local t = require('luatest')
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
        cookie = require('digest').urandom(6):hex(),
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
end

local function check_all_box_rw()
    for _, server in pairs(cluster.servers) do
        if server.net_box ~= nil then
            t.assert_equals(
                {[server.alias] = server.net_box:eval('return box.cfg.read_only')},
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
                tarantool_params {uri password}
            }}
        }
    ]]}).data.cluster.failover_params
end

local function set_failover_params(vars)
    local response = cluster.main_server:graphql({
        query = [[
            mutation(
                $mode: String!
                $state_provider: String!
                $tarantool_params: FailoverStateProviderCfgInputTarantool
            ) {
                cluster {
                    failover_params(
                        mode: $mode
                        state_provider: $state_provider
                        tarantool_params: $tarantool_params
                    ) {
                        mode
                        state_provider
                        tarantool_params {uri password}
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
    local response = cluster.main_server.net_box:eval([[
        return require('vshard').router.callrw(1, 'get_uuid')
    ]])
    t.assert_equals(response, expected_uuid)
end

local function list_issues(server)
    return server:graphql({query = [[{
        cluster {
            issues {
                level
                message
                replicaset_uuid
                instance_uuid
            }
        }
    }]]}).data.cluster.issues
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

    t.assert_error_msg_contains(
        string.format("Server %q is the leader and can't be expelled", storage_1_uuid),
        function()
            cluster.main_server:graphql({
                query = 'mutation($uuid: String!) { expel_server(uuid: $uuid) }',
                variables = {uuid = storage_1_uuid},
            })
        end
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
        return cluster.main_server.net_box:call(
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
    t.assert_equals(_call('failover_get_params'), {mode = 'disabled'})

    -- Set with deprecated GraphQL API
    t.assert_equals(set_failover(true), true)
    t.assert_equals(get_failover(), true)
    t.assert_covers(get_failover_params(), {mode = 'eventual'})
    t.assert_equals(_call('admin_get_failover'), true)
    t.assert_equals(_call('failover_get_params'), {mode = 'eventual'})

    -- Set with deprecated Lua API
    t.assert_equals(_call('admin_disable_failover'), false)
    t.assert_equals(_call('admin_get_failover'), false)
    t.assert_equals(_call('failover_get_params'), {mode = 'disabled'})
    t.assert_equals(get_failover(), false)
    t.assert_covers(get_failover_params(), {mode = 'disabled'})

    -- Set with deprecated Lua API
    t.assert_equals(_call('admin_enable_failover'), true)
    t.assert_equals(_call('admin_get_failover'), true)
    t.assert_equals(_call('failover_get_params'), {mode = 'eventual'})
    t.assert_equals(get_failover(), true)
    t.assert_covers(get_failover_params(), {mode = 'eventual'})

    -- New failover API tests
    -------------------------

    -- Set with new GraphQL API
    t.assert_covers(set_failover_params({mode = 'disabled'}), {mode = 'disabled'})
    t.assert_covers(get_failover_params(), {mode = 'disabled'})
    t.assert_equals(get_failover(), false)
    t.assert_equals(_call('admin_get_failover'), false)
    t.assert_equals(_call('failover_get_params'), {mode = 'disabled'})

    -- Set with new GraphQL API
    t.assert_covers(set_failover_params({mode = 'eventual'}), {mode = 'eventual'})
    t.assert_covers(get_failover_params(), {mode = 'eventual'})
    t.assert_equals(get_failover(), true)
    t.assert_equals(_call('admin_get_failover'), true)
    t.assert_equals(_call('failover_get_params'), {mode = 'eventual'})

    -- Set with new GraphQL API
    t.assert_error_msg_equals(
        'topology_new.failover missing state_provider for mode "stateful"',
        set_failover_params, {mode = 'stateful'}
    )
    t.assert_error_msg_equals(
        'topology_new.failover.tarantool_params.uri invalid URI "!@#$"',
        set_failover_params, {tarantool_params = {uri = '!@#$'}}
    )
    t.assert_error_msg_equals(
        'topology_new.failover.tarantool_params.password must be string, got nil',
        set_failover_params, {tarantool_params = {uri = 'localhost:9'}}
    )

    local tarantool_params = {uri = 'kingdom.com:8', password = 'xxx'}
    t.assert_equals(
        set_failover_params({tarantool_params = tarantool_params}),
        {
            mode = 'eventual',
            tarantool_params = tarantool_params,
        }
    )
    t.assert_equals(
        set_failover_params({mode = 'stateful', state_provider = 'tarantool'}),
        {
            mode = 'stateful',
            state_provider = 'tarantool',
            tarantool_params = tarantool_params,
        }
    )

    t.assert_equals(
        get_failover_params(),
        {
            mode = 'stateful',
            state_provider = 'tarantool',
            tarantool_params = tarantool_params,
        }
    )
    t.assert_equals(
        _call('failover_get_params'),
        {
            mode = 'stateful',
            state_provider = 'tarantool',
            tarantool_params = tarantool_params,
        }
    )
    t.assert_equals(_call('admin_get_failover'), true)

    -- Set with new Lua API
    t.assert_equals(_call('failover_set_params', {mode = 'disabled'}), true)
    t.assert_equals(
        get_failover_params(),
        {
            mode = 'disabled',
            state_provider = 'tarantool',
            tarantool_params = tarantool_params,
        }
    )
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
    set_failover(true)
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
        t.assert_equals(list_issues(cluster.main_server), {})
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
                statistics { }
            }
        }
    ]]})

    t.assert_items_equals(response.data.servers, {
        {uri = cluster:server('storage-1').advertise_uri, statistics = box.NULL},
        {uri = cluster:server('storage-2').advertise_uri, statistics = {}},
        {uri = cluster:server('storage-3').advertise_uri, statistics = {}},
        {uri = cluster:server('router-1').advertise_uri, statistics={}}
    })

    t.assert_items_equals(list_issues(cluster.main_server), {{
        level = 'warning',
        replicaset_uuid = replicaset_uuid,
        instance_uuid = storage_2_uuid,
        message = "Replication from localhost:13302 to localhost:13303 isn't running",
    }, {
        level = 'warning',
        replicaset_uuid = replicaset_uuid,
        instance_uuid = storage_3_uuid,
        message = "Replication from localhost:13302 to localhost:13304 isn't running",
    }})

    -- Send SIGCONT to server1
    cluster:server('storage-1').process:kill('CONT') -- SIGCONT
    cluster:wait_until_healthy()
    cluster:retrying({}, check_active_master, storage_1_uuid)
    t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_1_uuid})

    response = cluster.main_server:graphql({query = [[
        {
            servers {
                uri
                statistics { }
            }
        }
    ]]})

    t.assert_items_equals(response.data.servers, {
        {uri = cluster:server('storage-1').advertise_uri, statistics = {}},
        {uri = cluster:server('storage-2').advertise_uri, statistics = {}},
        {uri = cluster:server('storage-3').advertise_uri, statistics = {}},
        {uri = cluster:server('router-1').advertise_uri, statistics={}}
    })

    t.helpers.retrying({}, function()
        t.assert_equals(list_issues(cluster.main_server), {})
    end)
end
