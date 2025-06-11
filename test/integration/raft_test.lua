local fio = require('fio')
local fun = require('fun')

local t = require('luatest')
local g = t.group()
local g_unsupported = t.group('integration.raft_unsupported')
local g_not_enough_instances = t.group('integration.raft_not_enough_instances')
local g_unelectable = t.group('integration.raft_unelectable')
local g_disable = t.group('integration.raft_disabled_instances')
local g_expel = t.group('integration.raft_expelled_instances')
local g_appointments = t.group('integration.raft_appointments')
local g_all_rw = t.group('integration.raft_all_rw')
local h = require('test.helper')

local replicaset_uuid = h.uuid('b')
local storage_1_uuid = h.uuid('b', 'b', 1)
local storage_2_uuid = h.uuid('b', 'b', 2)
local storage_3_uuid = h.uuid('b', 'b', 3)
local single_replicaset_uuid = h.uuid('c')
local single_storage_uuid = h.uuid('c', 'c', 1)

local function set_failover_params(group, vars)
    local response = group.cluster.main_server:graphql({
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

local function get_election_cfg(group, alias)
    return group.cluster:server(alias):exec(function()
        return box.cfg.election_mode
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
    g.cluster:wait_until_healthy()
    t.assert_equals(set_failover_params(g, { mode = 'raft' }), { mode = 'raft' })

    t.assert_equals(get_election_cfg(g, 'router-1'), 'off')
    t.assert_equals(get_election_cfg(g, 'storage-1'), 'candidate')
    t.assert_equals(get_election_cfg(g, 'storage-2'), 'candidate')
    t.assert_equals(get_election_cfg(g, 'storage-3'), 'voter')
    t.assert_equals(get_election_cfg(g, 'single-storage-1'), 'off')

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
    -- syncro quorum is broken now
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

    -- syncro qourum is broken now
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
    g.cluster:wait_until_healthy()

    local after_2pc = get_2pc_count()

    -- assert that 2pc doesn't called while raft failovering
    t.assert_equals(before_2pc, after_2pc)
end

local q_leadership = string.format([[
    local failover = require('cartridge.failover')
    return failover.get_active_leaders()[%q]
]], replicaset_uuid)

local q_promote = [[
    return require('cartridge').failover_promote(...)
]]

g.test_promote = function()
    -- since box.ctl.promote starts fair election, we need retrying in tests to promote a leader
    h.retrying({timeout = 10}, function()
        local resp = g.cluster.main_server:graphql({
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
                instance_uuid = storage_2_uuid,
            }
        })
        t.assert_type(resp['data'], 'table')
        t.assert_equals(resp['data']['cluster']['failover_promote'], true)

        t.assert_equals(g.cluster:server('storage-1'):eval(q_leadership), storage_2_uuid)
        t.assert_equals(g.cluster:server('storage-2'):eval(q_leadership), storage_2_uuid)
        t.assert_equals(g.cluster:server('storage-3'):eval(q_leadership), storage_2_uuid)
        t.assert_equals(g.cluster:server('router-1'):eval(q_leadership), storage_2_uuid)
        t.assert_equals(g.cluster:server('single-storage-1'):eval(q_leadership), storage_2_uuid)
    end)
end

g.test_promote_errors = function()
    local ok, err = g.cluster.main_server:eval(q_promote, {{[replicaset_uuid] = 'invalid_uuid'}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'AppointmentError',
        err = [[Server "invalid_uuid" doesn't exist]],
    })

    local ok, err = g.cluster.main_server:eval(q_promote, {{['invalid_uuid'] = storage_1_uuid}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'AppointmentError',
        err = [[Replicaset "invalid_uuid" doesn't exist]],
    })

    local ok, err = g.cluster.main_server:eval(q_promote, {{[single_replicaset_uuid] = storage_1_uuid}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'AppointmentError',
        err = string.format(
            [[Server %q doesn't belong to replicaset %q]],
            storage_1_uuid, single_replicaset_uuid
        ),
    })
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

----------------------------------------------------------------

g_unsupported.before_all = function()
    t.skip_if(h.tarantool_version_ge('2.10.0'))
    g_unsupported.cluster = h.Cluster:new({
        datadir = fio.tempdir(),
        server_command = h.entrypoint('srv_raft'),
        cookie = h.random_cookie(),
        replicasets = {
            {
                alias = 'replicaset',
                roles = {},
                servers = 1,
            },
        }
    })
    g_unsupported.cluster:start()
end

g_unsupported.after_all = function()
    g_unsupported.cluster:stop()
    fio.rmtree(g_unsupported.cluster.datadir)
end

g_unsupported.test_tarantool_version_unsupported = function()
    t.assert_error_msg_contains(
        "Your Tarantool version doesn't support raft failover mode, need Tarantool 2.10 or higher",
        set_failover_params, g_unsupported, { mode = 'raft' })
    t.assert_equals(g_unsupported.cluster.main_server:exec(function()
        return require('cartridge.confapplier').get_state()
    end), 'RolesConfigured')
end

----------------------------------------------------------------

local function setup_group(g, replicasets)
    g.before_all = function()
        t.skip_if(not h.tarantool_version_ge('2.10.0'))
        g.cluster = h.Cluster:new({
            datadir = fio.tempdir(),
            use_vshard = true,
            server_command = h.entrypoint('srv_basic'),
            cookie = h.random_cookie(),
            replicasets = replicasets,
            env = {
                TARANTOOL_ELECTION_TIMEOUT = 1,
                TARANTOOL_REPLICATION_TIMEOUT = 0.25,
                TARANTOOL_SYNCHRO_TIMEOUT = 1,
                TARANTOOL_REPLICATION_SYNCHRO_QUORUM = 'N/2 + 1',
            }
        })
        g.cluster:start()
    end

    g.after_all = function()
        g.cluster:stop()
        fio.rmtree(g.cluster.datadir)
    end
end

----------------------------------------------------------------

setup_group(g_not_enough_instances, {
    {
        alias = 'router',
        uuid = h.uuid('a'),
        roles = {
            'vshard-router',
        },
        servers = 1,
    },
    {
        alias = 'storage',
        uuid = replicaset_uuid,
        roles = {
            'vshard-storage',
        },
        servers = 2,
    },
})

g_not_enough_instances.test_raft_is_disabled = function()
    t.assert_equals(set_failover_params(g_not_enough_instances, { mode = 'raft' }), { mode = 'raft' })
    t.assert_not(g_not_enough_instances.cluster:server('router-1'):exec(function()
        return box.info.ro
    end))
    t.assert_equals(get_election_cfg(g_not_enough_instances, 'router-1'), 'off')

    t.assert_not(g_not_enough_instances.cluster:server('storage-1'):exec(function()
        return box.info.ro
    end))
    t.assert_equals(get_election_cfg(g_not_enough_instances, 'storage-1'), 'off')

    t.assert(g_not_enough_instances.cluster:server('storage-2'):exec(function()
        return box.info.ro
    end))
    t.assert_equals(get_election_cfg(g_not_enough_instances, 'storage-2'), 'off')
end

----------------------------------------------------------------

setup_group(g_unelectable, {
    {
        alias = 'router',
        uuid = h.uuid('a'),
        roles = {
            'vshard-router',
        },
        servers = 1,
    },
    {
        alias = 'storage',
        uuid = replicaset_uuid,
        roles = {
            'vshard-storage',
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
})

g_unelectable.test_raft_is_disabled = function()
    t.assert_equals(set_failover_params(g_unelectable, { mode = 'raft' }), { mode = 'raft' })

    t.assert_equals(get_election_cfg(g_unelectable, 'storage-1'), 'candidate')

    t.assert_equals(get_election_cfg(g_unelectable, 'storage-2'), 'candidate')

    t.assert_equals(get_election_cfg(g_unelectable, 'storage-3'), 'candidate')

    g_unelectable.cluster.main_server:exec(function(uuids)
        local api_topology = require('cartridge.lua-api.topology')
        api_topology.set_unelectable_servers(uuids)
    end, {{storage_3_uuid}})

    t.assert_equals(get_election_cfg(g_unelectable, 'storage-1'), 'candidate')
    t.assert_equals(get_election_cfg(g_unelectable, 'storage-2'), 'candidate')
    t.assert_equals(get_election_cfg(g_unelectable, 'storage-3'), 'voter')
end

----------------------------------------------------------------

setup_group(g_disable, {
    {
        alias = 'router',
        uuid = h.uuid('a'),
        roles = {
            'vshard-router',
        },
        servers = 1,
    },
    {
        alias = 'storage',
        uuid = replicaset_uuid,
        roles = {
            'vshard-storage',
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
})

g_disable.test_raft_is_disabled = function()
    t.assert_equals(set_failover_params(g_disable, { mode = 'raft' }), { mode = 'raft' })

    t.assert_equals(get_election_cfg(g_disable, 'storage-1'), 'candidate')

    t.assert_equals(get_election_cfg(g_disable, 'storage-2'), 'candidate')

    t.assert_equals(get_election_cfg(g_disable, 'storage-3'), 'candidate')

    g_disable.cluster.main_server:exec(function(uuid)
        require('cartridge.lua-api.topology').disable_servers({uuid})
    end, {storage_3_uuid})
    t.assert_equals(get_election_cfg(g_disable, 'storage-1'), 'off')
    t.assert_equals(get_election_cfg(g_disable, 'storage-2'), 'off')
end

----------------------------------------------------------------

setup_group(g_expel, {
    {
        alias = 'router',
        uuid = h.uuid('a'),
        roles = {
            'vshard-router',
        },
        servers = 1,
    },
    {
        alias = 'storage',
        uuid = replicaset_uuid,
        roles = {
            'vshard-storage',
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
})

g_expel.test_raft_is_disabled = function()
    t.assert_equals(set_failover_params(g_expel, { mode = 'raft' }), { mode = 'raft' })

    t.assert_equals(get_election_cfg(g_expel, 'storage-1'), 'candidate')

    t.assert_equals(get_election_cfg(g_expel, 'storage-2'), 'candidate')

    t.assert_equals(get_election_cfg(g_expel, 'storage-3'), 'candidate')

    g_expel.cluster:retrying({}, function()
        g_expel.cluster:server('storage-1'):call('box.ctl.promote')
        -- here we call box.ctl.promote manually to promote rw instance
    end)

    g_expel.cluster:server('storage-3'):stop()
    g_expel.cluster.main_server:exec(function(uuid)
        require('cartridge.lua-api.topology').edit_topology({
            servers = {{
                uuid = uuid,
                expelled = true,
            }}
        })
    end, {storage_3_uuid})
    g_expel.cluster:retrying({timeout = 10}, function()
        t.assert_equals(get_election_cfg(g_expel, 'storage-1'), 'off')
        t.assert_equals(get_election_cfg(g_expel, 'storage-2'), 'off')
        t.assert(pcall(function()
            g_expel.cluster:server('storage-1'):exec(function()
                assert(box.info.ro == false)
            end)
        end))
    end)
end

g_expel.after_test('test_raft_is_disabled', function()
    g_expel.cluster:server('storage-1'):exec(function()
        local confapplier = require('cartridge.confapplier')
        local topology = require('cartridge.topology')
        local topology_cfg = confapplier.get_readonly('topology')
        local fun = require('fun')
        for _, uuid, _ in fun.filter(topology.expelled, topology_cfg.servers) do
            box.space._cluster.index.uuid:delete(uuid)
        end
    end)
end)

----------------------------------------------------------------

setup_group(g_all_rw, {
    {
        alias = 'router',
        uuid = h.uuid('a'),
        roles = {
            'vshard-router',
        },
        servers = 1,
    },
    {
        alias = 'storage',
        uuid = replicaset_uuid,
        roles = {
            'vshard-storage',
        },
        servers = 3,
        all_rw = true,
    },
})

g_all_rw.test_raft_in_all_rw_mode_fails = function()
    t.assert_error_msg_contains(
        "Raft failover can't be enabled with ALL_RW replicasets",
        set_failover_params, g_all_rw, { mode = 'raft' })
    t.assert_equals(g_all_rw.cluster.main_server:exec(function()
        return require('cartridge.confapplier').get_state()
    end), 'RolesConfigured')
end

----------------------------------------------------------------

setup_group(g_appointments, {
    {
        alias = 'router',
        uuid = h.uuid('a'),
        roles = {
            'vshard-router',
            'myrole',
        },
        servers = 1,
    },
    {
        alias = 'storage',
        uuid = replicaset_uuid,
        roles = {
            'vshard-storage',
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
        }
    },
})

g_appointments.before_each(function()
    t.assert_equals(set_failover_params(g_appointments, { mode = 'raft' }), { mode = 'raft' })
end)

g_appointments.after_each(function()
    -- return original leader
    g_appointments.cluster:retrying({}, function()
        g_appointments.cluster:server('storage-1'):call('box.ctl.promote')
    end)

    h.retrying({}, function()
        t.assert_equals(g_appointments.cluster:server('storage-1'):eval(q_leadership), storage_1_uuid)
    end)
end)

g_appointments.test_leader_persists_after_config_apply = function()
    -- There was a bug with leader selection when Raft failover was enabled
    -- on replicasets with fewer than 3 instances.
    -- Raft is disabled on such replicasets. These were often routers.
    -- As a result, the wrong storages were elected as masters,
    -- and vshard returned a NON_MASTER error.
    -- The bug is reproduced as follows:
    -- 1. Change the leader in the replica set
    -- 2. After the leader change, the router learns about the new leader via membership
    -- 3. Apply a config update, which triggers failover.cfg
    -- 4. The router incorrectly determines the leader and sets the old master as the leader,
    --    because it appears first in the topology (lexicographically), as in 'disabled' mode.

    -- Step 1: change the leader in the replica set
    g_appointments.cluster:retrying({}, function()
        g_appointments.cluster:server('storage-2'):call('box.ctl.promote')
    end)

    local storage_rs_uuid = g_appointments.cluster:server('storage-1').replicaset_uuid

    local leader_switched_index
    -- Step 2: wait for the router to update the leader via membership after the master change
    h.retrying({}, function()
        local res = g_appointments.cluster:server('router-1'):exec(function()
            local cartridge = require('cartridge')
            return cartridge.service_get('myrole').get_leaders_history()
        end)

        leader_switched_index = #res
        t.assert_equals(res[leader_switched_index][storage_rs_uuid], storage_2_uuid)
    end)

    -- Step 3: Apply new config to simulate a configuration change and trigger apply_config
    g_appointments.cluster:server('router-1'):exec(function()
        return require("cartridge").config_patch_clusterwide({uuid = require("uuid").str()})
    end)

    h.wish_state(g_appointments.cluster:server('router-1'), 'RolesConfigured', 10)

    -- Step 4: Check the updated leaders on the router
    -- Ensure the leader did not revert from storage-2 back to storage-1
    h.retrying({}, function()
        local res = g_appointments.cluster:server('router-1'):exec(function()
            local cartridge = require('cartridge')
            return cartridge.service_get('myrole').get_leaders_history()
        end)

        t.assert(#res > leader_switched_index, 'Wait for failover.cfg to be called again after config apply')
        for i = leader_switched_index, #res do
            local leader_list = res[i]
            -- After the switch, storage-2 must remain the leader
            t.assert_equals(leader_list[storage_rs_uuid], storage_2_uuid)
        end
    end)
end

g_appointments.test_on_small_replicaset = function()
    -- Check that if there are fewer than 3 instances in the replicaset,
    -- the router behaves as in 'disabled' failover mode and appoints
    -- the first (lexicographically) enabled instance as leader.

    -- change master, 
    g_appointments.cluster:retrying({}, function()
        g_appointments.cluster:server('storage-2'):call('box.ctl.promote')
    end)

    h.retrying({}, function()
        t.assert_equals(g_appointments.cluster:server('router-1'):eval(q_leadership), storage_2_uuid)
    end)

    -- Disable one instance to simulate a small replicaset (<3 instances)
    g_appointments.cluster.main_server:exec(function(uuid)
        require('cartridge.lua-api.topology').disable_servers({uuid})
    end, {storage_2_uuid})

    h.wish_state(g_appointments.cluster:server('router-1'), 'RolesConfigured', 10)

    h.retrying({}, function()
        -- storage-1 should be appointed as leader on router, as in 'disabled' mode
        t.assert_equals(g_appointments.cluster:server('router-1'):eval(q_leadership), storage_1_uuid)
    end)
end
