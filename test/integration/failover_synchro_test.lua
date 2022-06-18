local fio = require('fio')

local t = require('luatest')
local g = t.group()
local h = require('test.helper')

local stateboard_client = require('cartridge.stateboard-client')
local etcd2_client = require('cartridge.etcd2-client')

local replicaset_uuid = h.uuid('b')
local storage_1_uuid = h.uuid('b', 'b', 1)
local storage_2_uuid = h.uuid('b', 'b', 2)
local storage_3_uuid = h.uuid('b', 'b', 3)

g.before_all = function()
    t.skip_if(not h.tarantool_version_ge('2.6.1'))
    g.cluster = h.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = h.entrypoint('srv_raft'),
        cookie = h.random_cookie(),
        replicasets = {
            {
                alias = 'router',
                uuid = h.uuid('a'),
                roles = {
                    'vshard-router',
                    'test.roles.api',
                    'failover-coordinator',
                },
                servers = {
                    {instance_uuid = h.uuid('a', 'a', 1)},
                },
            },
            {
                alias = 'storage',
                uuid = replicaset_uuid,
                roles = {
                    'vshard-storage',
                    'test.roles.storage',
                },
                servers = {
                    {
                        instance_uuid = storage_1_uuid,
                    },
                    {
                        instance_uuid = storage_2_uuid,
                    },
                    {
                        instance_uuid = storage_3_uuid,
                    },
                },
            },
        },
        env = {
            TARANTOOL_REPLICATION_SYNCHRO_QUORUM = 'N/2 + 1',
        }
    })
    g.cluster:start()

    g.cluster:server('storage-1'):exec(function()
        box.space.test:alter{is_sync = true}
    end)
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function kill_server(alias)
    g.cluster:server(alias):stop()
end

local function start_server(alias)
    g.cluster:server(alias):start()
end

g.before_each(function()
    h.retrying({timeout = 30}, function()
        t.assert_equals(h.list_cluster_issues(g.cluster.main_server), {})
    end)
    h.retrying({}, function()
        t.assert_equals(h.get_master(g.cluster, replicaset_uuid), {storage_1_uuid, storage_1_uuid})

        g.cluster:server('storage-1'):exec(function()
            if box.space.test:len() > 0 then
                box.space.test:truncate()
            end
        end)
    end)
end)

g.after_each(function()
    h.retrying({}, function()
        t.assert_covers(h.set_failover_params(g.cluster, { mode = 'disabled' }), { mode = 'disabled' })
    end)
end)

local function find_alias_by_uuid(uuid)
    return ({
        [storage_1_uuid] = 'storage-1',
        [storage_2_uuid] = 'storage-2',
        [storage_3_uuid] = 'storage-3',
    })[uuid]
end

local function stateful_test()
    local res

    -- insert and get sharded data
    res = g.cluster.main_server:http_request('post', '/test?key=a', {json = {}, raise = false})
    t.assert_equals(res.status, 200)
    res = g.cluster.main_server:http_request('get', '/test?key=a', { raise = false })
    t.assert_equals(res.json, {})

    kill_server('storage-1')

    local current_master
    h.retrying({timeout = 20}, function()
        -- wait until leadeship
        current_master = h.get_master(g.cluster, replicaset_uuid)[2]
        t.assert_not_equals(current_master, storage_1_uuid)
        g.cluster:server(find_alias_by_uuid(current_master)):exec(function()
            assert(box.info.ro == false)
        end)
    end)

    -- insert and get sharded data again
    res = g.cluster.main_server:http_request('post', '/test?key=b', {json = {}, raise = false})
    t.assert_equals(res.status, 200)

    res = g.cluster.main_server:http_request('get', '/test?key=b', { raise = false })
    t.assert_equals(res.json, {})

    -- restart previous leader
    start_server('storage-1')
    g.cluster:wait_until_healthy()

    local new_master = h.get_master(g.cluster, replicaset_uuid)[2]
    t.assert_equals(current_master, new_master)

    kill_server('storage-1')
    kill_server('storage-3')
    -- syncro quorum is broken now
    h.retrying({timeout = 20}, function()
        t.assert_equals(h.get_master(g.cluster, replicaset_uuid), {storage_2_uuid, storage_2_uuid})
    end)

    -- we can't write to storage
    res = g.cluster.main_server:http_request('post', '/test?key=c', {json = {}, raise = false})
    t.assert_equals(res.status, 500)

    -- but still can read because master in vshard config is readable
    res = g.cluster.main_server:http_request('get', '/test?key=a', { raise = false })
    t.assert_equals(res.status, 200)
    t.assert_equals(res.json, {})


    start_server('storage-3')
    kill_server('storage-2')

    -- syncro quorum is broken now
    -- we can't write
    res = g.cluster.main_server:http_request('post', '/test?key=c', {json = {}, raise = false})
    t.assert_equals(res.status, 500)

    -- and can't read because vshard cfg send requests to killed storage-2
    res = g.cluster.main_server:http_request('get', '/test?key=a', { raise = false })
    t.assert_equals(res.status, 500)

    start_server('storage-1')
    start_server('storage-2')
end

g.before_test('test_kill_master_stateboard', function()
    g.datadir = fio.tempdir()

    g.kvpassword = h.random_cookie()
    g.state_provider = h.Stateboard:new({
        command = h.entrypoint('srv_stateboard'),
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

g.test_kill_master_stateboard = stateful_test

g.after_test('test_kill_master_stateboard', function()
    g.state_provider:stop()
    fio.rmtree(g.state_provider.workdir)
end)

g.before_test('test_kill_master_etcd', function()
    local etcd_path = os.getenv('ETCD_PATH')
    t.skip_if(etcd_path == nil, 'etcd missing')

    local URI = 'http://127.0.0.1:14001'
    g.datadir = fio.tempdir()
    g.state_provider = h.Etcd:new({
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

g.test_kill_master_etcd = stateful_test

g.after_test('test_kill_master_etcd', function()
    g.state_provider:stop()
    fio.rmtree(g.state_provider.workdir)
end)
