local fio = require('fio')
local fun = require('fun')

local t = require('luatest')
local g = t.group()
local h = require('test.helper')

local replicaset_uuid = h.uuid('b')
local storage_1_uuid = h.uuid('b', 'b', 1)
local storage_2_uuid = h.uuid('b', 'b', 2)
local storage_3_uuid = h.uuid('b', 'b', 3)
local single_replicaset_uuid = h.uuid('c')
local single_storage_uuid = h.uuid('c', 'c', 1)

local function set_failover_params(vars)
    local response = g.cluster.main_server:graphql({
        query = [[
            mutation(
                $mode: String
            ) {
                cluster {
                    failover_params(
                        mode: $mode
                    ) {
                        mode
                    }
                }
            }
        ]],
        variables = vars,
        raise = false,
    })
    if response.errors then
        error(response.errors[1].message, 2)
    end
    return response.data.cluster.failover_params
end

g.before_all = function()
    t.skip_if(not h.tarantool_version_ge('2.6.1'))
    g.cluster = h.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = h.entrypoint('srv_raft'),
        cookie = 'secret',--h.random_cookie(),
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
    })
    g.cluster:start()

    g.cluster:server('storage-1'):exec(function ()
        box.space.test:alter{is_sync = true}
    end)
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function set_master(instance_name)
    g.cluster:server(instance_name):exec(function()
        box.ctl.promote()
    end)
end

local function kill_server(alias)
    g.cluster:server(alias):stop()
end

local function start_server(alias)
    g.cluster:server(alias):start()
end

local function get_master(uuid)
    local response = g.cluster.main_server:graphql({
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
    t.assert_equals(#replicasets, 1)
    local replicaset = replicasets[1]
    return {replicaset.master.uuid, replicaset.active_master.uuid}
end

g.before_each(function()
    h.retrying({}, function()
        t.assert_equals(h.list_cluster_issues(g.cluster.main_server), {})
    end)
    h.retrying({}, function()
        -- call box.ctl.promote on storage-1
        set_master('storage-1')

        t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_1_uuid})

        g.cluster:server('storage-1'):exec(function()
            if box.space.test:len() > 0 then
                box.space.test:truncate()
            end
        end)
    end)
end)

g.before_test('test_kill_master_eventual', function()
    h.retrying({}, function()
        t.assert_equals(set_failover_params({ mode = 'eventual' }), { mode = 'eventual' })
    end)
end)

g.test_kill_master_eventual = function()
    local res

    -- insert and get sharded data
    res = g.cluster.main_server:http_request('post', '/test?key=a', {json = {}, raise = false})
    t.assert_equals(res.status, 200)
    res = g.cluster.main_server:http_request('get', '/test?key=a', { raise = false })
    t.assert_equals(res.json, {})

    kill_server('storage-1')

    h.retrying({timeout = 10}, function()
        -- wait until leadeship
        t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_2_uuid})
        g.cluster:server('storage-2'):exec(function ()
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

    h.retrying({}, function()
        t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_1_uuid})
    end)

    kill_server('storage-1')
    kill_server('storage-3')
    -- syncro quorom is broken now
    h.retrying({}, function()
        t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_2_uuid})
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

    -- syncro qourom is broken now
    -- we can't write
    res = g.cluster.main_server:http_request('post', '/test?key=c', {json = {}, raise = false})
    t.assert_equals(res.status, 500)

    -- and can't read because vshard cfg send requests to killed storage-2
    res = g.cluster.main_server:http_request('get', '/test?key=a', { raise = false })
    t.assert_equals(res.status, 500)

    start_server('storage-1')
    start_server('storage-2')
end
