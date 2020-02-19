local fio = require('fio')
local t = require('luatest')
local g = t.group()

local log = require('log')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.setup = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {'myrole'},
            servers = {{
                alias = 'master',
                instance_uuid = helpers.uuid('a', 'a', 1)
            },
            {
                alias = 'slave',
                instance_uuid = helpers.uuid('a', 'a', 2)
            }},
        }},
    })
    g.cluster:start()

    g.cluster.main_server:graphql({query = [[
        mutation {
            cluster { failover(enabled: true) }
        }
    ]]})
    log.warn('Failover enabled')

    g.master = g.cluster:server('master')
    g.slave = g.cluster:server('slave')
end

g.teardown = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function is_master(srv)
    return srv.net_box:eval([[
        return package.loaded['mymodule'].is_master()
    ]])
end

local function get_leader(srv)
    return srv.net_box:eval([[
        local failover = require('cartridge.failover')
        return failover.get_active_leaders()[box.info.cluster.uuid]
    ]])
end

local function rpc_get_candidate(srv)
    return srv.net_box:eval([[
        local get_candidates = require('cartridge').rpc_get_candidates
        local candidates = get_candidates('myrole', {leader_only = true})
        if #candidates == 0 then
            error('No rpc candidates available', 0)
        end
        return candidates[1]
    ]])
end

local function get_upstream_info(srv)
    local info = srv:graphql({
        query = [[query($uuid: String!) {
            servers(uuid: $uuid) {
                uuid
                boxinfo {replication {replication_info {
                    uuid
                    upstream_status
                    upstream_message
                }}}
            }
        }]],
        variables = {uuid = srv.instance_uuid},
    }).data.servers[1].boxinfo.replication.replication_info

    for _, v in pairs(info) do
        if v.uuid ~= srv.instance_uuid then
            return v
        end
    end
end

local function wish_state(srv, desired_state)
    g.cluster:retrying({}, function()
        srv.net_box:eval([[
            local confapplier = require('cartridge.confapplier')
            local desired_state = ...
            local state = confapplier.wish_state(desired_state)
            assert(
                state == desired_state,
                string.format('Inappropriate state %q ~= desired %q',
                state, desired_state)
            )
        ]], {desired_state})
    end)
end

local function list_issues(server)
    return server:graphql({query = [[{
        cluster {
            issues {
                level
                message
                replicaset_uuid
                instance_uuid
            }
        }
    }]]}).data.cluster.issues
end

function g.test_failover()
    local function _ro_map()
        local resp = g.cluster:server('slave'):graphql({query = [[{
            servers { alias boxinfo { general {ro} } }
        }]]})

        local ret = {}
        for _, srv in pairs(resp.data.servers) do
            if srv.boxinfo == nil then
                ret[srv.alias] = box.NULL
            else
                ret[srv.alias] = srv.boxinfo.general.ro
            end
        end

        return ret
    end

    --------------------------------------------------------------------
    t.assert_equals(is_master(g.slave), false)
    t.assert_equals(_ro_map(), {
        master = false,
        slave = true,
    })

    t.helpers.retrying({}, function()
        t.assert_equals(list_issues(g.master), {})
    end)

    --------------------------------------------------------------------
    g.master:stop()

    t.helpers.retrying({}, function()
        t.assert_equals(is_master(g.slave), true)
    end)
    t.assert_equals(_ro_map(), {
        master = box.NULL,
        slave = false,
    })
    t.helpers.retrying({}, function()
        local issues = list_issues(g.slave)
        t.assert_covers(issues[1], {
            level = 'warning',
            replicaset_uuid = helpers.uuid('a'),
            instance_uuid = helpers.uuid('a', 'a', 2),
        })
        t.assert_str_matches(
            issues[1].message,
            'Replication from localhost:13301' ..
            ' to localhost:13302 is disconnected .+'
        )
        t.assert_equals(issues[2], nil)
    end)

    --------------------------------------------------------------------
    log.warn('Restarting master')
    g.master:start()

    t.helpers.retrying({}, function()
        t.assert_equals(is_master(g.slave), false)
    end)
    t.assert_equals(is_master(g.master), true)
    t.assert_equals(_ro_map(), {
        master = false,
        slave = true,
    })

    t.helpers.retrying({}, function()
        t.assert_equals(list_issues(g.master), {})
    end)
end

function g.test_confapplier_race()
    -- Sequence of actions:
    --
    -- m|s: prepare_2pc (ok)
    -- m  : Trigger failover
    -- m  : ConfiguringRoles, sleep 0.5
    --   s: apply_2pc (ok)
    -- m  : Don't apply_2pc yet (state is inappropriate)
    -- m  : RolesConfigured
    -- m  : apply_config

    g.master.net_box:eval('f, arg = ...; loadstring(f)(arg)', {
        string.dump(function(uri)
            local myrole = require('mymodule')

            -- Monkeypatch validate_config to trigger failover
            myrole._validate_config_backup = myrole.validate_config
            myrole.validate_config = function()
                local member = require('membership').get_member(uri)
                require('membership.events').generate(
                    member.uri,
                    require('membership.options').DEAD,
                    100, -- incarnation, spread false rumor only once
                    member.payload
                )
                return true
            end

            -- Monkeypatch apply_config to be slower
            local slowdown_once = true
            myrole._apply_config_backup = myrole.apply_config
            myrole.apply_config = function()
                if slowdown_once then
                    require('fiber').sleep(0.5)
                    slowdown_once = false
                end
            end
        end),
        g.slave.advertise_uri
    })

    -- Trigger patch_clusterwide
    -- It should succeed
    g.master:graphql({query = [[
        mutation{ cluster{
            config(sections: [{filename: "x.txt", content: "XD"}]){}
        }}
    ]]})
end

function g.test_leader_death()
    -- Sequence of actions:
    --
    -- m|s: prepare_2pc (ok)
    -- m  : ConfiguringRoles, sleep 0.2
    --   s: ConfiguringRoles, sleep 0.5
    -- m  : dies
    --   s: Don't trigger failover yet (state is inappropriate)
    --   s: RolesConfigured
    --   s: Trigger failover

    -- Monkeypatch apply_config on master to faint death
    g.master.net_box:eval('loadstring(...)()', {
        string.dump(function()
            local myrole = require('mymodule')
            myrole.apply_config = function()
                require('fiber').sleep(0.2)

                 -- faint death
                local membership = require('membership')
                membership.leave()
                membership.set_payload = function() end

                error("Apply fails sometimes, who'd have thought?", 0)
            end
        end)
    })

    -- Monkeypatch apply_config on slave to be slow
    g.slave.net_box:eval('loadstring(...)()', {
        string.dump(function()
            local myrole = require('mymodule')

            myrole._apply_config_backup = myrole.apply_config
            myrole.apply_config = function(conf, opts)
                require('fiber').sleep(0.5)
                require('log').warn('I am %s',
                    opts.is_master and 'leader' or 'looser'
                )
                return myrole._apply_config_backup(conf, opts)
            end
        end),
        g.slave.advertise_uri
    })

    -- Trigger patch_clusterwide
    t.assert_error_msg_equals(
        "Apply fails sometimes, who'd have thought?",
        function()
            return g.master:graphql({query = [[
                mutation{ cluster{
                    config(sections: [{filename: "y.txt", content: "XD"}]){}
                }}
            ]]})
        end
    )

    t.helpers.retrying({}, function()
        t.assert_equals(is_master(g.slave), true)
    end)
end

function g.test_leader_recovery()
    -- Old leader shouldn't take its role until recovery is finished
    -- Simulate long recovery by temporarily disabling iproto on a slave
    g.master:stop()
    g.slave.net_box:eval("box.cfg({listen = box.NULL})")

    log.info('--------------------------------------------------------')
    g.master:start()
    wish_state(g.master, 'ConnectingFullmesh')
    g.master.net_box:eval([[
        _G.protection_fiber = require('fiber').create(function()
            require('log').warn('Master protected from becoming rw')
            if pcall(box.ctl.wait_rw) then
                require('log').error('DANGER! Master is rw!')
                os.exit(-1)
            end
        end)
    ]])

    t.assert_equals(
        get_upstream_info(g.master),
        {
            uuid = g.slave.instance_uuid,
            upstream_status = box.NULL,
            upstream_message = box.NULL,
        }
    )
    t.assert_covers(
        get_upstream_info(g.slave),
        {
            uuid = g.master.instance_uuid,
            upstream_status = "disconnected",
            -- upstream_message - not checked
        }
    )
    t.assert_error_msg_equals(
        "No rpc candidates available",
        rpc_get_candidate, g.master
    )
    t.assert_equals(rpc_get_candidate(g.slave), g.slave.advertise_uri)
    t.assert_equals(get_leader(g.slave), g.slave.instance_uuid)
    t.assert_equals(is_master(g.slave), true)
    t.assert_equals(is_master(g.master), box.NULL)

    g.master.net_box:eval([[
        _G.protection_fiber:cancel()
    ]])
    -- Simulate the end of recovery (successfull)
    g.slave.net_box:eval("box.cfg({listen = ...})", {g.slave.net_box_port})
    g.cluster:wait_until_healthy(g.slave)

    t.assert_equals(
        get_upstream_info(g.master),
        {
            uuid = g.slave.instance_uuid,
            upstream_status = "follow",
            upstream_message = box.NULL,
        }
    )
    t.assert_equals(
        get_upstream_info(g.slave),
        {
            uuid = g.master.instance_uuid,
            upstream_status = "follow",
            upstream_message = box.NULL,
        }
    )
    t.assert_equals(rpc_get_candidate(g.slave), g.master.advertise_uri)
    t.assert_equals(get_leader(g.slave), g.master.instance_uuid)
    t.assert_equals(get_leader(g.master), g.master.instance_uuid)
    t.assert_equals(is_master(g.slave), false)
    t.assert_equals(is_master(g.master), true)
end

function g.test_orphan_connect_timeout()
    -- If the master can't connect to the slave in
    -- <TARANTOOL_REPLICATION_CONNECT_TIMEOUT> seconds
    -- it becomes an orphan and transits to OperationError state.

    g.master:stop()
    g.slave:stop()

    log.info('--------------------------------------------------------')
    g.master.env['TARANTOOL_REPLICATION_CONNECT_TIMEOUT'] = 1
    g.master:start()
    wish_state(g.master, 'ConnectingFullmesh')
    t.assert_equals(
        g.master:graphql({
            query = [[ { servers {uuid message} } ]]
        }).data.servers,
        {{
            uuid = g.master.instance_uuid,
            message = "ConnectingFullmesh",
        }, {
            uuid = g.slave.instance_uuid,
            message = "",
        }}
    )
    wish_state(g.master, 'OperationError')

    t.helpers.retrying({}, function()
        t.assert_equals(list_issues(g.master), {{
            level = 'warning',
            replicaset_uuid = helpers.uuid('a'),
            instance_uuid = helpers.uuid('a', 'a', 1),
            message = "Replication from localhost:13302" ..
                " to localhost:13301 isn't running",
        }})
    end)

    log.info('--------------------------------------------------------')
    g.slave:start()
    wish_state(g.slave, 'RolesConfigured')

    t.assert_equals(
        get_upstream_info(g.slave),
        {
            uuid = g.master.instance_uuid,
            upstream_status = "follow",
            upstream_message = box.NULL,
        }
    )

    t.assert_equals(rpc_get_candidate(g.slave), g.slave.advertise_uri)
    t.assert_equals(get_leader(g.slave), g.slave.instance_uuid)
    t.assert_equals(is_master(g.slave), true)
    t.helpers.retrying({}, function()
        t.assert_equals(list_issues(g.slave), {})
    end)
end

function g.test_orphan_sync_timeout()
    -- Another way to get orphan status is to fail syncing.
    -- This case is similar to test_orphan_connect_timeout.
    g.master:stop()

    log.info('--------------------------------------------------------')
    g.master.env['TARANTOOL_REPLICATION_CONNECT_TIMEOUT'] = 0.1
    g.master.env['TARANTOOL_REPLICATION_SYNC_LAG'] = 1e-308
    g.master.env['TARANTOOL_REPLICATION_SYNC_TIMEOUT'] = 0.1
    g.master:start()
    wish_state(g.master, 'OperationError')

    t.assert_equals(
        -- master <- slave replication is established instantly
        get_upstream_info(g.master),
        {
            uuid = g.slave.instance_uuid,
            -- it never finish syncing due to the low lag setting
            upstream_status = "sync",
            upstream_message = box.NULL,
        }
    )

    t.helpers.retrying({}, function()
        local issues = list_issues(g.master)
        t.assert_covers(issues[1], {
            level = 'warning',
            replicaset_uuid = helpers.uuid('a'),
            instance_uuid = helpers.uuid('a', 'a', 1),
        })
        t.assert_str_matches(
            issues[1].message,
            'Replication from localhost:13302' ..
            ' to localhost:13301: high lag %(.+ > 1e%-308%)'
        )
        t.assert_equals(issues[2], nil)
    end)
end

function g.test_quorum_one()
    -- It's possible to avoid orphan status by explicitly specifying
    -- TARANTOOL_REPLICATION_CONNECT_QUORUM = 1 (or 0)

    g.master:stop()
    g.slave:stop()

    log.info('--------------------------------------------------------')
    g.master.env['TARANTOOL_REPLICATION_CONNECT_QUORUM'] = 1
    g.master:start()
    wish_state(g.master, 'RolesConfigured')

    t.assert_equals(rpc_get_candidate(g.master), g.master.advertise_uri)
    t.assert_equals(get_leader(g.master), g.master.instance_uuid)
    t.assert_equals(is_master(g.master), true)

    g.slave:start()
    g.cluster:wait_until_healthy(g.slave)

    t.assert_equals(
        -- slave <- master replication is established instantly
        get_upstream_info(g.slave),
        {
            uuid = g.master.instance_uuid,
            upstream_status = "follow",
            upstream_message = box.NULL,
        }
    )

    g.cluster:retrying({}, function()
        -- it make take some time to reconnect
        -- master <- slave replication
        -- (since the master retries every 1.0s)
        t.assert_equals(
            get_upstream_info(g.master),
            {
                uuid = g.slave.instance_uuid,
                upstream_status = "follow",
                upstream_message = box.NULL,
            }
        )
    end)

    t.assert_equals(rpc_get_candidate(g.slave), g.master.advertise_uri)
    t.assert_equals(get_leader(g.slave), g.master.instance_uuid)
    t.assert_equals(is_master(g.slave), false)
end

function g.test_restart_both()
    g.cluster:stop()
    g.cluster:start()
    wish_state(g.master, 'RolesConfigured')
    wish_state(g.slave, 'RolesConfigured')

    t.assert_equals(
        get_upstream_info(g.master),
        {
            uuid = g.slave.instance_uuid,
            upstream_status = "follow",
            upstream_message = box.NULL,
        }
    )

    t.assert_equals(
        get_upstream_info(g.slave),
        {
            uuid = g.master.instance_uuid,
            upstream_status = "follow",
            upstream_message = box.NULL,
        }
    )

    g.cluster:wait_until_healthy()
    t.helpers.retrying({}, function()
        t.assert_equals(list_issues(g.master), {})
    end)
end

