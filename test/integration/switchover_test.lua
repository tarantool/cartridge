local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local stateboard_client = require('cartridge.stateboard-client')

local uA = helpers.uuid('a')
local uB = helpers.uuid('b')
local uA1 = helpers.uuid('a', 1, 1)
local uB1 = helpers.uuid('b', 1, 1)
local uB2 = helpers.uuid('b', 2, 2)
local A1
local B1
local B2

g.before_all(function()
    g.datadir = fio.tempdir()

    -- Start stateboard instance
    fio.mktree(fio.pathjoin(g.datadir, 'stateboard'))
    g.kvpassword = require('digest').urandom(6):hex()
    g.stateboard = require('luatest.server'):new({
        command = helpers.entrypoint('srv_stateboard'),
        workdir = fio.pathjoin(g.datadir, 'stateboard'),
        net_box_port = 14401,
        net_box_credentials = {
            user = 'client',
            password = g.kvpassword,
        },
        env = {
            TARANTOOL_LOCK_DELAY = 9000,
            TARANTOOL_PASSWORD = g.kvpassword,
            TARANTOOL_CONSOLE_SOCK = fio.pathjoin(
                g.datadir, 'stateboard', 'console.sock'
            ),
        },
    })
    g.stateboard:start()
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
    end)

    g.client = stateboard_client.new({
        uri = '127.0.0.1:' .. g.stateboard.net_box_port,
        password = g.stateboard.net_box_credentials.password,
        call_timeout = 1,
    })

    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {{
            uuid = uA,
            roles = {},
            servers = {{alias = 'A1', instance_uuid = uA1}},
        }, {
            uuid = uB,
            roles = {},
            servers = {
                {alias = 'B1', instance_uuid = uB1},
                {alias = 'B2', instance_uuid = uB2},
            },
        }},
    })

    g.cluster:start()
    A1 = g.cluster:server('A1')
    B1 = g.cluster:server('B1')
    B2 = g.cluster:server('B2')

    B1.net_box:call('box.schema.sequence.create', {'test'})
    B1.net_box:call('package.loaded.cartridge.failover_set_params', {{
        mode = 'stateful',
        state_provider = 'tarantool',
        tarantool_params = {
            uri = '127.0.0.1:' .. g.stateboard.net_box_port,
            password = g.kvpassword,
        },
    }})
end)

g.after_all(function()
    g.cluster:stop()
    g.stateboard:stop()
    fio.rmtree(g.datadir)
end)

g.before_each(function()
    g.session = g.client:get_session()
    t.assert(g.session:acquire_lock({uuid = 'test-uuid', uri = 'test'}))
    t.assert(g.session:set_vclockkeeper(uA, uA1))
    t.assert(g.session:set_vclockkeeper(uB, uB1))
    t.assert(g.session:set_leaders({{uA, uA1}, {uB, uB1}}))

    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(A1), {})
    end)
end)

g.after_each(function()
    for _, srv in pairs(g.cluster.servers) do
        srv.process:kill('CONT')
    end
end)

local q_readonliness = "return box.info.ro"
local q_set_wait_lsn_timeout = [[
    local vars = require('cartridge.vars').new('cartridge.failover')
    vars.options.WAITLSN_TIMEOUT = ...
]]
local q_is_vclockkeeper = [[
    local failover = require('cartridge.failover')
    return failover.is_vclockkeeper()
]]
local q_leadership = [[
    local failover = require('cartridge.failover')
    return failover.get_active_leaders()[...]
]]

function g.test_2pc_forceful()
    -- Testing scenario:
    -- 1. Promote A1 as a leader
    -- 2. An attempt to constitute_oneself fails
    -- 3. Trigger apply_config
    -- 4. An attempt to constitute_oneself still fails
    -- 5. Manually set A1 as vclockkeeper
    -- 6. Expect it to become rw

    -- Prevent wait_lsn from accomplishing successfully
    t.assert(g.session:set_leaders({{uA, 'nobody'}}))
    t.assert(g.session:set_vclockkeeper(uA, 'nobody'))
    helpers.retrying({}, function()
        t.assert_equals(A1.net_box:eval(q_leadership, {uA}), 'nobody')
    end)

    t.assert_equals(A1.net_box:eval(q_readonliness), true)
    t.assert_equals(A1.net_box:eval(q_is_vclockkeeper), false)

    -- Promote A1
    t.assert(g.session:set_leaders({{uA, uA1}}))
    helpers.retrying({}, function()
        t.assert_equals(A1.net_box:eval(q_leadership, {uA}), uA1)
    end)
    t.assert_equals(A1.net_box:eval(q_readonliness), true)
    t.assert_equals(A1.net_box:eval(q_is_vclockkeeper), false)

    A1.net_box:eval(q_set_wait_lsn_timeout, {0.1})

    -- Trigger two-phase commit
    -- An attempt to constitute_oneself fails
    local ok, err = A1.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        local active_config = confapplier.get_active_config()
        require('log').warn('Triggering apply_config')
        return confapplier.apply_config(active_config)
    ]])

    -- Applying configuration succeeds
    t.assert_equals({ok, err}, {true, nil})

    -- But A1 still waits LSN from "nobody" (forever)
    t.assert_equals(A1.net_box:eval(q_readonliness), true)
    t.assert_equals(A1.net_box:eval(q_is_vclockkeeper), false)
    t.assert_items_equals(
        helpers.list_cluster_issues(A1),
        {{
            level = "warning",
            topic = "switchover",
            instance_uuid = uA1,
            replicaset_uuid = uA,
            message = "Consistency on " .. A1.advertise_uri ..
                " (A1) isn't reached yet",
        }}
    )

    -- Manually set A1 as vclockkeeper
    t.assert(g.session:set_vclockkeeper(uA, uA1))

    -- Expect it to become rw
    helpers.retrying({}, function()
        t.assert_equals(A1.net_box:eval(q_readonliness), false)
        t.assert_equals(A1.net_box:eval(q_is_vclockkeeper), true)
    end)
end

function g.test_promotion_forceful()
    -- Scenario:
    -- 1. B1 is a leader and a vclockkeeper
    -- 2. B2 gets promoted but can't accomplish wait_lsn
    -- 3. B2 becomes a vclockkeeper through a force promotion

    B2.net_box:eval(q_set_wait_lsn_timeout, {0.2})
    t.assert_equals(B2.net_box:eval(q_leadership, {uB}), uB1)
    t.assert_equals(B2.net_box:eval(q_readonliness), true)

    -- Prevent wait_lsn from accomplishing successfully
    B1.process:kill('STOP')

    t.assert(g.session:set_leaders({{uB, uB2}}))
    t.assert_error_msg_equals("timed out",
        function() B2.net_box:call('box.ctl.wait_rw', {0.1}) end
    )

    -- B2 stucks on wait_lsn
    t.assert_equals(B2.net_box:eval(q_leadership, {uB}), uB2)
    t.assert_equals(B2.net_box:eval(q_readonliness), true)
    t.assert_equals(B2.net_box:eval(q_is_vclockkeeper), false)
        t.assert_covers(g.session:get_vclockkeeper(uB), {
        replicaset_uuid = uB,
        instance_uuid = uB1,
    })

    -- Manually set B2 as vclockkeeper
    t.assert(g.session:set_vclockkeeper(uB, uB2))

    -- Expect it to become rw
    helpers.retrying({}, function()
        t.assert_equals(B2.net_box:eval(q_readonliness), false)
        t.assert_equals(B2.net_box:eval(q_is_vclockkeeper), true)
    end)

    -- Revert all hacks in fixtures
    B1.process:kill('CONT')
    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(A1), {})
    end)
end

function g.test_promotion_abortion()
    -- Scenario:
    -- 1. B1 is a leader and a vclockkeeper
    -- 2. B2 gets promoted but can't accomplish wait_lsn
    -- 3. B1 is promoted back

    t.assert(g.session:set_leaders({{uB, uB1}}))
    helpers.retrying({}, function()
        t.assert_equals(B1.net_box:eval(q_is_vclockkeeper), true)
        t.assert_equals(B2.net_box:eval(q_is_vclockkeeper), false)
    end)

    -- Protect B2 from becoming rw
    helpers.protect_from_rw(B2)

    -- Prevent wait_lsn from accomplishing successfully
    B2.net_box:eval([[
        _r = box.cfg.replication
        box.cfg({replication = {}})
    ]])
    B1.net_box:call('box.sequence.test:next')

    -- Promote B2
    t.assert(g.session:set_leaders({{uB, uB2}}))
    t.assert_error_msg_equals("timed out",
        function() B2.net_box:call('box.ctl.wait_rw', {0.2}) end
    )

    t.assert_equals(B1.net_box:eval(q_leadership, {uB}), uB2)
    t.assert_equals(B2.net_box:eval(q_leadership, {uB}), uB2)
    t.assert_equals(B1.net_box:eval(q_readonliness), true)
    t.assert_equals(B2.net_box:eval(q_readonliness), true)
    t.assert_equals(B1.net_box:eval(q_is_vclockkeeper), false)
    t.assert_equals(B1.net_box:eval(q_is_vclockkeeper), false)
    t.assert_covers(g.session:get_vclockkeeper(uB), {
        replicaset_uuid = uB,
        instance_uuid = uB1,
    })
    t.assert_items_equals(
        helpers.list_cluster_issues(A1),
        {{
            level = "warning",
            topic = "switchover",
            instance_uuid = uB2,
            replicaset_uuid = uB,
            message = "Consistency on " .. B2.advertise_uri ..
                " (B2) isn't reached yet",
        }, {
            level = "warning",
            topic = "replication",
            instance_uuid = uB2,
            replicaset_uuid = uB,
            message = "Replication" ..
                " from " .. B1.advertise_uri .. " (B1)" ..
                " to " .. B2.advertise_uri .. " (B2) isn't running",
        }}
    )

    -- Revert B1 leadership
    t.assert(g.session:set_leaders({{uB, uB1}}))

    -- Expect it to become rw
    helpers.retrying({}, function()
        t.assert_equals(B1.net_box:eval(q_readonliness), false)
        t.assert_equals(B2.net_box:eval(q_readonliness), true)
    end)

    -- Revert all hacks in fixtures
    B2.net_box:eval('box.cfg({replication = _r})')
    t.assert_error_msg_equals("timed out",
        function() B2.net_box:call('box.ctl.wait_rw', {0.2}) end
    )

    helpers.unprotect(B2)
end

function g.test_promotion_late()
    -- Scenario:
    -- 1. B1 is a leader and a vclockkeeper
    -- 2. B2 gets promoted but can't accomplish wait_lsn
    -- 3. wait_lsn succeeds and B2 finally becomes a vclockkeeper
    t.assert(g.session:set_leaders({{uB, uB1}}))
    helpers.retrying({}, function()
        t.assert_equals(B1.net_box:eval(q_is_vclockkeeper), true)
        t.assert_equals(B2.net_box:eval(q_is_vclockkeeper), false)
    end)

    -- Prevent wait_lsn from accomplishing successfully
    B2.net_box:eval([[
        _r = box.cfg.replication
        box.cfg({replication = {}})
    ]])
    B1.net_box:call('box.sequence.test:next')

    -- Promote B2
    t.assert(g.session:set_leaders({{uB, uB2}}))
    t.assert_error_msg_equals("timed out",
        function() B2.net_box:call('box.ctl.wait_rw', {0.1}) end
    )

    t.assert_equals(B1.net_box:eval(q_leadership, {uB}), uB2)
    t.assert_equals(B2.net_box:eval(q_leadership, {uB}), uB2)
    t.assert_equals(B1.net_box:eval(q_readonliness), true)
    t.assert_equals(B2.net_box:eval(q_readonliness), true)
    t.assert_covers(g.session:get_vclockkeeper(uB), {
        replicaset_uuid = uB,
        instance_uuid = uB1,
    })
    t.assert_items_equals(
        helpers.list_cluster_issues(A1),
        {{
            level = "warning",
            topic = "switchover",
            instance_uuid = uB2,
            replicaset_uuid = uB,
            message = "Consistency on " .. B2.advertise_uri ..
                " (B2) isn't reached yet",
        }, {
            level = "warning",
            topic = "replication",
            instance_uuid = uB2,
            replicaset_uuid = uB,
            message = "Replication" ..
                " from " .. B1.advertise_uri .. " (B1)" ..
                " to " .. B2.advertise_uri .. " (B2) isn't running",
        }}
    )

    -- Repair replication
    B2.net_box:eval('box.cfg({replication = _r})')

    -- Expect it to become rw
    helpers.retrying({}, function()
        t.assert_equals(B1.net_box:eval(q_readonliness), true)
        t.assert_equals(B2.net_box:eval(q_readonliness), false)
    end)
end


function g.test_vclockkeeper_caching()
    -- Scenario:
    -- 1. A1 is a vclockkeeper
    -- 2. B2 gets promoted
    -- 3. A1 successfully longpolls new appointments
    -- 4. But A1 is unable to get info about vclockkeeper
    -- 5. apply_config is still triggered

    t.assert_equals(A1.net_box:eval(q_leadership, {uA}), uA1)
    t.assert_equals(A1.net_box:eval(q_readonliness), false)
    t.assert_equals(A1.net_box:eval(q_is_vclockkeeper), true)

    local conn = require('socket').tcp_connect(
        'unix/', g.stateboard.env.TARANTOOL_CONSOLE_SOCK
    )
    conn:write([[
        _get_vclockkeeper_backup = get_vclockkeeper
        get_vclockkeeper = function() error('Banned', 0) end
    ]])

    -- Monkeypatch apply_config to count reconfiguration events
    A1.net_box:eval('loadstring(...)()', {
        string.dump(function()
            local myrole = require('mymodule-permanent')

            rawset(_G, 'config_incarnation', 0)
            myrole._apply_config_backup = myrole.apply_config
            myrole.apply_config = function(conf, opts)
                _G.config_incarnation = _G.config_incarnation + 1
                return myrole._apply_config_backup(conf, opts)
            end
        end)
    })

    t.assert_equals(A1.net_box:eval('return config_incarnation'), 0)

    t.assert(g.session:set_leaders({{uB, uB2}}))
    helpers.retrying({}, function()
        t.assert_equals(A1.net_box:eval(q_leadership, {uB}), uB2)
    end)

    t.assert_equals(A1.net_box:eval('return config_incarnation'), 1)

    -- Revert all hacks in fixtures
    conn:write([[
        get_vclockkeeper = _get_vclockkeeper_backup
        _get_vclockkeeper_backup = nil
    ]])
end

function g.test_enabling()
    -- Scenario:
    -- 1. Stateboard goes down
    -- 2. Reenable failover
    -- 3. A1 is stuck on fetching first appointments, but remains writable
    -- 4. Stateboard returns
    -- 5. A1 persists his vclock
    -- 6. Enable failover-coordinator role, it shouldn't spoil vclock value

    A1.net_box:eval(q_set_wait_lsn_timeout, {0.2})
    B1.net_box:eval(q_set_wait_lsn_timeout, {0.2})

    -- Stateboard is unavailable
    g.stateboard:stop()

    -- Turn it off and on again
    local q_set_failover_params = [[
        local cartridge = require("cartridge")
        return cartridge.failover_set_params(...)
    ]]
    A1.net_box:eval(q_set_failover_params, {{mode = 'disabled'}})
    A1.net_box:eval(q_set_failover_params, {{mode = 'stateful'}})

    -- Constituting oneself fails, but it remains writable
    t.assert_equals(A1.net_box:eval(q_leadership, {uA}), uA1)
    t.assert_equals(A1.net_box:eval(q_readonliness), false)
    t.assert_equals(A1.net_box:eval(q_is_vclockkeeper), false)
    t.assert_items_include(
        helpers.list_cluster_issues(A1),
        {{
            level = "warning",
            topic = "failover",
            instance_uuid = box.NULL,
            replicaset_uuid = box.NULL,
            message = "Can't obtain failover coordinator:" ..
                " State provider unavailable",
        }, {
            level = "warning",
            topic = "failover",
            instance_uuid = uA1,
            replicaset_uuid = box.NULL  ,
            message = "Failover is stuck on " .. A1.advertise_uri ..
                " (A1): Error fetching first appointments:" ..
                " Connection refused",
        }, {
            level = "warning",
            topic = "switchover",
            instance_uuid = uA1,
            replicaset_uuid = uA,
            message = "Consistency on " .. A1.advertise_uri .. " (A1)" ..
                " isn't reached yet",
        }}
    )

    -- Repair stateboard (empty)
    fio.rmtree(g.stateboard.workdir)
    g.stateboard:start()
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
    end)
    g.session = g.client:get_session()

    -- A1 becomes a legitimate vclockkeeper
    helpers.retrying({}, function()
        t.assert_equals(A1.net_box:eval(q_is_vclockkeeper), true)
    end)
    t.assert_equals(g.session:get_leaders(), {})
    t.assert_equals(g.session:get_vclockkeeper(uA), {
        replicaset_uuid = uA,
        instance_uuid = uA1,
        vclock = A1.net_box:eval('return box.info.vclock'),
    })

    -- Enable coordinator
    A1.net_box:eval(
        [[require("cartridge").admin_edit_topology(...)]],
        {{replicasets = {{uuid = uA, roles = {'failover-coordinator'}}}}}
    )

    -- Coordinator promotes A1, but shouldn't spoil vclock
    helpers.retrying({}, function()
        t.assert_covers(g.session:get_leaders(), {[uA] = uA1})
    end)
    t.assert_equals(g.session:get_vclockkeeper(uA), {
        replicaset_uuid = uA,
        instance_uuid = uA1,
        vclock = A1.net_box:eval('return box.info.vclock'),
    })

    -- Everything is fine now
    t.assert_equals(A1.net_box:eval(q_leadership, {uA}), uA1)
    t.assert_equals(A1.net_box:eval(q_readonliness), false)
    t.assert_equals(A1.net_box:eval(q_is_vclockkeeper), true)
    t.assert_equals(helpers.list_cluster_issues(A1), {})

    -- Revert all hacks in fixtures
    A1.net_box:eval(
        [[require("cartridge").admin_edit_topology(...)]],
        {{replicasets = {{uuid = uA, roles = {}}}}}
    )
    t.assert_equals(g.session:get_coordinator(), box.NULL)
end

function g.test_api()
    -- Enable coordinator
    g.client:drop_session()
    g.session = g.client:get_session()
    t.assert_equals(g.session:get_coordinator(), box.NULL)
    A1.net_box:eval(
        [[require("cartridge").admin_edit_topology(...)]],
        {{replicasets = {{uuid = uA, roles = {'failover-coordinator'}}}}}
    )
    helpers.retrying({}, function()
        t.assert_covers(g.session:get_coordinator(), {uuid = uA1})
    end)

    local query = [[
        mutation(
            $replicaset_uuid: String!
            $instance_uuid: String!
        ) {
        cluster {
            failover_promote(
                replicaset_uuid: $replicaset_uuid
                instance_uuid: $instance_uuid
                force_inconsistency: true
            )
        }
    }]]

    -- Test GraphQL forceful promotion API
    t.assert(g.session:set_vclockkeeper(uB, 'nobody'))
    local resp = A1:graphql({
        query = query,
        variables = {
            replicaset_uuid = uB,
            instance_uuid = uB2,
        }
    })
    t.assert_type(resp['data'], 'table')
    t.assert_equals(resp['data']['cluster']['failover_promote'], true)
    t.assert_equals(g.session:get_vclockkeeper(uB), {
        replicaset_uuid = uB,
        instance_uuid = uB2,
    })

    -- Revert all hacks in fixtures
    A1.net_box:eval(
        [[require("cartridge").admin_edit_topology(...)]],
        {{replicasets = {{uuid = uA, roles = {}}}}}
    )
    t.assert_equals(g.session:get_coordinator(), box.NULL)
end

function g.test_all_rw()
    -- Replicasets with all_rw flag shouldn't fail on box.ctl.wait_ro().

    -- Make sure that B1 is a leader
    t.assert(g.session:set_leaders({{uB, uB1}}))
    helpers.retrying({}, function()
        t.assert_equals(A1.net_box:eval(q_leadership, {uB}), uB1)
        t.assert_equals(B1.net_box:eval(q_leadership, {uB}), uB1)
    end)

    -- Leader is rw, replica is ro
    t.assert_equals(B1.net_box:eval(q_is_vclockkeeper), true)
    t.assert_equals(B1.net_box:eval(q_readonliness), false)
    t.assert_equals(B2.net_box:eval(q_readonliness), true)

    local function set_all_rw(yesno)
        A1.net_box:eval(
            'require("cartridge").admin_edit_topology(...)',
            {{replicasets = {{uuid = uB, all_rw = yesno}}}}
        )
    end

    -- B: all_rw = true
    set_all_rw(true)
    t.assert_equals(B1.net_box:eval(q_is_vclockkeeper), false)
    t.assert_equals(B1.net_box:eval(q_readonliness), false)
    t.assert_equals(B2.net_box:eval(q_readonliness), false)

    -- Promote B1 (inconsistently)
    -- wait_lsn is doomed to fail
    -- but it will not be performed
    t.assert(g.session:set_leaders({{uB, uB2}}))
    helpers.retrying({}, function()
        t.assert_equals(B2.net_box:eval(q_leadership, {uB}), uB2)
    end)

    t.assert_equals(helpers.list_cluster_issues(A1), {})

    -- Revert all hacks in fixtures
    set_all_rw(false)
end
