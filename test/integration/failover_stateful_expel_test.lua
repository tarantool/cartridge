local fio = require('fio')
local t = require('luatest')
local helpers = require('test.helper')

local etcd2_client = require('cartridge.etcd2-client')
local stateboard_client = require('cartridge.stateboard-client')

local g_etcd2 = t.group('integration.failover_stateful.etcd2_expel_instance')
local g_stateboard = t.group('integration.failover_stateful.stateboard_expel_instance')

local core_1_uuid = helpers.uuid('c')
local core_2_uuid = helpers.uuid('a')
local core_1_1_uuid = helpers.uuid('c', 'c', 1)
local core_2_1_uuid = helpers.uuid('a', 'a', 1)

local storage1_uuid = helpers.uuid('b', 1)
local storage1_1_uuid = helpers.uuid('b', 'b', 1)
local storage1_2_uuid = helpers.uuid('b', 'b', 2)
local storage1_3_uuid = helpers.uuid('b', 'b', 3)


local function setup_cluster(g)
    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {
            {
                alias = 'core-1',
                uuid = core_1_uuid,
                roles = {'failover-coordinator'},
                servers = {
                    {alias = 'core-1', instance_uuid = core_1_1_uuid},
                },
            },
            {
                alias = 'core-2',
                uuid = core_2_uuid,
                roles = {'failover-coordinator'},
                servers = {
                    {alias = 'core-2', instance_uuid = core_2_1_uuid},
                },
            },
            {
                alias = 'storage-1',
                uuid = storage1_uuid,
                roles = {},
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
    helpers.retrying({}, function()
        g.state_provider:stop()
    end)
    fio.rmtree(g.state_provider.workdir)
    fio.rmtree(g.datadir)
end
g_stateboard.after_all(function() after_all(g_stateboard) end)
g_etcd2.after_all(function() after_all(g_etcd2) end)

local q_expel = [[
    mutation($uuid: String!) {
        expel_server(uuid: $uuid)
    }
]]

local function add_new_instance(g)
    local server = helpers.Server:new({
        workdir = fio.tempdir(),
        command = helpers.entrypoint('srv_basic'),
        alias = 'storage-3',
        cluster_cookie = g.cluster.cookie,
        replicaset_uuid = storage1_uuid,
        instance_uuid = storage1_3_uuid,
        http_port = 8085,
        advertise_port = 13305,
    })
    server:start()

    g.cluster:join_server(server)
    return server
end

local function clean_server(server)
    server:stop()
    fio.rmtree(server.workdir)
end

local function add(name, fn)
    g_stateboard[name] = fn
    g_etcd2[name] = fn
end

add('test_expel_instances', function(g)
    local session = g.client:get_session()
    helpers.retrying({}, function()
        local res = session:get_leaders()
        t.assert(res[storage1_uuid])

        local res = session:get_vclockkeeper(storage1_uuid)
        t.assert(res.instance_uuid)
    end)

    g.cluster.main_server:graphql({
        query = q_expel,
        variables = {
            uuid = storage1_2_uuid
        }
    })

    -- nothing has changed
    helpers.retrying({}, function()
        local res = session:get_leaders()
        t.assert(res[storage1_uuid])

        local res = session:get_vclockkeeper(storage1_uuid)
        t.assert(res.instance_uuid)
    end)

    g.cluster.main_server:graphql({
        query = q_expel,
        variables = {
            uuid = storage1_1_uuid
        }
    })

    helpers.retrying({}, function()
        local res = session:get_leaders()
        t.assert_not(res[storage1_uuid])

        local res = session:get_vclockkeeper(storage1_uuid)
        t.assert_not(res)
    end)

    local server = add_new_instance(g)

    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.cluster.main_server), {})
    end)

    clean_server(server)
end)
