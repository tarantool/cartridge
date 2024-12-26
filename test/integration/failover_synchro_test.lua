local fio = require('fio')

local t = require('luatest')

local g_etcd2 = t.group('integration.failover_synchro.etcd2')
local g_stateboard = t.group('integration.failover_synchro.stateboard')

local h = require('test.helper')

local stateboard_client = require('cartridge.stateboard-client')
local etcd2_client = require('cartridge.etcd2-client')

local replicaset_uuid = h.uuid('b')
local storage_1_uuid = h.uuid('b', 'b', 1)
local storage_2_uuid = h.uuid('b', 'b', 2)
local storage_3_uuid = h.uuid('b', 'b', 3)

local function setup_cluster(g)
    local datadir = fio.tempdir()
    g.logfile = fio.pathjoin(datadir, 'localhost-13303', 'storage-2.log')
    g.cluster = h.Cluster:new({
        datadir = datadir,
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
                        env = {['TARANTOOL_LOG'] = g.logfile},
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

local function kill_server(g, alias)
    g.cluster:server(alias):stop()
end

local function start_server(g, alias)
    g.cluster:server(alias):start()
end

local function get_master(cluster, uuid)
    local response = cluster.main_server:graphql({
        query = [[
            query(
                $uuid: String!
            ){
                replicasets(uuid: $uuid) {
                    master { uuid }
                    active_master { uuid }
                }
            }
        ]],
        variables = {uuid = uuid}
    })
    local replicasets = response.data.replicasets
    assert(#replicasets == 1)
    local replicaset = replicasets[1]
    return {replicaset.master.uuid, replicaset.active_master.uuid}
end

local function before_each(g)
    h.retrying({timeout = 30}, function()
        t.assert_equals(h.list_cluster_issues(g.cluster.main_server), {})
    end)
    h.retrying({}, function()
        t.assert_equals(get_master(g.cluster, replicaset_uuid), {storage_1_uuid, storage_1_uuid})

        g.cluster:server('storage-1'):exec(function()
            if box.space.test:len() > 0 then
                box.space.test:truncate()
            end
        end)
    end)
end

g_etcd2.before_each = before_each
g_stateboard.before_each = before_each

local function find_alias_by_uuid(uuid)
    return ({
        [storage_1_uuid] = 'storage-1',
        [storage_2_uuid] = 'storage-2',
        [storage_3_uuid] = 'storage-3',
    })[uuid]
end

local function promote(cluster, storage_uuid)
    local resp = cluster.main_server:graphql({
        query = [[
        mutation(
                $replicaset_uuid: String!
                $instance_uuid: String!
            ) {
            cluster {
                failover_promote(
                    replicaset_uuid: $replicaset_uuid
                    instance_uuid: $instance_uuid
                )
            }
        }]],
        variables = {
            replicaset_uuid = replicaset_uuid,
            instance_uuid = storage_uuid,
        }
    })
    t.assert_type(resp['data'], 'table')
    t.assert_equals(resp['data']['cluster']['failover_promote'], true)
end

local function stateful_test(g)
    local res

    -- insert and get sharded data
    res = g.cluster.main_server:http_request('post', '/test?key=a', {json = {}, raise = false})
    t.assert_equals(res.status, 200)
    res = g.cluster.main_server:http_request('get', '/test?key=a', { raise = false })
    t.assert_equals(res.json, {})

    h.retrying({timeout = 20}, function()
        promote(g.cluster, storage_2_uuid)
    end)
    h.retrying({timeout = 20}, function()
        g.cluster:server(find_alias_by_uuid(storage_2_uuid)):exec(function()
            assert(box.info.ro == false)
            assert(box.info.synchro.queue.owner == box.info.id)
        end)
    end)

    kill_server(g, 'storage-2')

    local current_master
    h.retrying({timeout = 20}, function()
        -- wait until leadeship
        current_master = get_master(g.cluster, replicaset_uuid)[2]
        t.assert_not_equals(current_master, storage_2_uuid)
        g.cluster:server(find_alias_by_uuid(current_master)):exec(function()
            assert(box.info.ro == false)
            assert(box.info.synchro.queue.owner == box.info.id)
        end)
    end)

    -- insert and get sharded data again
    res = g.cluster.main_server:http_request('post', '/test?key=b', {json = {}, raise = false})
    t.assert_equals(res.status, 200)

    res = g.cluster.main_server:http_request('get', '/test?key=b', { raise = false })
    t.assert_equals(res.json, {})

    -- restart previous leader
    start_server(g, 'storage-2')
    g.cluster:wait_until_healthy()

    local new_master = get_master(g.cluster, replicaset_uuid)[2]
    t.assert_equals(current_master, new_master)

    kill_server(g, 'storage-2')
    kill_server(g, 'storage-3')
    -- syncro quorum is broken now
    h.retrying({timeout = 20}, function()
        t.assert_equals(get_master(g.cluster, replicaset_uuid), {storage_1_uuid, storage_1_uuid})
    end)

    -- we can't write to storage
    res = g.cluster.main_server:http_request('post', '/test?key=c', {json = {}, raise = false})
    t.assert_equals(res.status, 500)

    -- but still can read because master in vshard config is readable
    res = g.cluster.main_server:http_request('get', '/test?key=a', { raise = false })
    t.assert_equals(res.status, 200)
    t.assert_equals(res.json, {})

    start_server(g, 'storage-2')
    kill_server(g, 'storage-1')

    -- syncro quorum is broken now
    -- we can't write
    res = g.cluster.main_server:http_request('post', '/test?key=c', {json = {}, raise = false})
    t.assert_equals(res.status, 500)

    -- and can't read because vshard cfg send requests to killed storage-2
    res = g.cluster.main_server:http_request('get', '/test?key=a', { raise = false })
    t.assert_equals(res.status, 500)

    -- return everything in place
    start_server(g, 'storage-1')
    start_server(g, 'storage-3')

    h.retrying({timeout = 20}, function()
        promote(g.cluster, storage_1_uuid)
    end)
end

local function promote_errors_test(g)
    g.cluster:wait_until_healthy()
    local test_message = 'test promote error'
    for _, alias in ipairs({'storage-1', 'storage-2', 'storage-3'}) do
        g.cluster:server(alias):exec(function(test_message)
            local old_promote = box.ctl.promote
            rawset(box.ctl, 'promote', function()
                error(test_message)
            end)
            rawset(_G, 'old_promote', old_promote)
        end, {test_message})
    end

    pcall(promote, g.cluster, storage_2_uuid)

    t.assert(g.cluster:server('storage-2'):grep_log(test_message, nil, {filename = g.logfile}), g.logfile)

    for _, alias in ipairs({'storage-1', 'storage-2', 'storage-3'}) do
        g.cluster:server(alias):exec(function()
            rawset(box.ctl, 'promote', rawget(_G, 'old_promote'))
        end)
    end
    h.retrying({timeout = 20}, function()
        promote(g.cluster, storage_1_uuid)
    end)
end

g_stateboard.before_all(function()
    t.skip_if(not h.tarantool_version_ge('2.6.1'))
    local g = g_stateboard
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

g_stateboard.test_kill_master_stateboard = stateful_test
g_stateboard.test_promote_errors = promote_errors_test

g_stateboard.after_all(function(g)
    g.state_provider:stop()
    fio.rmtree(g.state_provider.workdir)
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

g_etcd2.before_all(function()
    t.skip_if(not h.tarantool_version_ge('2.6.1'))
    local g = g_etcd2
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

g_etcd2.test_kill_master = stateful_test
g_etcd2.test_promote_errors = promote_errors_test

g_etcd2.after_all(function(g)
    g.state_provider:stop()
    fio.rmtree(g.state_provider.workdir)
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)
