local fio = require('fio')
local t = require('luatest')
local helpers = require('test.helper')

local etcd2_client = require('cartridge.etcd2-client')
local stateboard_client = require('cartridge.stateboard-client')

local g_etcd2 = t.group('integration.failover_stateful.etcd2_add_replicaset')
local g_stateboard = t.group('integration.failover_stateful.stateboard_add_replicaset')

local router_uuid = helpers.uuid('a')
local router_1_uuid = helpers.uuid('a', 'a', 1)

local storage1_uuid = helpers.uuid('b')
local storage1_1_uuid = helpers.uuid('b', 'b', 1)
local storage1_2_uuid = helpers.uuid('b', 'b', 2)

local storage2_uuid = helpers.uuid('c')
local storage2_1_uuid = helpers.uuid('c', 'c', 1)
local storage2_2_uuid = helpers.uuid('c', 'c', 2)

local function setup_cluster(g)
    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
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
                alias = 'storage-1',
                uuid = storage1_uuid,
                roles = {'vshard-storage'},
                servers = {
                    {alias = 'storage-1-leader', instance_uuid = storage1_1_uuid},
                    {alias = 'storage-1-replica', instance_uuid = storage1_2_uuid},
                },
            },
        },
    })

    g.cluster:start()
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
        prefix = 'failover_add_replicaset_test',
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
                prefix = 'failover_add_replicaset_test',
                endpoints = {URI},
                lock_delay = 3,
            },
        }}
    ))
end)

local function after_all(g)
    if g.new_servers then
        for _, srv in ipairs(g.new_servers) do
            srv:stop()
        end
    end
    g.cluster:stop()
    helpers.retrying({}, function()
        g.state_provider:stop()
    end)
    fio.rmtree(g.state_provider.workdir)
    fio.rmtree(g.datadir)
end
g_stateboard.after_all(function() after_all(g_stateboard) end)
g_etcd2.after_all(function() after_all(g_etcd2) end)

local function add(name, fn)
    g_stateboard[name] = fn
    g_etcd2[name] = fn
end

add('test_add_new_replicaset_gets_leader', function(g)
    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.cluster.main_server), {})
    end)

    helpers.retrying({}, function()
        local leaders = g.client:get_session():get_leaders()
        t.assert(leaders[storage1_uuid], 'storage-1 must have a leader')
    end)

    local srv1 = helpers.Server:new({
        workdir = fio.pathjoin(g.datadir, 'storage-2-leader'),
        alias = 'storage-2-leader',
        command = helpers.entrypoint('srv_basic'),
        cluster_cookie = g.cluster.cookie,
        instance_uuid = storage2_1_uuid,
        replicaset_uuid = storage2_uuid,
        http_port = 8085,
        advertise_port = 13305,
    })
    local srv2 = helpers.Server:new({
        workdir = fio.pathjoin(g.datadir, 'storage-2-replica'),
        alias = 'storage-2-replica',
        command = helpers.entrypoint('srv_basic'),
        cluster_cookie = g.cluster.cookie,
        instance_uuid = storage2_2_uuid,
        replicaset_uuid = storage2_uuid,
        http_port = 8086,
        advertise_port = 13306,
    })
    g.new_servers = {srv1, srv2}

    srv1:start()
    srv2:start()

    g.cluster.main_server.net_box:eval([[
        local membership = require('membership')
        local errors = require('errors')
        errors.assert('ProbeError', membership.probe_uri(...))
    ]], {srv1.advertise_uri})

    g.cluster.main_server.net_box:eval([[
        local membership = require('membership')
        local errors = require('errors')
        errors.assert('ProbeError', membership.probe_uri(...))
    ]], {srv2.advertise_uri})

    local res = g.cluster.main_server:graphql({
        query = [[
            mutation(
                $uri: String!,
                $uuid: String!,
                $replicaset_uuid: String!
            ) {
                join_server(
                    uri: $uri,
                    instance_uuid: $uuid,
                    replicaset_uuid: $replicaset_uuid,
                    roles: ["vshard-storage"],
                    timeout: 30
                )
            }
        ]],
        variables = {
            uri = srv1.advertise_uri,
            uuid = storage2_1_uuid,
            replicaset_uuid = storage2_uuid,
        },
    })
    t.assert_equals(res['data']['join_server'], true)

    helpers.retrying({timeout = 30}, function()
        srv1:connect_net_box()
    end)

    g.cluster:wait_until_healthy()

    res = g.cluster.main_server:graphql({
        query = [[
            mutation(
                $uri: String!,
                $uuid: String!,
                $replicaset_uuid: String!
            ) {
                join_server(
                    uri: $uri,
                    instance_uuid: $uuid,
                    replicaset_uuid: $replicaset_uuid,
                    timeout: 30
                )
            }
        ]],
        variables = {
            uri = srv2.advertise_uri,
            uuid = storage2_2_uuid,
            replicaset_uuid = storage2_uuid,
        },
    })
    t.assert_equals(res['data']['join_server'], true)

    helpers.retrying({timeout = 30}, function()
        srv2:connect_net_box()
    end)

    helpers.retrying({timeout = 30}, function()
        t.assert_equals(srv1:eval('return box.info.ro'), false,
            'New replicaset leader must be writable')
    end)

    helpers.retrying({timeout = 30}, function()
        t.assert_equals(srv2:eval('return box.info.ro'), true,
            'New replicaset replica must be read-only')
    end)

    helpers.retrying({timeout = 30}, function()
        local state1 = srv1:eval([[
            return require('cartridge.confapplier').get_state()
        ]])
        t.assert_equals(state1, 'RolesConfigured',
            'Leader confapplier must reach RolesConfigured')
    end)

    helpers.retrying({timeout = 30}, function()
        local state2 = srv2:eval([[
            return require('cartridge.confapplier').get_state()
        ]])
        t.assert_equals(state2, 'RolesConfigured',
            'Replica confapplier must reach RolesConfigured')
    end)

    helpers.retrying({timeout = 30}, function()
        local leaders = g.client:get_session():get_leaders()
        t.assert_equals(leaders[storage2_uuid], storage2_1_uuid,
            'State provider must have the correct leader for new replicaset')
    end)

    helpers.retrying({timeout = 30}, function()
        t.assert_equals(helpers.list_cluster_issues(g.cluster.main_server), {})
    end)
end)
