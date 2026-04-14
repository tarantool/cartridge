local fio = require('fio')
local t = require('luatest')
local helpers = require('test.helper')

local etcd2_client = require('cartridge.etcd2-client')
local stateboard_client = require('cartridge.stateboard-client')

local g_etcd2 = t.group('integration.failover_stateful.etcd2_ordinal_changed')
local g_stateboard = t.group('integration.failover_stateful.stateboard_ordinal_changed')
local g_manual_etcd2 = t.group('integration.failover_stateful.manual_election.etcd2_ordinal_changed')
local g_manual_stateboard = t.group('integration.failover_stateful.manual_election.stateboard_ordinal_changed')

local manual_env = {
    TARANTOOL_ELECTION_MODE = 'manual',
    TARANTOOL_ELECTION_FENCING_MODE = 'off',
}

local core_uuid = helpers.uuid('c')
local core_1_uuid = helpers.uuid('c', 'c', 1)

local storage1_uuid = helpers.uuid('b', 1)
local storage1_1_uuid = helpers.uuid('b', 'b', 1)
local storage1_2_uuid = helpers.uuid('b', 'b', 2)
local storage1_3_uuid = helpers.uuid('b', 'b', 3)

local storage2_uuid = helpers.uuid('d', 2)
local storage2_1_uuid = helpers.uuid('d', 'd', 1)
local storage2_2_uuid = helpers.uuid('d', 'd', 2)

local function setup_cluster(g, opts)
    opts = opts or {}

    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        env = helpers.merge_env({}, opts.extra_env or {}),
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

    g.coordinator = g.cluster:server('core-1')
    g.cluster:start()
end

local function setup_stateboard_group(g, opts)
    opts = opts or {}

    if opts.require_manual_election then
        t.skip_if(not helpers.tarantool_supports_election_fencing_mode(),
            'Manual election release-1 tests require election_fencing_mode support')
    end

    g.datadir = fio.tempdir()
    g.is_etcd2 = false
    g.require_manual_election = opts.require_manual_election or false

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

    setup_cluster(g, {extra_env = opts.extra_env})

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
    g.is_etcd2 = true
    g.require_manual_election = opts.require_manual_election or false
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

    setup_cluster(g, {extra_env = opts.extra_env})

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
        prefix = 'failover_stateful_test',
        peer_url = 'http://127.0.0.1:17001',
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
        prefix = 'failover_stateful_manual_ordinal_changed_test',
        peer_url = 'http://127.0.0.1:17011',
        require_manual_election = true,
        uri = 'http://127.0.0.1:14011',
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
        instance_uuid = box.info.uuid,
        is_rw = box.info.ro == false,
        leader = failover.get_active_leaders()[...],
        queue_owner = queue.owner,
        server_id = box.info.id,
    }
]]

local function get_server_by_instance_uuid(g, instance_uuid)
    for _, server in ipairs(g.cluster.servers) do
        if server.instance_uuid == instance_uuid then
            return server
        end
    end

    error(('Server %s not found'):format(instance_uuid))
end

local function assert_promoted_leaders(g, promoted_replicasets)
    for replicaset_uuid, instance_uuid in pairs(promoted_replicasets) do
        helpers.retrying({timeout = 30}, function()
            local server = get_server_by_instance_uuid(g, instance_uuid)
            local state = server:eval(q_replicaset_state, {replicaset_uuid})
            local details = ('replicaset %s, promoted instance %s'):format(
                replicaset_uuid, instance_uuid
            )

            t.assert_equals(state.instance_uuid, instance_uuid, details)
            t.assert_equals(state.leader, instance_uuid, details)
            t.assert_equals(state.is_rw, true, details)
            if helpers.tarantool_version_ge('2.6.1') then
                t.assert_equals(state.queue_owner, state.server_id, details)
            end

            if g.require_manual_election then
                t.assert_equals(state.election_mode, 'manual', details)
                t.assert_equals(state.election_fencing_mode, 'off', details)
            end
        end)
    end
end

local function add_stateboard_hooks(g)
    g.before_test('test_ordinal_changed', function()
        for _, instance in ipairs(g.cluster.servers) do
            instance:exec(function()
                local fiber = require('fiber')
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

    g.after_test('test_ordinal_changed', function()
        for _, instance in ipairs(g.cluster.servers) do
            instance:exec(function()
                package.loaded.errors.netbox_call = _G.netbox_call
            end)
        end
    end)
end

local function add_etcd2_hooks(g)
    g.before_test('test_ordinal_changed', function()
        for _, instance in ipairs(g.cluster.servers) do
            instance:exec(function()
                rawset(_G, 'test_etcd2_client_ordinal_errnj', true)
            end)
        end
    end)

    g.after_test('test_ordinal_changed', function()
        for _, instance in ipairs(g.cluster.servers) do
            instance:exec(function()
                rawset(_G, 'test_etcd2_client_ordinal_errnj', nil)
            end)
        end
    end)
end

add_stateboard_hooks(g_stateboard)
add_stateboard_hooks(g_manual_stateboard)
add_etcd2_hooks(g_etcd2)
add_etcd2_hooks(g_manual_etcd2)

add('test_ordinal_changed', function(g)
    local promote_to_replicas = {
        [storage1_uuid] = storage1_2_uuid,
        [storage2_uuid] = storage2_2_uuid,
    }

    helpers.retrying({}, function()
        local ok, err = g.coordinator:eval(q_promote, {
            promote_to_replicas,
            {force_inconsistency = false}
        })
        t.assert_equals(ok, true, err)
        t.assert_not(err)
    end)

    assert_promoted_leaders(g, promote_to_replicas)

    local promote_back = {
        [core_uuid] = core_1_uuid,
        [storage1_uuid] = storage1_1_uuid,
        [storage2_uuid] = storage2_1_uuid,
    }

    local ok, err = g.coordinator:eval(q_promote, {
        promote_back,
        {
            force_inconsistency = true,
            skip_error_on_change = g.is_etcd2,
        }
    })
    t.assert_equals(ok, true, err)
    t.assert_not(err)

    assert_promoted_leaders(g, {
        [storage1_uuid] = storage1_1_uuid,
        [storage2_uuid] = storage2_1_uuid,
    })
end)
