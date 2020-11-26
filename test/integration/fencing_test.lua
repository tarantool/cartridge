local fio = require('fio')
local t = require('luatest')
local helpers = require('test.helper')

local etcd2_client = require('cartridge.etcd2-client')
local stateboard_client = require('cartridge.stateboard-client')

local g_etcd2 = t.group('integration.fencing.etcd2')
local g_stateboard = t.group('integration.fencing.stateboard')

local uA = helpers.uuid('a')
local uB = helpers.uuid('b')
local uA1 = helpers.uuid('a', 1, 1)
local uB1 = helpers.uuid('b', 1, 1)
local uB2 = helpers.uuid('b', 2, 2)
local A1
local B1
local B2

local function setup_cluster(g)
    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        env = {
            TARANTOOL_SWIM_SUSPECT_TIMEOUT_SECONDS = 0,
            TARANTOOL_SWIM_PROTOCOL_PERIOD_SECONDS = 0.2,
        },
        replicasets = {{
            uuid = uA,
            roles = {},
            servers = {{alias = 'A1', instance_uuid = uA1}},
        }, {
            uuid = uB,
            roles = {},
            servers = {
                {alias = 'B1', instance_uuid = uB1},
                {alias = 'B2', instance_uuid = uB2},
            },
        }},
    })

    g.cluster:start()
    A1 = g.cluster:server('A1')
    B1 = g.cluster:server('B1')
    B2 = g.cluster:server('B2')

    g.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            failover_timeout = 3,
            fencing_enabled = true,
            fencing_timeout = 2,
            fencing_pause = 1,
        }}
    )
end

g_stateboard.before_all(function()
    local g = g_stateboard
    g.datadir = fio.tempdir()

    fio.mktree(fio.pathjoin(g.datadir, 'stateboard'))
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
            TARANTOOL_LOCK_DELAY = 9000,
            TARANTOOL_PASSWORD = g.kvpassword,
            TARANTOOL_CONSOLE_SOCK = fio.pathjoin(
                g.datadir, 'stateboard', 'console.sock'
            ),
        },
    })
    g.state_provider:start()
    helpers.retrying({}, function()
        g.state_provider:connect_net_box()
    end)

    g.client = stateboard_client.new({
        uri = '127.0.0.1:' .. g.state_provider.net_box_port,
        password = g.state_provider.net_box_credentials.password,
        call_timeout = 1,
    })

    setup_cluster(g)

    B1.net_box:call('box.schema.sequence.create', {'test'})
    B1.net_box:call('package.loaded.cartridge.failover_set_params', {{
        mode = 'stateful',
        state_provider = 'tarantool',
        tarantool_params = {
            uri = '127.0.0.1:' .. g.state_provider.net_box_port,
            password = g.kvpassword,
        },
    }})
end)

g_etcd2.before_all(function()
    local g = g_etcd2
    local etcd_path = os.getenv('ETCD_PATH')
    t.skip_if(etcd_path == nil, 'etcd missing')

    g.datadir = fio.tempdir()
    g.state_provider = helpers.Etcd:new({
        workdir = fio.tempdir('/tmp'),
        etcd_path = etcd_path,
        peer_url = 'http://127.0.0.1:17001',
        client_url = 'http://127.0.0.1:14001',
    })

    g.state_provider:start()
    g.client = etcd2_client.new({
        prefix = 'fencing_test',
        endpoints = {g.state_provider.client_url},
        lock_delay = 5,
        username = '',
        password = '',
        request_timeout = 1,
    })

    setup_cluster(g)

    B1.net_box:call('box.schema.sequence.create', {'test'})
    t.assert(A1.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            mode = 'stateful',
            state_provider = 'etcd2',
            etcd2_params = {
                prefix = 'fencing_test',
                endpoints = {g.state_provider.client_url},
                lock_delay = 5,
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

g_etcd2.after_all(function() after_all(g_etcd2) end)
g_stateboard.after_all(function() after_all(g_stateboard) end)

local function before_each(g)
    g.session = g.client:get_session()
    t.assert(g.session:acquire_lock({uuid = 'test-uuid', uri = 'test'}))
    t.assert(g.session:set_vclockkeeper(uA, uA1))
    t.assert(g.session:set_vclockkeeper(uB, uB1))
    t.assert(g.session:set_leaders({{uA, uA1}, {uB, uB1}}))

    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(A1), {})
    end)
end

g_etcd2.before_each(function() before_each(g_etcd2) end)
g_stateboard.before_each(function() before_each(g_stateboard) end)

local function add(name, fn)
    g_stateboard[name] = fn
    g_etcd2[name] = fn
end

local q_readonliness = "return box.info.ro"
local q_set_fencing_params = [[
    local cartridge = require('cartridge')
    local pause, timeout = ...

    cartridge.failover_set_params({
        fencing_timeout = timeout,
        fencing_pause = pause,
    })
]]
local q_is_vclockkeeper = [[
    local failover = require('cartridge.failover')
    return failover.is_vclockkeeper()
]]
local q_leadership = [[
    local failover = require('cartridge.failover')
    return failover.get_active_leaders()[...]
]]

add('test_basics', function(g)
    t.assert(g.session:set_leaders({{uB, uB1}}))
    helpers.retrying({}, function()
        t.assert_equals(A1.net_box:eval(q_leadership, {uB}), uB1)
        t.assert_equals(B1.net_box:eval(q_leadership, {uB}), uB1)
    end)

    A1.net_box:eval(q_set_fencing_params, {0.1, 0.1})
    B1.net_box:eval(q_set_fencing_params, {0.1, 0.1})

    -- State provider is unavailable
    g.state_provider:stop()

    helpers.retrying({}, function()
        t.assert_equals(B1.net_box:eval(q_is_vclockkeeper), true)
        t.assert_equals(B1.net_box:eval(q_readonliness), false)
        t.assert_equals(B1.net_box:eval(q_leadership, {uB}), uB1)
    end)

    t.assert_equals(A1.net_box:eval(q_is_vclockkeeper), false)
    t.assert_equals(A1.net_box:eval(q_readonliness), false)
    t.assert_equals(A1.net_box:eval(q_leadership, {uA}), uA1)

    -- Replica is down
    B2:stop()

    -- Fencing is triggered, B1 goes read-only
    helpers.retrying({}, function()
        t.assert_equals(B1.net_box:eval(q_is_vclockkeeper), false)
        t.assert_equals(B1.net_box:eval(q_readonliness), true)
        t.assert_equals(B1.net_box:eval(q_leadership, {uB}), nil)
        -- A1 isn't affected
        t.assert_equals(B1.net_box:eval(q_leadership, {uA}), uA1)
    end)

    -- A1 still thinks B1 is a leader
    t.assert_equals(A1.net_box:eval(q_leadership, {uB}), uB1)

    -- A1 is a single-instance replicaset and never goes ro
    t.assert_equals(A1.net_box:eval(q_leadership, {uA}), uA1)
    t.assert_equals(A1.net_box:eval(q_is_vclockkeeper), false)
    t.assert_equals(A1.net_box:eval(q_readonliness), false)

    -- Everything is back to normal
    g.state_provider:start()

    helpers.retrying({}, function()
        t.assert_equals(B1.net_box:eval(q_is_vclockkeeper), true)
        t.assert_equals(B1.net_box:eval(q_readonliness), false)
        t.assert_equals(B1.net_box:eval(q_leadership, {uB}), uB1)
    end)
end)
