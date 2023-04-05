local fio = require('fio')
local t = require('luatest')
local helpers = require('test.helper')

local etcd2_client = require('cartridge.etcd2-client')
local stateboard_client = require('cartridge.stateboard-client')

local g_etcd2 = t.group('integration.failover_stateful.etcd2_electable_instances')
local g_stateboard = t.group('integration.failover_stateful.stateboard_electable_instances')

local core_1_uuid = helpers.uuid('c')
local core_1_1_uuid = helpers.uuid('c', 'c', 1)
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
                alias = 'storage-1',
                uuid = storage1_uuid,
                roles = {},
                servers = {
                    {alias = 'storage-1-leader', instance_uuid = storage1_1_uuid},
                    {alias = 'storage-1-replica-1', instance_uuid = storage1_2_uuid},
                    {alias = 'storage-1-replica-2', instance_uuid = storage1_3_uuid},
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


local function add(name, fn)
    g_stateboard[name] = fn
    g_etcd2[name] = fn
end


local q_promote = [[
    return require('cartridge').failover_promote(...)
]]

local function is_leader()
    return require('cartridge.failover').is_leader()
end

local function is_electable()
    local topology_api = require('cartridge.lua-api.topology')
    return topology_api.get_servers(box.info.uuid)[1].electable
end

add('test_set_electable', function(g)
    g.cluster.main_server:exec(function(uuids)
        local api_topology = require('cartridge.lua-api.topology')
        api_topology.set_unelectable_servers(uuids)
    end, {{storage1_3_uuid}})

    local _, err = g.cluster.main_server:eval(q_promote, { { [storage1_uuid] = storage1_3_uuid } })

    t.assert_str_contains(err.err, "Cannot appoint non-electable instance")

    t.assert_not(g.cluster:server('storage-1-replica-2'):exec(is_leader))

    t.assert_not(g.cluster:server('storage-1-replica-2'):exec(is_electable))


    g.cluster.main_server:exec(function(uuids)
        local api_topology = require('cartridge.lua-api.topology')
        api_topology.set_electable_servers(uuids)
    end, {{storage1_3_uuid}})

    t.assert(g.cluster:server('storage-1-replica-2'):exec(is_electable))

    local ok, err = g.cluster.main_server:eval(q_promote, { { [storage1_uuid] = storage1_3_uuid } })

    t.assert_equals(ok, true, err)
    t.assert_not(err)

    helpers.retrying({}, function()
        t.assert(g.cluster:server('storage-1-replica-2'):exec(is_leader))
    end)
end)

add('test_last_instance_electable', function(g)
    g.cluster:server("core-1"):exec(function(uuid)
        local vars = require('cartridge.vars').new('cartridge.roles.coordinator')
        vars.topology_cfg.servers[uuid].electable = nil -- pretend that instance doesn't have electable field

        return vars.topology_cfg.servers[uuid]
    end, {storage1_2_uuid})

    local _, err = g.cluster.main_server:eval(q_promote, { { [storage1_uuid] = storage1_2_uuid } })

    t.assert_not(err)

    t.assert(g.cluster:server('storage-1-replica-1'):exec(is_leader))
end)
