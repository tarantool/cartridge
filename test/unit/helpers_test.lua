#!/usr/bin/env tarantool

local t = require('luatest')
local g = t.group()

local fio = require('fio')
local yaml = require('yaml')
local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        failover = 'stateful',
        stateboard_entrypoint = helpers.entrypoint('srv_stateboard'),
        cookie = require('digest').urandom(6):hex(),
        base_http_port = 8080,
        base_advertise_port = 13300,
        swim_period = 0.314,
        replicasets = {
            {
                alias = 'vshard',
                roles = {'vshard-router', 'vshard-storage', 'failover-coordinator'},
                servers = 1,
            },
            {
                alias = 'myrole',
                roles = {'myrole'},
                servers = 2
            },
        },
    })

    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function build_cluster(config)
    config.datadir = '/tmp'
    config.server_command = 'true'
    return helpers.Cluster:new(config)
end

function g.test_server_by_role()
    local cluster = build_cluster({replicasets = {
        {roles = {'vshard-router', 'vshard-storage'}, alias = 'vshard', servers = 1},
        {roles = {'my-role'}, alias = 'myrole', servers = {
            {alias = 'custom-alias'},
            {},
        }},
    }})

    t.assert_equals(cluster:server_by_role('vshard-router'), cluster.servers[1])
    t.assert_equals(cluster:server_by_role('vshard-storage'), cluster.servers[1])
    t.assert_equals(cluster:server_by_role('my-role'), cluster.servers[2])
end

function g.test_servers_by_role()
    local cluster = build_cluster({replicasets = {
        {roles = {'vshard-router', 'vshard-storage'}, alias = 'vshard', servers = 2},
        {roles = {'my-role'}, alias = 'myrole', servers = 2},
    }})

    t.assert_equals(cluster:servers_by_role('vshard-router'), {cluster.servers[1], cluster.servers[2]})
    t.assert_equals(cluster:servers_by_role('vshard-storage'), {cluster.servers[1], cluster.servers[2]})
    t.assert_equals(cluster:servers_by_role('my-role'), {cluster.servers[3], cluster.servers[4]})
end

function g.test_cluster_bootstrap()
    for i, server in ipairs(g.cluster.servers) do
        t.assert_equals(type(server.process.pid), 'number', 'Server ' .. i .. ' not started')
    end
end

function g.test_config_management()
    g.cluster:upload_config({some_section = 'some_value'})
    t.assert_covers(g.cluster:download_config(), {some_section = 'some_value'})

    g.cluster:upload_config(yaml.encode({another_section = 'some_value2'}))
    t.assert_covers(g.cluster:download_config(), {another_section = 'some_value2'})
end

function g.test_invalid_config()
    local response = g.cluster:upload_config("", { raise = false })
    t.assert_equals(response.status, 400)
end

function g.test_servers_access()
    local cluster = build_cluster({replicasets = {
        {roles = {}, alias = 'vshard', servers = 1},
        {roles = {}, alias = 'myrole', servers = {
            {alias = 'custom-alias'},
            {},
        }},
    }})
    t.assert_equals(#cluster.servers, 3)
    t.assert_equals(cluster:server('vshard-1'), cluster.servers[1])
    t.assert_equals(cluster:server('custom-alias'), cluster.servers[2])
    t.assert_equals(cluster:server('myrole-2'), cluster.servers[3])
    t.assert_error_msg_contains('Server myrole-3 not found', function()
        g.cluster:server('myrole-3')
    end)
end

function g.test_replicaset_uuid_generation()
    local uuids = {}
    for _ = 1, 2 do
        local cluster = build_cluster({replicasets = {
            {roles = {}, servers = {{}}, alias = ''},
            {roles = {}, servers = {{}}, alias = ''},
        }})
        for i = 1, 2 do
            local uuid = cluster.replicasets[i].uuid
            t.assert_not(uuids[uuid], 'Generated uuid is not unique: ' .. uuid)
            uuids[uuid] = true
        end
    end
end

local function get_failover(cluster)
    return cluster.main_server:call(
        'package.loaded.cartridge.failover_get_params')
end

function g.test_failover()
    t.assert_equals(get_failover(g.cluster).mode, 'stateful')
    t.assert(g.cluster.stateboard)

    local coordinator = g.cluster:server('vshard-1')
    t.assert_equals(g.cluster.stateboard:call('get_coordinator'),
        {uri = coordinator.advertise_uri, uuid = coordinator.instance_uuid})

    t.assert_error_msg_contains(
        "failover must be 'disabled', 'eventual' or 'stateful'",
        build_cluster, {
        replicasets = {{roles = {}, servers = 1, alias = ''}},
        failover = 'thebest'
    })

    t.assert_error_msg_contains(
        "stateboard_entrypoint required for stateful failover",
        build_cluster, {
        replicasets = {{roles = {}, servers = 1, alias = ''}},
        failover = 'stateful',
    })

    -- t.assert_error_msg_contains(
    --     "fake: no such stateboard_entrypoint",
    --     build_cluster, {
    --     replicasets = {{roles = {}, servers = 1, alias = ''}},
    --     failover = 'stateful',
    --     stateboard_entrypoint = 'fake'
    -- })
end

function g.test_new_with_servers_count()
    local cluster = build_cluster({replicasets = {
        {roles = {}, servers = 2, alias = 'router'},
        {roles = {}, servers = 3, alias = 'storage'},
    }})
    t.assert_equals(#cluster.replicasets[1].servers, 2)
    t.assert_equals(#cluster.replicasets[2].servers, 3)
    t.assert_covers(cluster.servers[1], {alias = 'router-1'})
    t.assert_covers(cluster.servers[2], {alias = 'router-2'})
    t.assert_covers(cluster.servers[3], {alias = 'storage-1'})
    t.assert_covers(cluster.servers[5], {alias = 'storage-3'})

    t.assert_error_msg_contains('servers count must be positive', build_cluster, {replicasets = {
        {roles = {}, servers = 0, alias = 'router'},
    }})
    t.assert_error_msg_contains('servers count must be positive', build_cluster, {replicasets = {
        {roles = {}, servers = -10, alias = 'router'},
    }})
end

function g.test_new_without_replicaset_and_server_alias()
    t.assert_error_msg_contains('Either replicaset.alias or server.alias must be given',
        build_cluster, {replicasets = {
            {roles = {}, servers = 2},
        }}
    )
end

function g.test_new_with_env()
    local shared_env = {
        SHARED_ENV_1 = 's-val-1',
        SHARED_ENV_2 = 's-val-2',
    }
    local cluster = build_cluster({
        env = shared_env,
        replicasets = {
            {uuid = 'r1', roles = {}, servers = {
                {alias = 's1'},
                {alias = 's2', env = {LOCAL_ENV = 'l-val', SHARED_ENV_2 = 'override'}},
            }},
            {uuid = 'r2', roles = {}, servers = {
                {alias = 's3', env = {}},
            }},
        }
    })
    t.assert_covers(cluster.servers[1].env, shared_env)
    local expected = table.copy(shared_env)
    expected.LOCAL_ENV = 'l-val'
    expected.SHARED_ENV_2 = 'override'
    t.assert_covers(cluster.servers[2].env, expected)
    t.assert_covers(cluster.servers[3].env, shared_env)
end

function g.test_errno()
    local errno = require('errno')
    t.assert_error_msg_contains(
        "errno 'ENOSUCHERRNO' is not declared",
        function() return errno.ENOSUCHERRNO end
    )
end

function g.test_swim_period()
    local period = g.cluster.main_server:eval([[
        return package.loaded['membership.options'].PROTOCOL_PERIOD_SECONDS
    ]])

    t.assert_equals(period, 0.314)
end
