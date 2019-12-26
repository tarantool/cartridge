local fio = require('fio')
local t = require('luatest')
local g = t.group()

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    local server_command = fio.pathjoin(test_helper.root,
        'test', 'integration', 'srv_multisharding.lua'
    )

    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = server_command,
        use_vshard = true,
        replicasets = {
            {
                alias = 'storage-hot',
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                vshard_group = 'hot',
                servers = {{
                    http_port = 8082,
                    advertise_port = 13302,
                    instance_uuid = helpers.uuid('b', 'b', 2)
                }},
            },
            {
                alias = 'storage-cold',
                uuid = helpers.uuid('c'),
                roles = {'vshard-storage'},
                vshard_group = 'cold',
                servers = {{
                    http_port = 8084,
                    advertise_port = 13304,
                    instance_uuid = helpers.uuid('c', 'c', 2)
                }},
            },
            {
                alias = 'router',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
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
        command = server_command,
        replicaset_uuid = helpers.uuid('d'),
        instance_uuid = helpers.uuid('d', 'd', 1),
        http_port = 8085,
        vshard_group = nil,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13305,
    })

    g.cluster:start()

    g.server:start()
    t.helpers.retrying({}, function()
        g.server:graphql({query = '{}'})
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
                    collect_lua_garbage
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
            $group: String!
            $collect_lua_garbage: Boolean
            $sync_timeout: Float
            $collect_bucket_garbage_interval: Float,
            $rebalancer_disbalance_threshold: Float
        ) {
            cluster {
                edit_vshard_options(
                    name: $group
                    rebalancer_max_receiving: $rebalancer_max_receiving
                    collect_lua_garbage: $collect_lua_garbage
                    sync_timeout: $sync_timeout
                    collect_bucket_garbage_interval: $collect_bucket_garbage_interval
                    rebalancer_disbalance_threshold: $rebalancer_disbalance_threshold
                ) {
                    name
                    bucket_count
                    bootstrapped
                    rebalancer_max_receiving
                    collect_lua_garbage
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
                collect_lua_garbage
                sync_timeout
                collect_bucket_garbage_interval
                rebalancer_disbalance_threshold
            }
        }
    }]]}

    local res = g.cluster:server('router-1'):graphql(request)
    local data = res['data']['cluster']
    t.assert_equals(data['self']['uuid'], g.cluster:server('router-1').instance_uuid)
    t.assert_equals(data['can_bootstrap_vshard'], false)
    t.assert_equals(data['vshard_bucket_count'], 32000)
    t.assert_equals(data['vshard_known_groups'], {'cold', 'hot'})
    t.assert_equals(#data['vshard_groups'], 2)

    local expected_map = {
        ['name'] = 'cold',
        ['bucket_count'] = 2000,
        ['bootstrapped'] = true,
    }
    t.assert_covers(data['vshard_groups'][1], expected_map)

    local expected_map = {
        ['name'] = 'hot',
        ['bucket_count'] = 30000,
        ['bootstrapped'] = true,
    }
    t.assert_covers(data['vshard_groups'][2], expected_map)


    local res = g.server:graphql(request)
    t.assert_equals(res['data']['cluster']['self']['uuid'], box.NULL)
    t.assert_equals(res['data']['cluster']['can_bootstrap_vshard'], false)
    t.assert_equals(res['data']['cluster']['vshard_bucket_count'], 32000)
    t.assert_equals(res['data']['cluster']['vshard_known_groups'], {'cold', 'hot'})
    t.assert_equals(res['data']['cluster']['vshard_groups'], {
        {
            ['collect_bucket_garbage_interval'] = 0.5,
            ['collect_lua_garbage'] = false,
            ['rebalancer_disbalance_threshold'] = 1,
            ['rebalancer_max_receiving'] = 100,
            ['sync_timeout'] = 1,
            ['name'] = 'cold',
            ['bucket_count'] = 2000,
            ['bootstrapped'] = false,
        }, {
            ['collect_bucket_garbage_interval'] = 0.5,
            ['collect_lua_garbage'] = false,
            ['rebalancer_disbalance_threshold'] = 1,
            ['rebalancer_max_receiving'] = 100,
            ['sync_timeout'] = 1,
            ['name'] = 'hot',
            ['bucket_count'] = 30000,
            ['bootstrapped'] = false,
        }
    })
end


function g.test_mutations()
    local ruuid_cold = g.cluster:server('storage-cold-1').replicaset_uuid

    local change_group = function()
        g.cluster:server('router-1'):graphql({query = [[
            mutation($uuid: String!, $vshard_group: String!) {
                edit_replicaset(
                    uuid: $uuid
                    vshard_group: $vshard_group
                )
            }]],
            variables = {
                uuid = ruuid_cold, vshard_group = 'hot'
            }
        })
    end

    t.assert_error_msg_contains(
        string.format([[replicasets[%s].vshard_group can't be modified]], ruuid_cold),
        change_group
    )

    local join_server = function(server, group)
        g.cluster:server('router-1'):graphql({query = [[
            mutation(
                $uri: String!, $instance_uuid: String!,
                $replicaset_uuid: String!, $group: String
            ) {
                join_server(
                    uri: $uri
                    instance_uuid: $instance_uuid
                    replicaset_uuid: $replicaset_uuid
                    roles: ["vshard-storage"]
                    vshard_group: $group
                )
            }]],
            variables = {
                uri = server.advertise_uri,
                instance_uuid = server.instance_uuid,
                replicaset_uuid = server.replicaset_uuid,
                group = group
            }
        })
    end

    t.assert_error_msg_contains(
        string.format([[replicasets[%s].vshard_group "default" doesn't exist]], g.server.replicaset_uuid),
        join_server, g.server
    )

    t.assert_error_msg_contains(
        string.format([[replicasets[%s].vshard_group "unknown" doesn't exist]], g.server.replicaset_uuid),
        join_server, g.server, 'unknown'
    )
end


function g.test_router_role()
    local res = g.cluster:server('router-1').net_box:eval([[
        local cartridge = require('cartridge')
        local router_role = assert(cartridge.service_get('vshard-router'))

        assert(router_role.get() == nil, "Default router isn't initialized")

        return {
            hot = router_role.get('hot'):call(1, 'read', 'get_uuid'),
            cold = router_role.get('cold'):call(1, 'read', 'get_uuid'),
        }
    ]])

    t.assert_equals(res, {
        ['hot'] = 'bbbbbbbb-bbbb-0000-0000-000000000002',
        ['cold'] = 'cccccccc-cccc-0000-0000-000000000002'
    })
end


function g.test_set_vshard_options_positive()
    local res = edit_vshard_group(g.cluster, {
        group = 'cold',
        rebalancer_max_receiving = 42
    })
    t.assert_equals(res['data']['cluster']['edit_vshard_options'], {
        ['collect_bucket_garbage_interval'] = 0.5,
        ['collect_lua_garbage'] = false,
        ['rebalancer_disbalance_threshold'] = 1,
        ['rebalancer_max_receiving'] = 42,
        ['sync_timeout'] = 1,
        ['name'] = 'cold',
        ['bucket_count'] = 2000,
        ['bootstrapped'] = true,
    })

    local res = edit_vshard_group(g.cluster, {
        group = 'hot',
        rebalancer_max_receiving = 44
    })
    t.assert_equals(res['data']['cluster']['edit_vshard_options'], {
        ['collect_bucket_garbage_interval'] = 0.5,
        ['collect_lua_garbage'] = false,
        ['rebalancer_disbalance_threshold'] = 1,
        ['rebalancer_max_receiving'] = 44,
        ['sync_timeout'] = 1,
        ['name'] = 'hot',
        ['bucket_count'] = 30000,
        ['bootstrapped'] = true,
    })

    local res = get_vshard_groups(g.cluster)
    t.assert_equals(res, {
        {
            ['collect_bucket_garbage_interval'] = 0.5,
            ['collect_lua_garbage'] = false,
            ['rebalancer_disbalance_threshold'] = 1,
            ['rebalancer_max_receiving'] = 42,
            ['sync_timeout'] = 1,
            ['name'] = 'cold',
            ['bucket_count'] = 2000,
            ['bootstrapped'] = true,
        },
        {
            ['collect_bucket_garbage_interval'] = 0.5,
            ['collect_lua_garbage'] = false,
            ['rebalancer_disbalance_threshold'] = 1,
            ['rebalancer_max_receiving'] = 44,
            ['sync_timeout'] = 1,
            ['name'] = 'hot',
            ['bucket_count'] = 30000,
            ['bootstrapped'] = true,
        }
    })
end
