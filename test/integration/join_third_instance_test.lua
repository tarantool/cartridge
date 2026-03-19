local fio = require('fio')
local t = require('luatest')
local g = t.group('integration.join_third_instance')
local g_manual = t.group('integration.join_third_instance.manual_election')

local helpers = require('test.helper')

local replicaset_uuid = helpers.uuid('a')
local storage_3_uuid = helpers.uuid('a', 'a', 3)

local function setup(g, opts)
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        failover = 'stateful',
        stateboard_entrypoint = helpers.entrypoint('srv_stateboard'),
        env = opts.env,
        replicasets = {
            {
                alias = 'storage',
                uuid = replicaset_uuid,
                roles = {'failover-coordinator'},
                servers = 2,
            },
        },
    })

    g.server = helpers.Server:new({
        workdir = fio.tempdir(),
        command = helpers.entrypoint('srv_basic'),
        alias = 'storage-3',
        cluster_cookie = g.cluster.cookie,
        replicaset_uuid = replicaset_uuid,
        instance_uuid = storage_3_uuid,
        http_port = 8083,
        advertise_port = 13303,
        env = opts.env,
    })

    g.server:start()
    g.cluster:start()
end

local function cleanup(g)
    if g.server ~= nil then
        g.server:stop()
        fio.rmtree(g.server.workdir)
    end

    if g.cluster ~= nil then
        g.cluster:stop()
        fio.rmtree(g.cluster.datadir)
    end
end

g.before_all(function()
    setup(g, {})
end)

g.after_all(function()
    cleanup(g)
end)

g_manual.before_all(function()
    t.skip_if(not helpers.tarantool_supports_election_fencing_mode(),
        'Manual election release-1 tests require election_fencing_mode support')

    setup(g_manual, {
        env = {
            TARANTOOL_ELECTION_MODE = 'manual',
            TARANTOOL_ELECTION_FENCING_MODE = 'off',
        },
    })
end)

g_manual.after_all(function()
    cleanup(g_manual)
end)

local function test_join_third_storage(g)
    helpers.retrying({}, function()
        g.cluster.main_server:graphql({
            query = [[
                mutation(
                    $replicaset_uuid: String!
                    $instance_uuid: String!
                    $force: Boolean
                ) {
                cluster {
                    failover_promote(
                        replicaset_uuid: $replicaset_uuid
                        instance_uuid: $instance_uuid
                        force_inconsistency: $force
                    )
                }
            }]],
            variables = {
                replicaset_uuid = replicaset_uuid,
                instance_uuid = g.cluster.servers[2].instance_uuid,
                force = true,
            },
        })
    end)

    g.cluster:join_server(g.server)

    helpers.retrying({}, function()
        local state = g.cluster:server('storage-2'):exec(function()
            local failover = require('cartridge.failover')
            local synchro = box.info.synchro or {}
            local queue = synchro.queue or {}

            return {
                is_leader = failover.is_leader(),
                is_ro = box.info.ro,
                synchro_owner = queue.owner,
                id = box.info.id,
            }
        end)

        t.assert_equals(state.is_leader, true)
        t.assert_equals(state.is_ro, false)
        if helpers.tarantool_version_ge('2.6.1') then
            t.assert_equals(state.synchro_owner, state.id)
        end
    end)

    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.cluster.main_server), {})
    end)
end

g.test_join_third_storage = function()
    test_join_third_storage(g)
end

g_manual.test_join_third_storage = function()
    test_join_third_storage(g_manual)
end
