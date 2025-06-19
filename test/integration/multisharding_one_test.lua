local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        use_vshard = true,
        replicasets = {
            {
                alias = 'router',
                uuid = helpers.uuid('a'),
                roles = {'vshard-storage', 'vshard-router'},
                servers = {{
                    http_port = 8081,
                    advertise_port = 13301,
                    instance_uuid = helpers.uuid('a', 'a', 1)
                }},
            }
        },
    })

    g.server = helpers.Server:new({
        alias = 'spare',
        workdir = fio.pathjoin(g.cluster.datadir, 'spare'),
        command = helpers.entrypoint('srv_basic'),
        replicaset_uuid = helpers.uuid('d'),
        instance_uuid = helpers.uuid('d', 'd', 1),
        http_port = 8082,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13302,
    })

    g.cluster:start()

    g.server:start()
    t.helpers.retrying({}, function()
        g.server:graphql({query = '{ servers { uri } }'})
    end)
end

g.after_all = function()
    g.cluster:stop()
    g.server:stop()
    fio.rmtree(g.cluster.datadir)
end

local function get_vshard_groups(cluster)
    local res = cluster.main_server:graphql({query = [[{
            cluster {
                vshard_groups {
                    name
                    bucket_count
                    bootstrapped
                    rebalancer_max_receiving
                    rebalancer_max_sending
                    collect_lua_garbage
                    connection_fetch_schema
                    sync_timeout
                    collect_bucket_garbage_interval
                    rebalancer_disbalance_threshold
                }
            }
        }]]
    })
    return res.data.cluster.vshard_groups
end

local function edit_vshard_group(cluster, kv_args)
    local res = cluster.main_server:graphql({query = [[
        mutation(
            $rebalancer_max_receiving: Int
            $rebalancer_max_sending: Int
            $group: String!
            $collect_lua_garbage: Boolean
            $connection_fetch_schema: Boolean
            $sync_timeout: Float
            $collect_bucket_garbage_interval: Float,
            $rebalancer_disbalance_threshold: Float
        ) {
            cluster {
                edit_vshard_options(
                    name: $group
                    rebalancer_max_receiving: $rebalancer_max_receiving
                    rebalancer_max_sending: $rebalancer_max_sending
                    collect_lua_garbage: $collect_lua_garbage
                    connection_fetch_schema: $connection_fetch_schema
                    sync_timeout: $sync_timeout
                    collect_bucket_garbage_interval: $collect_bucket_garbage_interval
                    rebalancer_disbalance_threshold: $rebalancer_disbalance_threshold
                ) {
                    name
                    bucket_count
                    bootstrapped
                    rebalancer_max_receiving
                    rebalancer_max_sending
                    collect_lua_garbage
                    connection_fetch_schema
                    sync_timeout
                    collect_bucket_garbage_interval
                    rebalancer_disbalance_threshold
                }
            }
        }]],
        variables = kv_args
    })

    return res
end

function g.test_api()
    local request = {query = [[{
        cluster {
            self { uuid }
            can_bootstrap_vshard
            vshard_bucket_count
            vshard_known_groups
            vshard_groups {
                name
                bucket_count
                bootstrapped
                rebalancer_max_receiving
                rebalancer_max_sending
                collect_lua_garbage
                connection_fetch_schema
                sync_timeout
                collect_bucket_garbage_interval
                rebalancer_disbalance_threshold
                sched_ref_quota
                sched_move_quota
            }
        }}]]
    }

    local res = g.cluster.main_server:graphql(request)
    local data = res['data']['cluster']
    t.assert_equals(data['self']['uuid'], g.cluster.main_server.instance_uuid)
    t.assert_equals(data['can_bootstrap_vshard'], false)
    t.assert_equals(data['vshard_bucket_count'], 3000)
    t.assert_equals(data['vshard_known_groups'], {'default'})
    t.assert_equals(#data['vshard_groups'], 1)
    t.assert_equals(data['vshard_groups'][1]['name'], 'default')
    t.assert_equals(data['vshard_groups'][1]['bucket_count'], 3000)
    t.assert_equals(data['vshard_groups'][1]['bootstrapped'], true)
    t.assert_equals(data['vshard_groups'][1]['sched_ref_quota'], 300)
    t.assert_equals(data['vshard_groups'][1]['sched_move_quota'], 1)
    t.assert_equals(data['vshard_groups'][1]['connection_fetch_schema'], true)


    local res = g.server:graphql(request)
    t.assert_equals(res['data']['cluster']['self']['uuid'], box.NULL)
    t.assert_equals(res['data']['cluster']['can_bootstrap_vshard'], false)
    t.assert_equals(res['data']['cluster']['vshard_bucket_count'], 3000)
    t.assert_equals(res['data']['cluster']['vshard_known_groups'], {'default'})
    t.assert_equals(res['data']['cluster']['vshard_groups'], {
        {
            ['collect_bucket_garbage_interval'] = box.NULL,
            ['collect_lua_garbage'] = false,
            ['connection_fetch_schema'] = true,
            ['rebalancer_disbalance_threshold'] = 1,
            ['rebalancer_max_receiving'] = 100,
            ['rebalancer_max_sending'] = 1,
            ['sync_timeout'] = 1,
            ['name'] = 'default',
            ['bucket_count'] = 3000,
            ['bootstrapped'] = false,
            sched_ref_quota = 300,
            sched_move_quota = 1,
        }
    })
end


function g.test_router_role()
    local res = g.cluster.main_server:eval([[
        local vshard = require('vshard')
        local cartridge = require('cartridge')
        local router_role = assert(cartridge.service_get('vshard-router'))

        assert(router_role.get() == vshard.router.static, "Default router is initialized")
        return {
            null = router_role.get():call(1, 'read', 'get_uuid'),
            default = router_role.get('default'):call(1, 'read', 'get_uuid'),
            static = vshard.router.call(1, 'read', 'get_uuid'),
        }
    ]])

    t.assert_equals(res, {
        ['null'] = 'aaaaaaaa-aaaa-0000-0000-000000000001',
        ['static'] = 'aaaaaaaa-aaaa-0000-0000-000000000001',
        ['default'] = 'aaaaaaaa-aaaa-0000-0000-000000000001'
    })
end

function g.test_set_vshard_options_positive()
    local res = edit_vshard_group(g.cluster, {
        group = "default",
        rebalancer_max_receiving = 42,
        rebalancer_max_sending = 1,
        collect_lua_garbage = true,
        sync_timeout = 24,
        rebalancer_disbalance_threshold = 14
    })
    t.assert_equals(res['data']['cluster']['edit_vshard_options'], {
        ['collect_bucket_garbage_interval'] = box.NULL,
        ['collect_lua_garbage'] = false,
        ['rebalancer_disbalance_threshold'] = 14,
        ['rebalancer_max_receiving'] = 42,
        ['rebalancer_max_sending'] = 1,
        ['sync_timeout'] = 24,
        ['name'] = 'default',
        ['bucket_count'] = 3000,
        ['bootstrapped'] = true,
        ['connection_fetch_schema'] = true,
    })

    local res = edit_vshard_group(g.cluster, {
        group = "default",
        rebalancer_max_receiving = nil,
        rebalancer_max_sending = nil,
        sync_timeout = 25,
        connection_fetch_schema = false,
    })
    t.assert_equals(res['data']['cluster']['edit_vshard_options'], {
        ['collect_bucket_garbage_interval'] = box.NULL,
        ['collect_lua_garbage'] = false,
        ['rebalancer_disbalance_threshold'] = 14,
        ['rebalancer_max_receiving'] = 42,
        ['rebalancer_max_sending'] = 1,
        ['sync_timeout'] = 25,
        ['name'] = 'default',
        ['bucket_count'] = 3000,
        ['bootstrapped'] = true,
        ['connection_fetch_schema'] = false,
    })

    local res = get_vshard_groups(g.cluster)
    t.assert_equals(res, {
        {
            ['collect_bucket_garbage_interval'] = box.NULL,
            ['collect_lua_garbage'] = false,
            ['rebalancer_disbalance_threshold'] = 14,
            ['rebalancer_max_receiving'] = 42,
            ['rebalancer_max_sending'] = 1,
            ['sync_timeout'] = 25,
            ['name'] = 'default',
            ['bucket_count'] = 3000,
            ['bootstrapped'] = true,
            ['connection_fetch_schema'] = false,
        }
    })
end


function g.test_set_vshard_options_negative()
    t.assert_error_msg_contains(
        [[vshard-group "undef" doesn't exist]],
        edit_vshard_group, g.cluster, {group = "undef", rebalancer_max_receiving = 42}
    )

    t.assert_error_msg_contains(
        [[vshard_groups["default"].rebalancer_max_receiving must be positive]],
        edit_vshard_group, g.cluster, {group = "default", rebalancer_max_receiving = -42}
    )

    t.assert_error_msg_contains(
        [[vshard_groups["default"].rebalancer_max_sending must be positive]],
        edit_vshard_group, g.cluster, {group = "default", rebalancer_max_sending = -42}
    )

    t.assert_error_msg_contains(
        [[vshard_groups["default"].sync_timeout must be non-negative]],
        edit_vshard_group, g.cluster, {group = "default", sync_timeout = -24}
    )

    t.assert_error_msg_contains(
        [[vshard_groups["default"].collect_bucket_garbage_interval must be positive]],
        edit_vshard_group, g.cluster, {group = "default", collect_bucket_garbage_interval = -42.24}
    )

    t.assert_error_msg_contains(
        [[vshard_groups["default"].rebalancer_disbalance_threshold must be non-negative]],
        edit_vshard_group, g.cluster, {group = "default", rebalancer_disbalance_threshold = -14}
    )
end
