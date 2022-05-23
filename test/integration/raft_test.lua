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
    t.skip_if(not h.tarantool_version_ge('2.10.0'))
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
                        env = {
                            TARANTOOL_ELECTION_MODE = 'voter',
                        },
                    },
                },
            },
            {
                alias = 'single-storage',
                uuid = single_replicaset_uuid,
                roles = {},
                servers = {
                    {
                        instance_uuid = single_storage_uuid,
                        env = {
                            TARANTOOL_ELECTION_MODE = 'off',
                        },
                    },
                },
            },
        },
        env = {
            TARANTOOL_ELECTION_TIMEOUT = 1,
            TARANTOOL_REPLICATION_TIMEOUT = 0.25,
            TARANTOOL_SYNCHRO_TIMEOUT = 1,
            TARANTOOL_REPLICATION_SYNCHRO_QUORUM = 'N/2 + 1',
        }
    })
    g.cluster:start()

    g.cluster.main_server:setup_replicaset({
        roles = {'vshard-storage', 'test.roles.storage'},
        weight = 0,
        uuid = single_replicaset_uuid,
    })
    -- make single vshard-storage writable
    g.cluster:server('single-storage-1'):exec(function()
        box.cfg{replication_synchro_quorum = 1}
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

local function get_raft_info(alias)
    return g.cluster:server(alias):exec(function()
        return box.info.election
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

local function get_2pc_count()
    local counts = {}
    for _, server in ipairs(g.cluster.servers) do
        table.insert(counts, server:exec(function()
            return _G['2pc_count']
        end))
    end
    return counts
end

local function get_sharding_config()
    local sharding = g.cluster:server('router-1'):exec(function()
        local vars = require('cartridge.vars').new('cartridge.roles.vshard-router')
        return vars.vshard_cfg['vshard-router/default'].sharding
    end)
    return fun.iter(sharding):map(function(x, y)
        return x, fun.iter(y.replicas):map(function(k, v)
            return k, {master = v.master}
        end):tomap()
    end):tomap()
end

g.before_each(function()
    h.retrying({}, function()
        t.assert_equals(set_failover_params({ mode = 'raft' }), { mode = 'raft' })
    end)
    h.retrying({}, function()
        t.assert_equals(h.list_cluster_issues(g.cluster.main_server), {})
    end)
    h.retrying({}, function()
        -- call box.ctl.promote on storage-1
        set_master('storage-1')
        -- assert that storage-1 is leader and anybody else is follower
        t.assert_equals(get_raft_info('storage-1').state, 'leader')
        t.assert_equals(get_raft_info('storage-2').state, 'follower')
        t.assert_equals(get_raft_info('storage-3').state, 'follower')

        -- assert that vshard-router has correct config
        t.assert_covers(get_sharding_config(),{
            [replicaset_uuid] = {
                [storage_1_uuid] = {master = true},
                [storage_2_uuid] = {master = false},
                [storage_3_uuid] = {master = false},
            },
        })
        t.assert_equals(get_master(replicaset_uuid), {storage_1_uuid, storage_1_uuid})

        g.cluster:server('storage-1'):exec(function()
            if box.space.test:len() > 0 then
                box.space.test:truncate()
            end
        end)
    end)
end)

g.before_test('test_kill_master', function()
    g.cluster:server('storage-1'):exec(function ()
        box.space.test:alter{is_sync = true}
    end)
end)

g.test_kill_master = function()
    local res
    -- count 2pc calls
    local before_2pc = get_2pc_count()

    -- insert and get sharded data
    res = g.cluster.main_server:http_request('post', '/test?key=a', {json = {}, raise = false})
    t.assert_equals(res.status, 200)
    res = g.cluster.main_server:http_request('get', '/test?key=a', { raise = false })
    t.assert_equals(res.json, {})

    kill_server('storage-1')

    h.retrying({timeout = 10}, function()
        -- wait until leadeship
        t.assert_equals(get_raft_info('storage-2').state, 'leader')
        t.assert_equals(get_raft_info('storage-3').state, 'follower')
        t.assert_covers(get_sharding_config(), {
            [replicaset_uuid] = {
                [storage_1_uuid] = {master = false},
                [storage_2_uuid] = {master = true},
                [storage_3_uuid] = {master = false},
            }
        })
        t.assert_equals(get_master(replicaset_uuid), {storage_2_uuid, storage_2_uuid})
    end)

    -- insert and get sharded data again
    res = g.cluster.main_server:http_request('post', '/test?key=b', {json = {}, raise = false})
    t.assert_equals(res.status, 200)

    res = g.cluster.main_server:http_request('get', '/test?key=b', { raise = false })
    t.assert_equals(res.json, {})

    -- restart previous leader
    start_server('storage-1')

    h.retrying({}, function()
        -- leader doesn't changed
        t.assert_equals(get_raft_info('storage-1').state, 'follower')
        t.assert_equals(get_raft_info('storage-2').state, 'leader')
        t.assert_equals(get_raft_info('storage-3').state, 'follower')

        t.assert_covers(get_sharding_config(), {
            [replicaset_uuid] = {
                [storage_1_uuid] = {master = false},
                [storage_2_uuid] = {master = true},
                [storage_3_uuid] = {master = false},
            }
        })
        t.assert_equals(get_master(replicaset_uuid), {storage_2_uuid, storage_2_uuid})
    end)

    kill_server('storage-1')
    kill_server('storage-3')
    -- syncro quorom is broken now
    h.retrying({}, function()
        -- vshard doesn't know that replicaset has no leader
        t.assert_covers(get_sharding_config(), {
            [replicaset_uuid] = {
                [storage_1_uuid] = {master = false},
                [storage_2_uuid] = {master = true},
                [storage_3_uuid] = {master = false},
            }
        })
        t.assert_equals(get_master(replicaset_uuid), {storage_2_uuid, storage_2_uuid})
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
    h.retrying({}, function()
        -- raft doesn't know that replicaset has no leader
        t.assert_equals(get_raft_info('storage-3').state, 'follower')

        -- that means vshard doesn't know that replicaset has no leader
        t.assert_covers(get_sharding_config(), {
            [replicaset_uuid] = {
                [storage_1_uuid] = {master = false},
                [storage_2_uuid] = {master = true},
                [storage_3_uuid] = {master = false},
            }
        })
        t.assert_equals(get_master(replicaset_uuid), {storage_2_uuid, storage_2_uuid})
    end)

    -- we can't write
    res = g.cluster.main_server:http_request('post', '/test?key=c', {json = {}, raise = false})
    t.assert_equals(res.status, 500)

    -- and can't read because vshard cfg send requests to killed storage-2
    res = g.cluster.main_server:http_request('get', '/test?key=a', { raise = false })
    t.assert_equals(res.status, 500)

    start_server('storage-1')
    start_server('storage-2')

    local after_2pc = get_2pc_count()

    -- assert that 2pc doesn't called while raft failovering
    t.assert_equals(before_2pc, after_2pc)
end

local kvpassword = require('digest').urandom(6):hex()
local failover_change = {
    {to = 'disabled', params = {}},
    {to = 'eventual', params = {}},
    {to = 'stateful', params = {
        state_provider = 'tarantool',
        tarantool_params = {
            uri = 'localhost:14401',
            password = kvpassword,
        }}
    }
}

for _, test_case in ipairs(failover_change) do
    g['test_change_raft_failover_to_' .. test_case.to] = function()
        local assertions = g.cluster:server('storage-1'):exec(function()
            return {
                #box.ctl.on_election(),
                box.cfg.election_mode,
                box.info.election.state,
            }
        end)
        t.assert_equals(assertions, {
            1,
            'candidate',
            'leader',
        })

        h.retrying({}, function ()
            t.assert(g.cluster.main_server:call(
            'package.loaded.cartridge.failover_set_params',
            {{
                mode = test_case.to,
                state_provider = test_case.params.state_provider,
                tarantool_params = test_case.params.tarantool_params,
            }}
        ))
        end)

        local assertions = g.cluster:server('router-1'):exec(function()
            return {
                #box.ctl.on_election(),
                box.cfg.election_mode,
                box.info.election.state,
            }
        end)
        t.assert_equals(assertions, {
            0,
            'off',
            'follower',
        })
    end
end

g.before_test('test_change_raft_failover_to_stateful', function()
    g.state_provider = h.Stateboard:new({
        command = h.entrypoint('srv_stateboard'),
        workdir = fio.pathjoin(g.cluster.datadir, 'stateboard'),
        net_box_port = 14401,
        net_box_credentials = {
            user = 'client',
            password = kvpassword,
        },
        env = {
            TARANTOOL_LOCK_DELAY = 2,
            TARANTOOL_PASSWORD = kvpassword,
        },
    })
    g.state_provider:start()
end)

g.after_test('test_change_raft_failover_to_stateful', function()
    g.state_provider:stop()
    fio.rmtree(g.state_provider.workdir)
end)
