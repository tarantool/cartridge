local fio = require('fio')
local t = require('luatest')
local helpers = require('test.helper')

local etcd2_client = require('cartridge.etcd2-client')
local stateboard_client = require('cartridge.stateboard-client')

local g_etcd2 = t.group('integration.failover_stateful.etcd2_electable_instances')
local g_stateboard = t.group('integration.failover_stateful.stateboard_electable_instances')
local g_manual_etcd2 = t.group('integration.failover_stateful.manual_election.etcd2_electable_instances')
local g_manual_stateboard = t.group('integration.failover_stateful.manual_election.stateboard_electable_instances')

local manual_env = {
    TARANTOOL_ELECTION_MODE = 'manual',
    TARANTOOL_ELECTION_FENCING_MODE = 'off',
}

local core_1_uuid = helpers.uuid('c')
local core_1_1_uuid = helpers.uuid('c', 'c', 1)
local storage1_uuid = helpers.uuid('b', 1)
local storage1_1_uuid = helpers.uuid('b', 'b', 1)
local storage1_2_uuid = helpers.uuid('b', 'b', 2)
local storage1_3_uuid = helpers.uuid('b', 'b', 3)


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
        prefix = 'failover_stateful_manual_electable_test',
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

local q_replicaset_state = [[
    local failover = require('cartridge.failover')
    local synchro = box.info.synchro or {}
    local queue = synchro.queue or {}

    return {
        election_fencing_mode = box.cfg.election_fencing_mode,
        election_mode = box.cfg.election_mode,
        is_leader = failover.is_leader(),
        is_rw = box.info.ro == false,
        queue_owner = queue.owner,
        server_id = box.info.id,
    }
]]

local function is_leader()
    return require('cartridge.failover').is_leader()
end

local function is_electable()
    local topology_api = require('cartridge.lua-api.topology')
    return topology_api.get_servers(box.info.uuid)[1].electable
end

local function assert_manual_promoted_state(g, alias)
    if not g.require_manual_election then
        return
    end

    helpers.retrying({timeout = 20}, function()
        local state = g.cluster:server(alias):eval(q_replicaset_state)

        t.assert_equals(state.election_mode, 'manual')
        t.assert_equals(state.election_fencing_mode, 'off')
        t.assert_equals(state.is_leader, true)
        t.assert_equals(state.is_rw, true)
        t.assert_equals(state.queue_owner, state.server_id)
    end)
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

    assert_manual_promoted_state(g, 'storage-1-replica-2')
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

    assert_manual_promoted_state(g, 'storage-1-replica-1')
end)

