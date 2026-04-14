local fio = require('fio')
local fiber = require('fiber')
local t = require('luatest')
local helpers = require('test.helper')

local etcd2_client = require('cartridge.etcd2-client')
local stateboard_client = require('cartridge.stateboard-client')

local g_etcd2 = t.group('integration.failover_stateful.etcd2_autoreturn')
local g_stateboard = t.group('integration.failover_stateful.stateboard_autoreturn')
local g_manual_etcd2 = t.group('integration.failover_stateful.manual_election.etcd2_autoreturn')
local g_manual_stateboard = t.group('integration.failover_stateful.manual_election.stateboard_autoreturn')

local manual_env = {
    TARANTOOL_ELECTION_MODE = 'manual',
    TARANTOOL_ELECTION_FENCING_MODE = 'off',
}

local core_1_uuid = helpers.uuid('c')
local core_1_1_uuid = helpers.uuid('c', 'c', 1)

local storage1_uuid = helpers.uuid('b', 1)
local storage1_1_uuid = helpers.uuid('b', 'b', 1)
local storage1_2_uuid = helpers.uuid('b', 'b', 2)

local --[[ const ]] AUTORETURN_DELAY = 3

local function setup_cluster(g, opts)
    opts = opts or {}
    g.require_manual_election = opts.require_manual_election or false

    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        env = helpers.merge_env({}, opts.extra_env or {}),
        replicasets = {
            {
                alias = 'coordinator',
                uuid = core_1_uuid,
                roles = {'failover-coordinator'},
                servers = {
                    {alias = 'coordinator', instance_uuid = core_1_1_uuid},
                },
            },
            {
                alias = 'storage-1',
                uuid = storage1_uuid,
                roles = {},
                servers = {
                    {alias = 'leader', instance_uuid = storage1_1_uuid},
                    {alias = 'replica', instance_uuid = storage1_2_uuid},
                },
            },
        },
    })

    g.cluster:start()
end

local function setup_stateboard_group(g, opts)
    opts = opts or {}

    if opts.require_manual_election then
        t.skip_if(not helpers.tarantool_supports_election_fencing_mode(),
            'Manual election release-1 tests require election_fencing_mode support')
    end

    g.datadir = fio.tempdir()

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

    setup_cluster(g, {
        extra_env = opts.extra_env,
        require_manual_election = opts.require_manual_election,
    })

    t.assert(g.cluster.main_server:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            mode = 'stateful',
            leader_autoreturn = true,
            autoreturn_delay = AUTORETURN_DELAY,
            state_provider = 'tarantool',
            tarantool_params = {
                uri = g.state_provider.net_box_uri,
                password = g.kvpassword,
            },
        }}
    ))
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
        endpoints = {opts.uri},
        lock_delay = 3,
        username = '',
        password = '',
        request_timeout = 1,
    })

    setup_cluster(g, {
        extra_env = opts.extra_env,
        require_manual_election = opts.require_manual_election,
    })

    t.assert(g.cluster.main_server:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            mode = 'stateful',
            leader_autoreturn = true,
            autoreturn_delay = AUTORETURN_DELAY,
            state_provider = 'etcd2',
            etcd2_params = {
                prefix = opts.prefix,
                endpoints = {opts.uri},
                lock_delay = 3,
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
        prefix = 'failover_stateful_test',
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
        prefix = 'failover_stateful_manual_autoreturn_test',
        require_manual_election = true,
        uri = 'http://127.0.0.1:14011',
    })
end)

local function after_all(g)
    if g.cluster ~= nil then
        g.cluster:stop()
    end

    if g.state_provider ~= nil then
        helpers.retrying({}, function()
            g.state_provider:stop()
        end)

        if g.state_provider.workdir ~= nil then
            fio.rmtree(g.state_provider.workdir)
        end
    end

    if g.datadir ~= nil then
        fio.rmtree(g.datadir)
    end
end
g_stateboard.after_all(function() after_all(g_stateboard) end)
g_etcd2.after_all(function() after_all(g_etcd2) end)
g_manual_stateboard.after_all(function() after_all(g_manual_stateboard) end)
g_manual_etcd2.after_all(function() after_all(g_manual_etcd2) end)

local function add(name, fn)
    g_stateboard[name] = fn
    g_etcd2[name] = fn
    g_manual_stateboard[name] = fn
    g_manual_etcd2[name] = fn
end

local q_promote = [[
    return require('cartridge').failover_promote(...)
]]
local q_leadership = string.format([[
    local failover = require('cartridge.failover')
    return failover.get_active_leaders()[%q]
]], storage1_uuid)
local q_server_state = [[
    local failover = require('cartridge.failover')

    return {
        is_leader = failover.is_leader(),
        is_rw = box.info.ro == false,
    }
]]

local function check_fiber(g, server_name, present)
    g.cluster:server(server_name):exec(function(present)
        local fun = require('fun')
        local fiber = require('fiber')

        local vars = require('cartridge.vars').new('cartridge.failover')
        assert((vars.autoreturn_fiber ~= nil) == present)
        local num_of_fibers = present and 1 or 0
        assert(fun.iter(fiber.info()):filter(
            function(_, x) return x.name == 'cartridge.leader_autoreturn' end):length() == num_of_fibers)
    end, {present})
end

local function assert_manual_preferred_leader_rw(g)
    if not g.require_manual_election then
        return
    end

    helpers.retrying({timeout = 5}, function()
        local state = g.cluster:server('leader'):eval(q_server_state)
        t.assert_equals(state.is_leader, true)
        t.assert_equals(state.is_rw, true)
    end)
end

add('test_fiber_present', function(g)
    check_fiber(g, 'coordinator', false)
    for _, v in ipairs{'leader', 'replica'} do
        check_fiber(g, v, true)
    end
end)


add('test_stateful_failover_autoreturn', function(g)
    helpers.retrying({}, function()
        local ok, err = g.cluster.main_server:eval(q_promote, {{[storage1_uuid] = storage1_2_uuid}})
        t.assert(ok, err)
    end)

    helpers.retrying({}, function()
        t.assert_equals(g.cluster.main_server:eval(q_leadership), storage1_2_uuid)
    end)

    helpers.retrying({timeout = 5}, function()
        t.assert_equals(g.cluster.main_server:eval(q_leadership), storage1_1_uuid)
    end)

    assert_manual_preferred_leader_rw(g)
end)

for _, server in ipairs({'coordinator', 'leader'}) do
    add('test_fails_no_' .. server, function(g)
        helpers.retrying({}, function()
            local ok, err = g.cluster.main_server:eval(q_promote, {{[storage1_uuid] = storage1_2_uuid}})
            t.assert(ok, err)
        end)
        g.cluster:server(server):stop()

        helpers.retrying({}, function()
            t.assert_equals(g.cluster:server('replica'):eval(q_leadership), storage1_2_uuid)
        end)
        g.cluster:server(server):start()
        g.cluster:wait_until_healthy()

        helpers.retrying({timeout = 2*AUTORETURN_DELAY}, function()
            t.assert_equals(g.cluster.main_server:eval(q_leadership), storage1_1_uuid)
        end)

        assert_manual_preferred_leader_rw(g)
    end)
end

local function set_autoreturn(g, leader_autoreturn)
    local response = g.cluster.main_server:graphql({
        query = [[
            mutation(
                $leader_autoreturn: Boolean
            ) {
                cluster {
                    failover_params(
                        leader_autoreturn: $leader_autoreturn
                    ) {
                        leader_autoreturn
                    }
                }
            }
        ]],
        variables = {leader_autoreturn = leader_autoreturn},
        raise = false,
    })
    if response.errors then
        error(response.errors[1].message, 2)
    end
end

add('test_disable_no_fibers', function(g)
    set_autoreturn(g, false)
    for _, v in ipairs{'coordinator', 'leader', 'replica'} do
        check_fiber(g, v, false)
    end
    set_autoreturn(g, true)
end)

add('test_failed_no_prime', function(g)
    helpers.retrying({}, function()
        local ok, err = g.cluster.main_server:eval(q_promote, {{[storage1_uuid] = storage1_2_uuid}})
        t.assert(ok, err)
    end)

    helpers.retrying({}, function()
        t.assert_equals(g.cluster.main_server:eval(q_leadership), storage1_2_uuid)
    end)

    g.cluster:server('replica'):exec(function(uri)
        local memberhsip = require('membership')
        rawset(_G, '__get_member_prev', memberhsip.get_member)
        package.loaded['membership'].get_member = function(advertise_uri)
            local res = _G.__get_member_prev(uri)
            if uri == advertise_uri then
                res.status = 'unhealthy'
            end
            return res
        end
    end, {g.cluster:server('replica').advertise_uri})
    fiber.sleep(5) -- enough to wait autoreturn fiber

    t.assert_not_equals(g.cluster.main_server:eval(q_leadership), storage1_1_uuid)
    t.assert_equals(g.cluster.main_server:eval(q_leadership), storage1_2_uuid)

    g.cluster:server('replica'):exec(function()
        package.loaded['membership'].get_member = rawget(_G, '__get_member_prev')
    end)
end)

