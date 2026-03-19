local fio = require('fio')
local t = require('luatest')

local helpers = require('test.helper')

local g = t.group('integration.manual_election_mode_helper.stateboard')

local replicaset_uuid = helpers.uuid('a')
local storage_1_uuid = helpers.uuid('a', 'a', 1)
local storage_2_uuid = helpers.uuid('a', 'a', 2)
local storage_3_uuid = helpers.uuid('a', 'a', 3)

local function get_state(server)
    return server:exec(function()
        local failover = require('cartridge.failover')
        local synchro = box.info.synchro or {}
        local queue = synchro.queue or {}

        return {
            election_mode = box.cfg.election_mode or 'off',
            election_fencing_mode = box.cfg.election_fencing_mode,
            is_leader = failover.is_leader(),
            is_ro = box.info.ro,
            synchro_owner = queue.owner,
            id = box.info.id,
        }
    end)
end

local function call_switch_to_manual(server)
    return server:exec(function()
        local failover = require('cartridge.lua-api.failover')
        local ok, err = failover.switch_to_manual_election_mode()
        return {
            ok = ok,
            err = err and tostring(err) or nil,
        }
    end)
end

local function call_switch_to_off(server, opts)
    return server:exec(function(opts)
        local failover = require('cartridge.lua-api.failover')
        local ok, err = failover.switch_to_off_election_mode(opts)
        return {
            ok = ok,
            err = err and tostring(err) or nil,
        }
    end, {opts})
end

local function set_election_state(server, election_mode, election_fencing_mode)
    return server:exec(function(election_mode, election_fencing_mode)
        box.cfg({
            election_mode = election_mode,
            election_fencing_mode = election_fencing_mode,
        })

        return {
            election_mode = box.cfg.election_mode,
            election_fencing_mode = box.cfg.election_fencing_mode,
        }
    end, {election_mode, election_fencing_mode})
end

local function get_peer_switch_order(server)
    return server:exec(function()
        local confapplier = require('cartridge.confapplier')
        local topology = require('cartridge.topology')

        local topology_cfg = confapplier.get_readonly('topology')
        local self_uuid = box.info.uuid
        local replicaset_uuid = topology_cfg.servers[self_uuid].replicaset_uuid
        local leaders_order = topology.get_leaders_order(
            topology_cfg,
            replicaset_uuid,
            nil,
            {
                only_enabled = false,
                only_electable = false,
            }
        )

        local ret = {}
        for _, instance_uuid in ipairs(leaders_order) do
            if instance_uuid ~= self_uuid then
                table.insert(ret, instance_uuid)
            end
        end

        return ret
    end)
end

local function inject_promote_error(server, message)
    server:exec(function(message)
        rawset(_G, 'old_promote', box.ctl.promote)
        rawset(box.ctl, 'promote', function()
            error(message, 0)
        end)
    end, {message})
end

local function restore_promote(server)
    server:exec(function()
        local old_promote = rawget(_G, 'old_promote')
        if old_promote ~= nil then
            rawset(box.ctl, 'promote', old_promote)
            rawset(_G, 'old_promote', nil)
        end
    end)
end

local function inject_switch_error(server, message)
    server:exec(function(message)
        rawset(
            _G,
            'old_switch_to_manual_election_mode',
            _G.__cartridge_failover_switch_to_manual_election_mode
        )
        rawset(_G, '__cartridge_failover_switch_to_manual_election_mode', function()
            error(message, 0)
        end)
    end, {message})
end

local function restore_switch_error(server)
    server:exec(function()
        local old_switch = rawget(_G, 'old_switch_to_manual_election_mode')
        if old_switch ~= nil then
            rawset(_G, '__cartridge_failover_switch_to_manual_election_mode', old_switch)
            rawset(_G, 'old_switch_to_manual_election_mode', nil)
        end
    end)
end

local function inject_unhealthy_membership(server, target_uri)
    server:exec(function(target_uri)
        local membership = require('membership')
        rawset(_G, 'old_membership_get_member', membership.get_member)
        rawset(membership, 'get_member', function(uri)
            if uri == target_uri then
                return {status = 'dead'}
            end

            return rawget(_G, 'old_membership_get_member')(uri)
        end)
    end, {target_uri})
end

local function restore_membership(server)
    server:exec(function()
        local membership = require('membership')
        local old_get_member = rawget(_G, 'old_membership_get_member')
        if old_get_member ~= nil then
            rawset(membership, 'get_member', old_get_member)
            rawset(_G, 'old_membership_get_member', nil)
        end
    end)
end

local function assert_cluster_is_off()
    helpers.retrying({timeout = 20}, function()
        local leader_state = get_state(g.leader)
        local replica_1_state = get_state(g.replica_1)
        local replica_2_state = get_state(g.replica_2)

        t.assert_equals(leader_state.election_mode, 'off')
        t.assert_equals(leader_state.is_leader, true)
        t.assert_equals(leader_state.is_ro, false)

        t.assert_equals(replica_1_state.election_mode, 'off')
        t.assert_equals(replica_1_state.is_leader, false)
        t.assert_equals(replica_1_state.is_ro, true)

        t.assert_equals(replica_2_state.election_mode, 'off')
        t.assert_equals(replica_2_state.is_leader, false)
        t.assert_equals(replica_2_state.is_ro, true)
    end)
end

local function assert_cluster_fencing_mode(expected_fencing_mode)
    helpers.retrying({timeout = 20}, function()
        local leader_state = get_state(g.leader)
        local replica_1_state = get_state(g.replica_1)
        local replica_2_state = get_state(g.replica_2)

        t.assert_equals(leader_state.election_fencing_mode, expected_fencing_mode)
        t.assert_equals(replica_1_state.election_fencing_mode, expected_fencing_mode)
        t.assert_equals(replica_2_state.election_fencing_mode, expected_fencing_mode)
    end)
end

local function assert_cluster_is_manual()
    helpers.retrying({timeout = 20}, function()
        local leader_state = get_state(g.leader)
        local replica_1_state = get_state(g.replica_1)
        local replica_2_state = get_state(g.replica_2)

        t.assert_equals(leader_state.election_mode, 'manual')
        t.assert_equals(leader_state.election_fencing_mode, 'off')
        t.assert_equals(leader_state.is_leader, true)
        t.assert_equals(leader_state.is_ro, false)

        t.assert_equals(replica_1_state.election_mode, 'manual')
        t.assert_equals(replica_1_state.election_fencing_mode, 'off')
        t.assert_equals(replica_1_state.is_leader, false)
        t.assert_equals(replica_1_state.is_ro, true)

        t.assert_equals(replica_2_state.election_mode, 'manual')
        t.assert_equals(replica_2_state.election_fencing_mode, 'off')
        t.assert_equals(replica_2_state.is_leader, false)
        t.assert_equals(replica_2_state.is_ro, true)

        if helpers.tarantool_version_ge('2.6.1') then
            t.assert_equals(leader_state.synchro_owner, leader_state.id)
        end
    end)
end

local function stop_cluster()
    if g.cluster ~= nil then
        g.cluster:stop()
        fio.rmtree(g.cluster.datadir)
        g.cluster = nil
        g.leader = nil
        g.replica_1 = nil
        g.replica_2 = nil
        g.servers_by_uuid = nil
    end
end

local function start_cluster(opts)
    opts = opts or {}

    local replicasets = opts.replicasets or {
        {
            alias = 'storage',
            uuid = replicaset_uuid,
            roles = {'failover-coordinator'},
            all_rw = opts.all_rw,
            servers = {
                {alias = 'storage-1', instance_uuid = storage_1_uuid},
                {alias = 'storage-2', instance_uuid = storage_2_uuid},
                {alias = 'storage-3', instance_uuid = storage_3_uuid},
            },
        },
    }

    local cluster_opts = {
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        failover = opts.failover or 'stateful',
        replicasets = replicasets,
        env = opts.env,
    }

    if cluster_opts.failover == 'stateful' then
        cluster_opts.stateboard_entrypoint = helpers.entrypoint('srv_stateboard')
    end

    g.cluster = helpers.Cluster:new(cluster_opts)
    g.cluster:start()
    helpers.retrying({}, function()
        g.cluster:wait_until_healthy()
    end)
    g.leader = g.cluster:server('storage-1')
    g.replica_1 = g.cluster:server('storage-2')
    g.replica_2 = g.cluster:server('storage-3')
    g.servers_by_uuid = {
        [storage_1_uuid] = g.leader,
        [storage_2_uuid] = g.replica_1,
        [storage_3_uuid] = g.replica_2,
    }
end

local function assert_switch_fails(server, expected_substring)
    local res = call_switch_to_manual(server)
    t.assert_equals(res.ok, nil)
    t.assert_not_equals(res.err, nil)
    t.assert_str_contains(res.err, expected_substring)
    return res.err
end

local function assert_switch_to_off_fails(server, expected_substring, opts)
    local res = call_switch_to_off(server, opts)
    t.assert_equals(res.ok, nil)
    t.assert_not_equals(res.err, nil)
    t.assert_str_contains(res.err, expected_substring)
    return res.err
end

local function set_failover_suppressed(server, value)
    return server:exec(function(value)
        local vars = require('cartridge.vars').new('cartridge.failover')
        vars.failover_suppressed = value
        return vars.failover_suppressed
    end, {value})
end

local function set_failover_paused(paused)
    for _, server in ipairs(g.cluster.servers) do
        server:exec(function(paused)
            if paused then
                _G.__cartridge_failover_pause()
            else
                _G.__cartridge_failover_resume()
            end
            return require('cartridge.failover').is_paused()
        end, {paused})
    end
end

local function set_failover_mode(mode)
    t.assert_equals(g.cluster.main_server:call(
        'package.loaded.cartridge.failover_set_params',
        {{mode = mode}}
    ), true)
end

local function set_server_disabled(server, instance_uuid, disabled)
    return server:exec(function(instance_uuid, disabled)
        local topology = require('cartridge.lua-api.topology')
        if disabled then
            assert(topology.disable_servers({instance_uuid}))
            return true
        end

        assert(topology.enable_servers({instance_uuid}))
        return true
    end, {instance_uuid, disabled})
end

local function assert_failover_mode(server, expected_mode)
    helpers.retrying({timeout = 20}, function()
        t.assert_equals(server:exec(function()
            return require('cartridge.failover').mode()
        end), expected_mode)
    end)
end

local peer_start_states = {
    {name = 'manual_off', election_mode = 'manual', election_fencing_mode = 'off'},
    {name = 'manual_soft', election_mode = 'manual', election_fencing_mode = 'soft'},
    {name = 'off_off', election_mode = 'off', election_fencing_mode = 'off'},
    {name = 'off_soft', election_mode = 'off', election_fencing_mode = 'soft'},
}

g.before_all(function()
    t.skip_if(not helpers.tarantool_supports_election_fencing_mode(),
        'Manual election helper test requires election_fencing_mode support')
end)

g.before_each(function()
    start_cluster()
end)

g.after_each(function()
    stop_cluster()
end)

g.test_switch_to_manual_election_mode = function()
    assert_cluster_is_off()

    local res = call_switch_to_manual(g.leader)
    t.assert_equals(res, {
        ok = true,
        err = nil,
    })

    assert_cluster_is_manual()
end

g.test_switch_to_off_election_mode = function()
    assert_cluster_is_off()

    local res = call_switch_to_manual(g.leader)
    t.assert_equals(res, {
        ok = true,
        err = nil,
    })

    assert_cluster_is_manual()

    res = call_switch_to_off(g.leader)
    t.assert_equals(res, {
        ok = true,
        err = nil,
    })

    assert_cluster_is_off()
    assert_cluster_fencing_mode('soft')
end

g.test_switch_to_off_converges_manual_and_off_mix = function()
    assert_cluster_is_off()

    local res = call_switch_to_manual(g.leader)
    t.assert_equals(res, {
        ok = true,
        err = nil,
    })

    assert_cluster_is_manual()

    t.assert_equals(
        set_election_state(g.replica_2, 'off', 'off'),
        {
            election_mode = 'off',
            election_fencing_mode = 'off',
        }
    )

    res = call_switch_to_off(g.leader)
    t.assert_equals(res, {
        ok = true,
        err = nil,
    })

    assert_cluster_is_off()
    assert_cluster_fencing_mode('soft')
end

g.test_switch_to_off_fails_for_disabled_failover = function()
    assert_cluster_is_off()

    local res = call_switch_to_manual(g.leader)
    t.assert_equals(res, {
        ok = true,
        err = nil,
    })

    assert_cluster_is_manual()

    set_failover_mode('disabled')
    assert_failover_mode(g.leader, 'disabled')

    assert_switch_to_off_fails(
        g.leader,
        'switch_to_off_election_mode() is supported only for stateful failover, got "disabled"'
    )
end

g.test_switch_to_manual_rolls_back_after_promote_error_and_retries = function()
    assert_cluster_is_off()

    local test_message = 'manual election helper promote error'
    inject_promote_error(g.leader, test_message)

    local res = call_switch_to_manual(g.leader)
    t.assert_equals(res.ok, nil)
    t.assert_not_equals(res.err, nil)
    t.assert_str_contains(res.err, test_message)

    assert_cluster_is_off()

    restore_promote(g.leader)

    res = call_switch_to_manual(g.leader)
    t.assert_equals(res, {
        ok = true,
        err = nil,
    })

    assert_cluster_is_manual()
end

g.test_switch_to_manual_rolls_back_after_peer_switch_error = function()
    assert_cluster_is_off()

    local peer_order = get_peer_switch_order(g.leader)
    local failing_peer = g.servers_by_uuid[peer_order[2]]
    local test_message = 'manual election helper peer switch error'

    t.assert_not_equals(failing_peer, nil)
    inject_switch_error(failing_peer, test_message)

    local res = call_switch_to_manual(g.leader)
    t.assert_equals(res.ok, nil)
    t.assert_not_equals(res.err, nil)
    t.assert_str_contains(res.err, test_message)
    t.assert_str_contains(res.err, peer_order[2])

    restore_switch_error(failing_peer)

    assert_cluster_is_off()
end

g.test_switch_to_manual_fails_when_called_on_non_leader = function()
    assert_cluster_is_off()

    assert_switch_fails(
        g.replica_1,
        'switch_to_manual_election_mode() must be called on the appointed leader'
    )
    assert_cluster_is_off()
end

g.test_switch_to_off_fails_when_called_on_non_leader = function()
    assert_cluster_is_off()

    local res = call_switch_to_manual(g.leader)
    t.assert_equals(res, {
        ok = true,
        err = nil,
    })

    assert_cluster_is_manual()

    assert_switch_to_off_fails(
        g.replica_1,
        'switch_to_off_election_mode() must be called on the appointed leader'
    )
end

g.test_switch_to_manual_fails_when_suppressed = function()
    assert_cluster_is_off()

    t.assert_equals(set_failover_suppressed(g.leader, true), true)
    t.assert_equals(g.leader:exec(function()
        return require('cartridge.failover').is_suppressed()
    end), true)

    assert_switch_fails(g.leader, 'Failover is suppressed')
    assert_cluster_is_off()
end

g.test_switch_to_manual_is_not_blocked_by_pause = function()
    assert_cluster_is_off()

    set_failover_paused(true)
    t.assert_equals(g.leader:exec(function()
        return require('cartridge.failover').is_paused()
    end), true)

    local res = call_switch_to_manual(g.leader)
    t.assert_equals(res, {
        ok = true,
        err = nil,
    })

    assert_cluster_is_manual()
end

g.test_switch_to_manual_fails_without_synchro_mode = function()
    stop_cluster()
    start_cluster({
        env = {
            TARANTOOL_DISABLE_SYNCHRO_MODE = 'true',
        },
    })

    assert_switch_fails(g.leader, 'Synchro mode must be enabled')
end

g.test_switch_to_manual_fails_for_eventual_failover = function()
    stop_cluster()
    start_cluster({
        failover = 'eventual',
    })

    assert_switch_fails(
        g.leader,
        'switch_to_manual_election_mode() is supported only for stateful failover, got "eventual"'
    )
end

g.test_switch_to_manual_fails_for_all_rw_replicaset = function()
    stop_cluster()
    start_cluster({
        all_rw = true,
    })

    assert_switch_fails(
        g.leader,
        'switch_to_manual_election_mode() is not supported with ALL_RW replicasets'
    )
end

g.test_switch_to_manual_fails_for_disabled_instance = function()
    assert_cluster_is_off()

    set_server_disabled(g.leader, storage_3_uuid, true)

    local err = assert_switch_fails(
        g.leader,
        'contains disabled instance'
    )
    t.assert_str_contains(err, storage_3_uuid)
end

g.test_switch_to_manual_fails_for_unhealthy_instance = function()
    assert_cluster_is_off()

    inject_unhealthy_membership(g.leader, g.replica_2.advertise_uri)

    local ok, err = pcall(function()
        local switch_err = assert_switch_fails(
            g.leader,
            'contains unhealthy instance'
        )
        t.assert_str_contains(switch_err, storage_3_uuid)
    end)
    restore_membership(g.leader)
    t.assert(ok, err)
end

g.test_switch_to_off_fails_on_unsupported_peer_election_mode = function()
    assert_cluster_is_off()

    local res = call_switch_to_manual(g.leader)
    t.assert_equals(res, {
        ok = true,
        err = nil,
    })

    assert_cluster_is_manual()

    t.assert_equals(
        set_election_state(g.replica_1, 'voter', 'soft'),
        {
            election_mode = 'voter',
            election_fencing_mode = 'soft',
        }
    )

    res = call_switch_to_off(g.leader)
    t.assert_equals(res.ok, nil)
    t.assert_not_equals(res.err, nil)
    t.assert_str_contains(res.err, storage_2_uuid)
    t.assert_str_contains(res.err, 'unsupported election_mode="voter"')
end

for _, replica_1_state in ipairs(peer_start_states) do
    for _, replica_2_state in ipairs(peer_start_states) do
        local test_name = string.format(
            'test_switch_to_manual_converges_%s__%s',
            replica_1_state.name,
            replica_2_state.name
        )

        g[test_name] = function()
            assert_cluster_is_off()

            t.assert_equals(
                set_election_state(
                    g.replica_1,
                    replica_1_state.election_mode,
                    replica_1_state.election_fencing_mode
                ),
                {
                    election_mode = replica_1_state.election_mode,
                    election_fencing_mode = replica_1_state.election_fencing_mode,
                }
            )
            t.assert_equals(
                set_election_state(
                    g.replica_2,
                    replica_2_state.election_mode,
                    replica_2_state.election_fencing_mode
                ),
                {
                    election_mode = replica_2_state.election_mode,
                    election_fencing_mode = replica_2_state.election_fencing_mode,
                }
            )

            helpers.retrying({timeout = 20}, function()
                local current_replica_1_state = get_state(g.replica_1)
                local current_replica_2_state = get_state(g.replica_2)

                t.assert_equals(
                    current_replica_1_state.election_mode,
                    replica_1_state.election_mode
                )
                t.assert_equals(
                    current_replica_1_state.election_fencing_mode,
                    replica_1_state.election_fencing_mode
                )
                t.assert_equals(
                    current_replica_2_state.election_mode,
                    replica_2_state.election_mode
                )
                t.assert_equals(
                    current_replica_2_state.election_fencing_mode,
                    replica_2_state.election_fencing_mode
                )
            end)

            local res = call_switch_to_manual(g.leader)
            t.assert_equals(res, {
                ok = true,
                err = nil,
            })

            assert_cluster_is_manual()
        end
    end
end

