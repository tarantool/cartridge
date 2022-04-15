local fio = require('fio')
local t = require('luatest')
local helpers = require('test.helper')

local etcd2_client = require('cartridge.etcd2-client')
local stateboard_client = require('cartridge.stateboard-client')

local g_etcd2 = t.group('integration.failover_stateful.etcd2_ordinal_changed')
local g_stateboard = t.group('integration.failover_stateful.stateboard_ordinal_changed')

local core_uuid = helpers.uuid('c')
local C1; local core_1_uuid = helpers.uuid('c', 'c', 1)

local storage1_uuid = helpers.uuid('b', 1)
local storage1_1_uuid = helpers.uuid('b', 'b', 1)
local storage1_2_uuid = helpers.uuid('b', 'b', 2)
local storage1_3_uuid = helpers.uuid('b', 'b', 3)

local storage2_uuid = helpers.uuid('d', 2)
local storage2_1_uuid = helpers.uuid('d', 'd', 1)
local storage2_2_uuid = helpers.uuid('d', 'd', 2)

local function setup_cluster(g)
    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {
            {
                alias = 'core-1',
                uuid = core_uuid,
                roles = {'vshard-router', 'failover-coordinator'},
                servers = {
                    {alias = 'core-1', instance_uuid = core_1_uuid},
                },
            },
            {
                alias = 'storage-1',
                uuid = storage1_uuid,
                roles = {'vshard-storage'},
                servers = {
                    {alias = 'storage-1-leader', instance_uuid = storage1_1_uuid},
                    {alias = 'storage-1-replica', instance_uuid = storage1_2_uuid},
                    {alias = 'storage-1-replica-2', instance_uuid = storage1_3_uuid},
                },
            },
            {
                alias = 'storage-2',
                uuid = storage2_uuid,
                roles = {'vshard-storage'},
                servers = {
                    {alias = 'storage-1-leader', instance_uuid = storage2_1_uuid},
                    {alias = 'storage-1-replica', instance_uuid = storage2_2_uuid},
                },
            },
        },
    })

    C1 = g.cluster:server('core-1')
    C1.state_provider = 'etcd'
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
    g.state_provider:stop()
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

g_stateboard.before_test('test_ordinal_changed', function()
    for _, instance in ipairs(g_stateboard.cluster.servers) do
        instance:exec(function()
            local fiber = require'fiber'
            rawset(_G, 'netbox_call', package.loaded.errors.netbox_call)
            package.loaded.errors.netbox_call = function(conn, fn, ...)
                if fn == 'set_vclockkeeper' then
                    fiber.sleep(1)
                end
                return _G.netbox_call(conn, fn, ...)
            end
        end)
    end
end)

g_stateboard.after_test('test_ordinal_changed', function()
    for _, instance in ipairs(g_stateboard.cluster.servers) do
        instance:exec(function()
            package.loaded.errors.netbox_call = _G.netbox_call
        end)
    end
end)

g_etcd2.before_test('test_ordinal_changed', function()
    for _, instance in ipairs(g_etcd2.cluster.servers) do
        instance:exec(function()
            rawset(_G, 'test_etcd2_client_ordinal_errnj', true)
        end)
    end
end)

g_etcd2.after_test('test_ordinal_changed', function()
    for _, instance in ipairs(g_etcd2.cluster.servers) do
        instance:exec(function()
            rawset(_G, 'test_etcd2_client_ordinal_errnj', nil)
        end)
    end
end)

add('test_ordinal_changed', function()
    helpers.retrying({}, function()
        local ok, err = C1:eval(q_promote, {
            {[storage1_uuid] = storage1_2_uuid,
            [storage2_uuid] = storage2_2_uuid},
            {force_inconsistency = false}
        })
        t.assert_equals(ok, true, err)
        t.assert_not(err)
    end)

    local ok, err = C1:eval(q_promote, {
        {[core_uuid] = core_1_uuid,
        [storage1_uuid] = storage1_1_uuid,
        [storage2_uuid] = storage2_1_uuid},
        {
            force_inconsistency = true,
            skip_error_on_change = C1.state_provider == 'etcd',
        }
    })
    t.assert_equals(ok, true, err)
    t.assert_not(err)
end)
