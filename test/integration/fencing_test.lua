local fiber = require('fiber')
local fio = require('fio')
local uri = require('uri')
local t = require('luatest')
local helpers = require('test.helper')

local etcd2_client = require('cartridge.etcd2-client')
local stateboard_client = require('cartridge.stateboard-client')

local g_etcd2 = t.group('integration.fencing.etcd2')
local g_stateboard = t.group('integration.fencing.stateboard')
local g_manual_etcd2 = t.group('integration.fencing.manual_election.etcd2')
local g_manual_stateboard = t.group('integration.fencing.manual_election.stateboard')
local synchro_params = {{fencing = false}, {fencing = true}}
local g_synchro_etcd2 = t.group('integration.fencing.synchro.etcd2', synchro_params)
local g_synchro_stateboard = t.group('integration.fencing.synchro.stateboard', synchro_params)

local manual_env = {
    TARANTOOL_ELECTION_MODE = 'manual',
    TARANTOOL_ELECTION_FENCING_MODE = 'off',
}

local uA = helpers.uuid('a')
local uB = helpers.uuid('b')
local uA1 = helpers.uuid('a', 1, 1)
local uB1 = helpers.uuid('b', 1, 1)
local uB2 = helpers.uuid('b', 2, 2)
local uB3 = helpers.uuid('b', 3, 3)
local A1
local B1
local B2
local B3

local function setup_cluster(g, opts)
    opts = opts or {}

    local servers = {
        {alias = 'B1', instance_uuid = uB1},
        {alias = 'B2', instance_uuid = uB2},
    }
    if opts.with_third_replica then
        table.insert(servers, {alias = 'B3', instance_uuid = uB3})
    end

    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        env = helpers.merge_env({
            TARANTOOL_SWIM_SUSPECT_TIMEOUT_SECONDS = 0,
            TARANTOOL_SWIM_PROTOCOL_PERIOD_SECONDS = 0.2,
        }, opts.extra_env or {}),
        replicasets = {{
            uuid = uA,
            roles = {},
            servers = {{alias = 'A1', instance_uuid = uA1}},
        }, {
            uuid = uB,
            roles = {},
            servers = servers,
        }},
    })

    g.cluster:start()
    A1 = g.cluster:server('A1')
    B1 = g.cluster:server('B1')
    B2 = g.cluster:server('B2')
    B3 = opts.with_third_replica and g.cluster:server('B3') or nil

    g.cluster.main_server:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            failover_timeout = 3,
            fencing_enabled = true,
            fencing_timeout = 2,
            fencing_pause = 1,
        }}
    )
end

local function setup_stateboard_group(g, opts)
    opts = opts or {}

    if opts.require_manual_election then
        t.skip_if(not helpers.tarantool_supports_election_fencing_mode(),
            'Manual election release-1 tests require election_fencing_mode support')
    end

    g.datadir = fio.tempdir()

    fio.mktree(fio.pathjoin(g.datadir, 'stateboard'))
    g.kvpassword = helpers.random_cookie()
    g.state_provider = helpers.Stateboard:new({
        command = helpers.entrypoint('srv_stateboard'),
        workdir = fio.pathjoin(g.datadir, 'stateboard'),
        net_box_port = opts.net_box_port,
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

    setup_cluster(g, opts)

    B1:call('box.schema.sequence.create', {'test'})
    B1:call('package.loaded.cartridge.failover_set_params', {{
        mode = 'stateful',
        state_provider = 'tarantool',
        tarantool_params = {
            uri = '127.0.0.1:' .. g.state_provider.net_box_port,
            password = g.kvpassword,
        },
    }})
end

local function setup_etcd2_group(g, opts)
    opts = opts or {}

    if opts.require_manual_election then
        t.skip_if(not helpers.tarantool_supports_election_fencing_mode(),
            'Manual election release-1 tests require election_fencing_mode support')
    end

    local etcd_path = os.getenv('ETCD_PATH')
    t.skip_if(etcd_path == nil, 'etcd missing')

    g.datadir = fio.tempdir()
    g.state_provider = helpers.Etcd:new({
        workdir = fio.tempdir('/tmp'),
        etcd_path = etcd_path,
        peer_url = opts.peer_url,
        client_url = opts.uri,
    })

    g.state_provider:start()
    g.client = etcd2_client.new({
        prefix = opts.prefix,
        endpoints = {g.state_provider.client_url},
        lock_delay = opts.lock_delay or 5,
        username = '',
        password = '',
        request_timeout = 1,
    })

    setup_cluster(g, opts)

    B1:call('box.schema.sequence.create', {'test'})
    t.assert(A1:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            mode = 'stateful',
            state_provider = 'etcd2',
            etcd2_params = {
                prefix = opts.prefix,
                endpoints = {g.state_provider.client_url},
                lock_delay = opts.lock_delay or 5,
            },
        }}
    ))
end

g_stateboard.before_all(function()
    setup_stateboard_group(g_stateboard, {
        net_box_port = 14401,
    })
end)

g_etcd2.before_all(function()
    setup_etcd2_group(g_etcd2, {
        peer_url = 'http://127.0.0.1:17001',
        prefix = 'fencing_test',
        uri = 'http://127.0.0.1:14001',
    })
end)

g_manual_stateboard.before_all(function()
    setup_stateboard_group(g_manual_stateboard, {
        extra_env = manual_env,
        net_box_port = 14411,
        require_manual_election = true,
    })
end)

g_manual_etcd2.before_all(function()
    setup_etcd2_group(g_manual_etcd2, {
        extra_env = manual_env,
        peer_url = 'http://127.0.0.1:17011',
        prefix = 'manual_fencing_test',
        require_manual_election = true,
        uri = 'http://127.0.0.1:14011',
    })
end)

g_synchro_stateboard.before_all(function(g)
    setup_stateboard_group(g, {
        extra_env = manual_env,
        net_box_port = 14431,
        require_manual_election = true,
        with_third_replica = true,
    })
end)

g_synchro_etcd2.before_all(function(g)
    setup_etcd2_group(g, {
        extra_env = manual_env,
        lock_delay = 60,
        peer_url = 'http://127.0.0.1:17031',
        prefix = 'synchro_fencing_test',
        require_manual_election = true,
        uri = 'http://127.0.0.1:14031',
        with_third_replica = true,
    })
end)

local function after_all(g)
    if g.cluster ~= nil then
        g.cluster:stop()
    end

    if g.state_provider ~= nil then
        g.state_provider:stop()

        if g.state_provider.workdir ~= nil then
            fio.rmtree(g.state_provider.workdir)
        end
    end

    if g.datadir ~= nil then
        fio.rmtree(g.datadir)
    end
end

g_etcd2.after_all(function() after_all(g_etcd2) end)
g_stateboard.after_all(function() after_all(g_stateboard) end)
g_manual_etcd2.after_all(function() after_all(g_manual_etcd2) end)
g_manual_stateboard.after_all(function() after_all(g_manual_stateboard) end)
g_synchro_etcd2.after_all(after_all)
g_synchro_stateboard.after_all(after_all)

local function before_each(g)
    g.session = g.client:get_session()
    t.assert(g.session:acquire_lock({uuid = 'test-uuid', uri = 'test'}))
    t.assert(g.session:set_leaders({{uA, uA1}, {uB, uB1}}, true))

    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(A1), {})
    end)
end

g_etcd2.before_each(function() before_each(g_etcd2) end)
g_stateboard.before_each(function() before_each(g_stateboard) end)
g_manual_etcd2.before_each(function() before_each(g_manual_etcd2) end)
g_manual_stateboard.before_each(function() before_each(g_manual_stateboard) end)
g_synchro_etcd2.before_each(before_each)
g_synchro_stateboard.before_each(before_each)

local function add(name, fn)
    g_stateboard[name] = fn
    g_etcd2[name] = fn
    g_manual_stateboard[name] = fn
    g_manual_etcd2[name] = fn
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
        t.assert_equals(A1:eval(q_leadership, {uB}), uB1)
        t.assert_equals(B1:eval(q_leadership, {uB}), uB1)
    end)

    A1:eval(q_set_fencing_params, {0.1, 0.1})
    B1:eval(q_set_fencing_params, {0.1, 0.1})

    -- State provider is unavailable
    g.state_provider:stop()

    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_is_vclockkeeper), true)
        t.assert_equals(B1:eval(q_readonliness), false)
        t.assert_equals(B1:eval(q_leadership, {uB}), uB1)
    end)

    t.assert_equals(A1:eval(q_is_vclockkeeper), false)
    t.assert_equals(A1:eval(q_readonliness), false)
    t.assert_equals(A1:eval(q_leadership, {uA}), uA1)

    -- Replica is down
    B2:stop()

    -- Fencing is triggered, B1 goes read-only
    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_is_vclockkeeper), false)
        t.assert_equals(B1:eval(q_readonliness), true)
        t.assert_equals(B1:eval(q_leadership, {uB}), nil)
        -- A1 isn't affected
        t.assert_equals(B1:eval(q_leadership, {uA}), uA1)
    end)

    -- A1 still thinks B1 is a leader
    t.assert_equals(A1:eval(q_leadership, {uB}), uB1)

    -- A1 is a single-instance replicaset and never goes ro
    t.assert_equals(A1:eval(q_leadership, {uA}), uA1)
    t.assert_equals(A1:eval(q_is_vclockkeeper), false)
    t.assert_equals(A1:eval(q_readonliness), false)

    -- Everything is back to normal
    g.state_provider:start()

    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_is_vclockkeeper), true)
        t.assert_equals(B1:eval(q_readonliness), false)
        t.assert_equals(B1:eval(q_leadership, {uB}), uB1)
    end)
end)


local q_synchro_state = [[
    local queue = box.info.synchro.queue
    return {
        election = box.info.election.state,
        owner = queue.owner,
        len = queue.len,
        ro = box.info.ro,
    }
]]

local function isolate_leader_from_fencing_checks()
    B1:exec(function(peer_uuid)
        local vars = require('cartridge.vars').new('cartridge.failover')
        local membership = require('membership')
        local client = vars.client
        local peer = vars.clusterwide_config:get_readonly('topology').servers[peer_uuid]
        local check_quorum = client.check_quorum
        local get_member = membership.get_member
        client.check_quorum = function() return false end
        membership.get_member = function(address)
            if address ~= peer.uri then
                return get_member(address)
            end
        end
        rawset(_G, 'restore_fencing_checks', function()
            client.check_quorum = check_quorum
            membership.get_member = get_member
        end)
    end, {uB2})
end

local function test_synchro_queue_handover(g)
    local synchro_timeout = 5
    A1:eval(q_set_fencing_params, {0.1, 2})
    B1:exec(function(uuid)
        local topology_api = require('cartridge.lua-api.topology')
        assert(topology_api.set_unelectable_servers({uuid}))
    end, {uB3})

    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_readonliness), false)
    end)
    B1:exec(function(timeout)
        local space = box.schema.space.create('fencing_sync', {is_sync = true})
        space:create_index('pk')
        space:replace{1, 'committed'}
        box.cfg({replication_synchro_timeout = timeout})
    end, {synchro_timeout})

    local replication = B1:eval('return box.cfg.replication')
    local leader_port = uri.parse(B1.advertise_uri).service
    local majority = {}
    for _, address in ipairs(replication) do
        if uri.parse(address).service ~= leader_port then
            table.insert(majority, address)
        end
    end
    B1:eval('box.cfg{replication = {}}')
    B2:eval('box.cfg{replication = ...}', {majority})
    B3:eval('box.cfg{replication = ...}', {majority})

    B1:exec(function()
        require('fiber').create(function()
            pcall(box.space.fencing_sync.replace, box.space.fencing_sync, {2, 'pending'})
        end)
    end)
    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_synchro_state).len, 1)
    end)

    local deadline = fiber.clock() + synchro_timeout
    local old_id = B1:eval('return box.info.id')
    local new_id = B2:eval('return box.info.id')
    local function assert_frozen_queue()
        local state = B1:eval(q_synchro_state)
        t.assert_equals(state, {election = 'follower', owner = old_id, len = 1, ro = true})
    end
    if g.params.fencing then
        isolate_leader_from_fencing_checks()
        B1:exec(function()
            local synchro = box.info.synchro
            rawset(synchro.queue, 'term', 0)
            rawset(box.info, 'synchro', synchro)
        end)
        t.assert(g.session:set_leaders({{uA, 'nobody'}}))
        helpers.retrying({}, function()
            t.assert_equals(B1:eval(q_leadership, {uB}), nil)
        end)
        B1:exec(function()
            _G.__cartridge_failover_pause()
            rawset(box.info, 'synchro', nil)
        end)
        helpers.retrying({}, assert_frozen_queue)
        B1:exec(function() _G.__cartridge_failover_resume() end)
    end

    t.assert(g.session:set_leaders({{uA, uA1}, {uB, uB2}}, true))
    helpers.retrying({}, assert_frozen_queue)
    fiber.sleep(math.max(0, deadline - fiber.clock()) + 0.1)
    assert_frozen_queue()

    helpers.retrying({timeout = 20}, function()
        t.assert_equals(B2:eval(q_readonliness), false)
        t.assert_equals(B2:eval(q_synchro_state).owner, new_id)
    end)
    B2:eval([[box.space.fencing_sync:replace{3, 'new leader'}]])

    if g.params.fencing then
        B1:exec(function() _G.restore_fencing_checks() end)
    end
    for _, server in ipairs({B1, B2, B3}) do
        server:eval('box.cfg{replication = ...}', {replication})
    end
    helpers.retrying({timeout = 20}, function()
        local state = B1:eval(q_synchro_state)
        t.assert_equals(state.owner, new_id)
        t.assert_equals(state.len, 0)
        t.assert_equals(
            B1:eval('return box.space.fencing_sync:select()'),
            B2:eval('return box.space.fencing_sync:select()')
        )
    end)
    g.cluster:wait_until_healthy()
end

g_synchro_etcd2.test_synchro_queue_handover = test_synchro_queue_handover
g_synchro_stateboard.test_synchro_queue_handover = test_synchro_queue_handover
