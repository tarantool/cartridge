local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local log = require('log')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = 'test-cluster-cookie',

        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = {
                    {
                        alias = 'router',
                        instance_uuid = helpers.uuid('a', 'a', 1),
                        advertise_port = 13301,
                        http_port = 8081
                    }
                }
            }, {
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                all_rw = true,
                servers = {
                    {
                        alias = 'storage',
                        instance_uuid = helpers.uuid('b', 'b', 1),
                        advertise_port = 13302,
                        http_port = 8082
                    }, {
                        alias = 'storage-2',
                        instance_uuid = helpers.uuid('b', 'b', 2),
                        advertise_port = 13304,
                        http_port = 8084
                    }
                }
            }, {
                uuid = helpers.uuid('c'),
                roles = {},
                servers = {
                    {
                        alias = 'expelled',
                        instance_uuid = helpers.uuid('c', 'c', 1),
                        advertise_port = 13309,
                        http_port = 8089
                    }
                }
            }
        }
    })

    g.cluster:start()
    g.cluster:server('expelled'):stop()
    g.cluster:server('router'):graphql({
        query = [[
            mutation($uuid: String!) {
                expel_server(uuid: $uuid)
            }
        ]],
        variables = {
            uuid = g.cluster:server('expelled').instance_uuid
        }
    })

    g.server = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'spare',
        command = helpers.entrypoint('srv_basic'),
        replicaset_uuid = helpers.uuid('b'),
        instance_uuid = helpers.uuid('b', 'b', 1),
        http_port = 8083,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13303,
        env = {
            TARANTOOL_WEBUI_BLACKLIST = '/cluster/code:/cluster/schema',
        }
    })

    g.server:start()
    t.helpers.retrying({timeout = 5}, function()
        g.server:graphql({query = '{}'})
        g.cluster.main_server:graphql({
            query = 'mutation($uri: String!) { probe_server(uri:$uri) }',
            variables = {uri = g.server.advertise_uri},
        })
    end)
end

g.after_all = function()
    g.cluster:stop()
    g.server:stop()
    fio.rmtree(g.cluster.datadir)
    fio.rmtree(g.server.workdir)
end

local function fields_from_map(map, field_key)
    local data_arr = {}
    for _, v in pairs(map['fields']) do
        table.insert(data_arr, v[field_key])
    end
    return data_arr
end

function g.test_self()
    local router_server = g.cluster:server('router')

    local resp = router_server:graphql({
        query = [[
            {
                cluster {
                    self {
                        uri
                        uuid
                        alias
                    }
                    can_bootstrap_vshard
                    vshard_bucket_count
                    vshard_known_groups
                }
            }
        ]]
    })

    t.assert_equals(resp['data']['cluster']['self'], {
        uri = string.format( "localhost:%d", router_server.net_box_port),
        uuid = router_server.instance_uuid,
        alias = router_server.alias,
    })

    t.assert_equals(resp['data']['cluster']['can_bootstrap_vshard'], false)
    t.assert_equals(resp['data']['cluster']['vshard_bucket_count'], 3000)
    t.assert_equals(resp['data']['cluster']['vshard_known_groups'], {'default'})

    local function _get_demo_uri()
        return router_server:graphql({query = [[{
            cluster { self { demo_uri } } }
        ]]}).data.cluster.self.demo_uri
    end

    t.assert_equals(_get_demo_uri(), box.NULL)

    local demo_uri = 'http://try-cartridge.tarantool.io'
    router_server.net_box:eval([[
        os.setenv('TARANTOOL_DEMO_URI', ...)
    ]], {demo_uri})

    t.assert_equals(_get_demo_uri(g.server), demo_uri)
end


function g.test_custom_http_endpoint()
    local router = g.cluster:server('router')
    local resp = router:http_request('get', '/custom-get')
    t.assert_equals(resp['body'], 'GET OK')

    local resp = router:http_request('post', '/custom-post')
    t.assert_equals(resp['body'], 'POST OK')
end


function g.test_server_stat_schema()
    local router = g.cluster:server('router')
    local resp = router:graphql({
        query = [[{
            __type(name: "ServerStat") {
                fields { name }
            }
        }]]
    })

    local field_names = fields_from_map(resp['data']['__type'], 'name')
    t.assert_items_equals(field_names, {
        'items_size', 'items_used', 'items_used_ratio',
        'quota_size', 'quota_used', 'quota_used_ratio',
        'arena_size', 'arena_used', 'arena_used_ratio',
        'vshard_buckets_count'
    })

    local stat_fields_str = table.concat(field_names, ' ')
    local resp = router:graphql({
        query = string.format([[{
            servers {
                statistics { %s }
            }
        }]], stat_fields_str)
    })
    log.info(resp['data']['servers'][1])
end

function g.test_server_info_schema()
    local router = g.cluster:server('router')
    local resp = router:graphql({
        query = [[{
            general_fields: __type(name: "ServerInfoGeneral") {
                fields { name }
            }
            storage_fields: __type(name: "ServerInfoStorage") {
                fields { name }
            }
            network_fields: __type(name: "ServerInfoNetwork") {
                fields { name }
            }
            replication_fields: __type(name: "ServerInfoReplication") {
                fields { name }
            }
            cartridge_fields: __type(name: "ServerInfoCartridge") {
                fields { name }
            }
        }]]
    })

    local data = resp['data']
    local field_name_general = fields_from_map(data['general_fields'], 'name')
    local field_name_storage = fields_from_map(data['storage_fields'], 'name')
    local field_name_network = fields_from_map(data['network_fields'], 'name')
    local field_name_replica = fields_from_map(data['replication_fields'], 'name')
    local field_name_cartridge = fields_from_map(data['cartridge_fields'], 'name')

    local resp = router:graphql({
        query = string.format(
            [[
                {
                    servers {
                        boxinfo {
                            general { %s }
                            storage { %s }
                            network { %s }
                            replication { %s }
                            cartridge { %s }
                        }
                    }
                }
            ]],
            table.concat(field_name_general, ' '),
            table.concat(field_name_storage, ' '),
            table.concat(field_name_network, ' '),
            table.concat(field_name_replica, ' '),
            table.concat(field_name_cartridge, ' ')
                -- workaround composite graphql type
                :gsub('error', 'error {}')
        )
    })
    log.info(resp['data']['servers'][1])
end

function g.test_replication_info_schema()
    local router = g.cluster:server('router')
    local resp = router:graphql({
        query = [[{
            __type(name: "ReplicaStatus") {
                fields { name }
            }
        }]]
    })

    local field_names = fields_from_map(resp['data']['__type'], 'name')
    log.info(field_names)

    local replica_fields_str = table.concat(field_names, ' ')
    router:graphql({
        query = string.format([[{
            servers {
                boxinfo {
                    replication {
                        replication_info {
                            %s
                        }
                    }
                }
            }
        }]],  replica_fields_str)
    })
end

function g.test_servers()
    local router = g.cluster:server('router')

    local resp = router:graphql({
        query = [[
            {
                servers {
                    uri
                    uuid
                    alias
                    labels
                    disabled
                    priority
                    replicaset { roles }
                    statistics { vshard_buckets_count }
                    boxinfo { cartridge { state error { message class_name } } }
                }
            }
        ]]
    })

    local servers = resp['data']['servers']

    t.assert_equals(#servers, 4)

    t.assert_equals(
        helpers.table_find_by_attr(servers, 'uri', 'localhost:13301'),
        {
            uri = 'localhost:13301',
            uuid = helpers.uuid('a', 'a', 1),
            alias = 'router',
            labels = {},
            priority = 1,
            disabled = false,
            statistics = {vshard_buckets_count = box.NULL},
            replicaset = {roles = {'vshard-router'}},
            boxinfo = {cartridge = {error = box.NULL, state = "RolesConfigured"}},
        }
    )

    t.assert_equals(
        helpers.table_find_by_attr(servers, 'uri', 'localhost:13302'),
        {
            uri = 'localhost:13302',
            uuid = helpers.uuid('b', 'b', 1),
            alias = 'storage',
            labels = {},
            priority = 1,
            disabled = false,
            statistics = {vshard_buckets_count = 3000},
            replicaset = {roles = {'vshard-storage'}},
            boxinfo = {cartridge = {error = box.NULL, state = "RolesConfigured"}},
        }
    )

    t.assert_equals(
        helpers.table_find_by_attr(servers, 'uri', 'localhost:13304'),
        {
            uri = 'localhost:13304',
            uuid = helpers.uuid('b', 'b', 2),
            alias = 'storage-2',
            labels = {},
            priority = 2,
            disabled = false,
            statistics = {vshard_buckets_count = 3000},
            replicaset = {roles = {'vshard-storage'}},
            boxinfo = {cartridge = {error = box.NULL, state = "RolesConfigured"}},
        }
    )

    t.assert_equals(
        helpers.table_find_by_attr(servers, 'uri', 'localhost:13303'),
        {
            uri = 'localhost:13303',
            uuid = '',
            alias = 'spare',
            labels = box.NULL,
            priority = box.NULL,
            disabled = box.NULL,
            statistics = box.NULL,
            replicaset = box.NULL,
            boxinfo = box.NULL,
        }
    )
end

function g.test_replicasets()
    local resp = g.cluster:server('router'):graphql({
        query = [[
            {
                replicasets {
                    uuid
                    alias
                    roles
                    status
                    master { uuid }
                    active_master { uuid }
                    servers { uri priority }
                    all_rw
                    weight
                }
            }
        ]]
    })

    local replicasets = resp['data']['replicasets']

    t.assert_equals(#replicasets, 2)

    t.assert_equals(
        helpers.table_find_by_attr(replicasets, 'uuid', helpers.uuid('a')),
        {
            uuid = helpers.uuid('a'),
            alias = 'unnamed',
            roles = {'vshard-router'},
            status = 'healthy',
            master = {uuid = helpers.uuid('a', 'a', 1)},
            active_master = {uuid = helpers.uuid('a', 'a', 1)},
            servers = {{uri = 'localhost:13301', priority = 1}},
            all_rw = false,
            weight = box.NULL,
        }
    )

    t.assert_equals(
        helpers.table_find_by_attr(replicasets, 'uuid', helpers.uuid('b')),
        {
            uuid = helpers.uuid('b'),
            alias = 'unnamed',
            roles = {'vshard-storage'},
            status = 'healthy',
            master = {uuid = helpers.uuid('b', 'b', 1)},
            active_master = {uuid = helpers.uuid('b', 'b', 1)},
            weight = 1,
            all_rw = true,
            servers = {
                {uri = 'localhost:13302', priority = 1},
                {uri = 'localhost:13304', priority = 2},
            }
        }
    )
end

function g.test_probe_server()
    local router = g.cluster:server('router')
    local probe_req = function(vars)
        return router:graphql({
            query = 'mutation($uri: String!) { probe_server(uri:$uri) }',
            variables = vars
        })
    end

    t.assert_error_msg_contains(
        'Probe "localhost:9" failed: no response',
        probe_req, {uri = 'localhost:9'}
    )

    t.assert_error_msg_contains(
        'Probe "bad-host" failed: ping was not sent',
        probe_req, {uri = 'bad-host'}
    )

    local resp = probe_req({uri = router.advertise_uri})
    t.assert_equals(resp['data']['probe_server'], true)
end

function g.test_clock_delta()
    local router = g.cluster:server('router')

    local resp = router:graphql({
        query = [[{ servers { uri clock_delta } }]]
    })

    local servers = resp['data']['servers']

    t.assert_equals(#servers, 4)
    for _, server in pairs(servers) do
        t.assert_almost_equals(server.clock_delta, 0, 0.1)
    end
end

function g.test_topology_caching()
    -- In this test we protect `admin.get_topology` function from being
    -- executed twice in the same request and query same data with
    -- different aliases
    g.cluster.main_server.net_box:eval([[
        local fiber = require('fiber')
        local lua_api_topology = require('cartridge.lua-api.topology')
        local __get_topology = lua_api_topology.get_topology
        lua_api_topology.get_topology = function()
            assert(
                not fiber.self().storage.get_topology_wasted,
                "Excess get_topology call"
            )
            fiber.self().storage.get_topology_wasted = true
            return __get_topology()
        end
    ]])

    local resp = g.cluster.main_server:graphql({
        query = [[{
            s1: servers {alias}
            s2: servers {alias}
            replicasets {servers {}}
        }]],
    })

    t.assert_equals(resp.data.s1, resp.data.s2)

    local resp = g.cluster.main_server:graphql({
        query = [[{
            r1: replicasets {servers {replicaset {servers { uuid }}}}
            r2: replicasets {servers {replicaset {servers { uuid }}}}
        }]],
    })

    t.assert_equals(resp.data.r1, resp.data.r2)
end

function g.test_operation_error()
    local victim = g.cluster:server('storage-2')
    victim.net_box:eval([[
        package.loaded['mymodule-permanent'].apply_config = function()
            error('Artificial Error', 0)
        end
    ]])

    -- Dummy mutation doesn't trigger two-phase commit
    g.cluster.main_server:graphql({
        query = [[
            mutation { cluster { config(sections: []) {} } }
        ]],
    })

    -- Real tho-phase commit fails on apply stage with artificial error
    local resp = g.cluster.main_server:graphql({
        query = [[
            mutation { cluster { schema(as_yaml: "{}") {} } }
        ]],
        raise = false,
    })

    local err = resp.errors[1]
    t.assert_equals(err.message, 'Artificial Error')
    t.assert_covers(err.extensions, {
        ['io.tarantool.errors.class_name'] = 'ApplyConfigError',
    })

    local victim_info = g.cluster.main_server:graphql({
        query = [[query($uuid: String!){
            servers(uuid: $uuid) {
                boxinfo {cartridge {
                    state
                    error { message class_name stack}
                }}
            }
        }]],
        variables = {uuid = victim.instance_uuid},
    }).data.servers[1].boxinfo.cartridge

    t.assert_equals(victim_info.state, 'OperationError')
    t.assert_covers(victim_info.error, {
        message = 'Artificial Error',
        class_name = 'ApplyConfigError',
    })
end

function g.test_webui_blacklist()
    local query = '{ cluster { webui_blacklist }}'

    t.assert_equals(
        g.cluster.main_server:graphql({query = query}).data.cluster,
        {webui_blacklist = {}}
    )

    t.assert_equals(
        g.server:graphql({query = query}).data.cluster,
        {webui_blacklist = {'/cluster/code', '/cluster/schema'}}
    )
end
