local fio = require('fio')
local t = require('luatest')
local helpers = require('test.helper')

local etcd2_client = require('cartridge.etcd2-client')
local stateboard_client = require('cartridge.stateboard-client')

local g_etcd2 = t.group('integration.switchover.etcd2')
local g_stateboard = t.group('integration.switchover.stateboard')

local uA = helpers.uuid('a')
local uB = helpers.uuid('b')
local uA1 = helpers.uuid('a', 1, 1)
local uB1 = helpers.uuid('b', 1, 1)
local uB2 = helpers.uuid('b', 2, 2)
local A1
local B1
local B2

local function setup_cluster(g)
    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
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
end

g_stateboard.before_all(function()
    local g = g_stateboard
    g.datadir = fio.tempdir()

    fio.mktree(fio.pathjoin(g.datadir, 'stateboard'))
    g.kvpassword = helpers.random_cookie()
    g.state_provider = helpers.Stateboard:new({
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

    g.state_provider:start()
    helpers.retrying({}, function()
        g.state_provider:connect_net_box()
    end)

    g.client = stateboard_client.new({
        uri = '127.0.0.1:' .. g.state_provider.net_box_port,
        password = g.state_provider.net_box_credentials.password,
        call_timeout = 1,
    })

    setup_cluster(g)

    B1:call('box.schema.sequence.create', {'test'})
    B1:call('package.loaded.cartridge.failover_set_params', {{
        mode = 'stateful',
        state_provider = 'tarantool',
        tarantool_params = {
            uri = '127.0.0.1:' .. g.state_provider.net_box_port,
            password = g.kvpassword,
        },
    }})
end)

g_etcd2.before_all(function()
    local g = g_etcd2
    local etcd_path = os.getenv('ETCD_PATH')
    t.skip_if(etcd_path == nil, 'etcd missing')

    g.datadir = fio.tempdir()
    g.state_provider = helpers.Etcd:new({
        workdir = fio.tempdir('/tmp'),
        etcd_path = etcd_path,
        peer_url = 'http://127.0.0.1:17001',
        client_url = 'http://127.0.0.1:14001',
    })

    g.state_provider:start()
    g.client = etcd2_client.new({
        prefix = 'switchover_test',
        endpoints = {g.state_provider.client_url},
        lock_delay = 5,
        username = '',
        password = '',
        request_timeout = 1,
    })

    setup_cluster(g)

    B1:call('box.schema.sequence.create', {'test'})
    t.assert(A1:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            mode = 'stateful',
            state_provider = 'etcd2',
            etcd2_params = {
                prefix = 'switchover_test',
                endpoints = {g.state_provider.client_url},
                lock_delay = 5,
            },
        }}
    ))

end)

local function after_all(g)
    g.cluster:stop()
    g.state_provider:stop()
    fio.rmtree(g.state_provider.workdir)
    fio.rmtree(g.datadir)
end

g_etcd2.after_all(function() after_all(g_etcd2) end)
g_stateboard.after_all(function() after_all(g_stateboard) end)

local function before_each(g)
    g.session = g.client:get_session()
    t.assert(g.session:acquire_lock({uuid = 'test-uuid', uri = 'test'}))
    t.assert(g.session:set_vclockkeeper(uA, uA1))
    t.assert(g.session:set_vclockkeeper(uB, uB1))
    t.assert(g.session:set_leaders({{uA, uA1}, {uB, uB1}}))

    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(A1), {})
    end)
end

g_etcd2.before_each(function() before_each(g_etcd2) end)
g_stateboard.before_each(function() before_each(g_stateboard) end)

local function after_each(g)
    for _, srv in pairs(g.cluster.servers) do
        srv.process:kill('CONT')
    end
end

g_etcd2.after_each(function() after_each(g_etcd2) end)
g_stateboard.after_each(function() after_each(g_stateboard) end)

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

local function add(name, fn)
    g_stateboard[name] = fn
    g_etcd2[name] = fn
end

add('test_2pc_forceful', function(g)
    -- Testing scenario:
    -- 1. Promote B1 as a leader
    -- 2. An attempt to constitute_oneself fails
    -- 3. Trigger apply_config
    -- 4. An attempt to constitute_oneself still fails
    -- 5. Manually set B1 as vclockkeeper
    -- 6. Expect it to become rw

    -- Prevent wait_lsn from accomplishing successfully
    t.assert(g.session:set_vclockkeeper(uB, 'nobody'))
    t.assert(g.session:set_leaders({{uB, 'nobody'}}))
    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_leadership, {uB}), 'nobody')
    end)

    t.assert_equals(B1:eval(q_readonliness), true)
    t.assert_equals(B1:eval(q_is_vclockkeeper), false)

    -- Promote B1
    t.assert(g.session:set_leaders({{uB, uB1}}))
    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_leadership, {uB}), uB1)
    end)
    t.assert_equals(B1:eval(q_readonliness), true)
    t.assert_equals(B1:eval(q_is_vclockkeeper), false)

    A1:eval(q_set_wait_lsn_timeout, {0.1})

    -- Trigger apply_config
    -- An attempt to constitute_oneself fails
    local ok, err = B1:eval([[
        local confapplier = require('cartridge.confapplier')
        local active_config = confapplier.get_active_config()
        require('log').warn('Triggering apply_config')
        return confapplier.apply_config(active_config)
    ]])

    -- Applying configuration succeeds
    t.assert_equals({ok, err}, {true, nil})

    -- But B1 still waits LSN from "nobody" (forever)
    t.assert_equals(B1:eval(q_readonliness), true)
    t.assert_equals(B1:eval(q_is_vclockkeeper), false)
    t.assert_items_equals(
        helpers.list_cluster_issues(B1),
        {{
            level = "warning",
            topic = "switchover",
            instance_uuid = uB1,
            replicaset_uuid = uB,
            message = "Consistency on " .. B1.advertise_uri ..
                " (B1) isn't reached yet",
        }}
    )

    -- Manually set B1 as vclockkeeper
    t.assert(g.session:set_vclockkeeper(uB, uB1))

    -- Expect it to become rw
    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_readonliness), false)
        t.assert_equals(B1:eval(q_is_vclockkeeper), true)
    end)
end)

add('test_promotion_forceful', function(g)
   -- Scenario:
    -- 1. B1 is a leader and a vclockkeeper
    -- 2. B2 gets promoted but can't accomplish wait_lsn
    -- 3. B2 becomes a vclockkeeper through a force promotion

    B2:eval(q_set_wait_lsn_timeout, {0.2})
    t.assert_equals(B2:eval(q_leadership, {uB}), uB1)
    t.assert_equals(B2:eval(q_readonliness), true)

    -- Prevent wait_lsn from accomplishing successfully
    B1.process:kill('STOP')

    t.assert(g.session:set_leaders({{uB, uB2}}))
    t.assert_error_msg_equals("timed out",
        function() B2:call('box.ctl.wait_rw', {0.1}) end
    )

    -- B2 stucks on wait_lsn
    t.assert_equals(B2:eval(q_leadership, {uB}), uB2)
    t.assert_equals(B2:eval(q_readonliness), true)
    t.assert_equals(B2:eval(q_is_vclockkeeper), false)
        t.assert_covers(g.session:get_vclockkeeper(uB), {
        replicaset_uuid = uB,
        instance_uuid = uB1,
    })

    -- Manually set B2 as vclockkeeper
    t.assert(g.session:set_vclockkeeper(uB, uB2))

    -- Expect it to become rw
    helpers.retrying({}, function()
        t.assert_equals(B2:eval(q_readonliness), false)
        t.assert_equals(B2:eval(q_is_vclockkeeper), true)
    end)

    -- Revert all hacks in fixtures
    B1.process:kill('CONT')
    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(A1), {})
    end)
end)

add('test_promotion_abortion', function(g)
    -- Scenario:
    -- 1. B1 is a leader and a vclockkeeper
    -- 2. B2 gets promoted but can't accomplish wait_lsn
    -- 3. B1 is promoted back

    t.assert(g.session:set_leaders({{uB, uB1}}))
    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_is_vclockkeeper), true)
        t.assert_equals(B2:eval(q_is_vclockkeeper), false)
    end)

    -- Protect B2 from becoming rw
    helpers.protect_from_rw(B2)

    -- Prevent wait_lsn from accomplishing successfully
    B2:eval([[
        _r = box.cfg.replication
        box.cfg({replication = {}})
    ]])
    B1:call('box.sequence.test:next')

    -- Promote B2
    t.assert(g.session:set_leaders({{uB, uB2}}))
    t.assert_error_msg_equals("timed out",
        function() B2:call('box.ctl.wait_rw', {0.2}) end
    )

    t.assert_equals(B1:eval(q_leadership, {uB}), uB2)
    t.assert_equals(B2:eval(q_leadership, {uB}), uB2)
    t.assert_equals(B1:eval(q_readonliness), true)
    t.assert_equals(B2:eval(q_readonliness), true)
    t.assert_equals(B1:eval(q_is_vclockkeeper), false)
    t.assert_equals(B1:eval(q_is_vclockkeeper), false)
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
            level = "critical",
            topic = "replication",
            instance_uuid = uB2,
            replicaset_uuid = uB,
            message = "Replication" ..
                " from " .. B1.advertise_uri .. " (B1)" ..
                " to " .. B2.advertise_uri .. " (B2) isn't running",
        }}
    )
    t.assert_items_equals(
        helpers.get_suggestions(A1).restart_replication,
        {{uuid = uB2}}
    )

    -- Revert B1 leadership
    t.assert(g.session:set_leaders({{uB, uB1}}))

    -- Expect it to become rw
    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_readonliness), false)
        t.assert_equals(B2:eval(q_readonliness), true)
    end)

    -- Revert all hacks in fixtures
    B2:eval('box.cfg({replication = _r})')
    t.assert_error_msg_equals("timed out",
        function() B2:call('box.ctl.wait_rw', {0.2}) end
    )

    helpers.unprotect(B2)
end)

add('test_promotion_late', function(g)
    -- Scenario:
    -- 1. B1 is a leader and a vclockkeeper
    -- 2. B2 gets promoted but can't accomplish wait_lsn
    -- 3. wait_lsn succeeds and B2 finally becomes a vclockkeeper
    t.assert(g.session:set_leaders({{uB, uB1}}))
    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_is_vclockkeeper), true)
        t.assert_equals(B2:eval(q_is_vclockkeeper), false)
    end)

    -- Prevent wait_lsn from accomplishing successfully
    B2:eval([[
        _r = box.cfg.replication
        box.cfg({replication = {}})
    ]])
    B1:call('box.sequence.test:next')

    -- Promote B2
    t.assert(g.session:set_leaders({{uB, uB2}}))
    t.assert_error_msg_equals("timed out",
        function() B2:call('box.ctl.wait_rw', {0.1}) end
    )

    t.assert_equals(B1:eval(q_leadership, {uB}), uB2)
    t.assert_equals(B2:eval(q_leadership, {uB}), uB2)
    t.assert_equals(B1:eval(q_readonliness), true)
    t.assert_equals(B2:eval(q_readonliness), true)
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
            level = "critical",
            topic = "replication",
            instance_uuid = uB2,
            replicaset_uuid = uB,
            message = "Replication" ..
                " from " .. B1.advertise_uri .. " (B1)" ..
                " to " .. B2.advertise_uri .. " (B2) isn't running",
        }}
    )

    -- Repair replication
    B2:eval('box.cfg({replication = _r})')

    -- Expect it to become rw
    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_readonliness), true)
        t.assert_equals(B2:eval(q_readonliness), false)
    end)
end)

add('test_vclockkeeper_caching', function(g)
    -- Scenario:
    -- 1. B1 is a vclockkeeper
    -- 2. A2 (non-existant) gets promoted
    -- 3. B1 successfully longpolls new appointments
    -- 4. But B1 is unable to get info about vclockkeeper
    -- 5. apply_config is still triggered

    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_leadership, {uB}), uB1)
        t.assert_equals(B1:eval(q_readonliness), false)
        t.assert_equals(B1:eval(q_is_vclockkeeper), true)
    end)

    B1:eval([[
        local vars = require('cartridge.vars').new('cartridge.failover')
        _get_vclockkeeper_backup = vars.client.session.get_vclockkeeper
        vars.client.session.get_vclockkeeper = function()
            error('Banned', 0)
        end
    ]])

    -- Monkeypatch apply_config to count reconfiguration events
    B1:eval('loadstring(...)()', {
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

    t.assert_equals(B1:eval('return config_incarnation'), 0)

    t.assert(g.session:set_leaders({{uA, 'someone-else'}}))
    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_leadership, {uA}), 'someone-else')
    end)

    t.assert_equals(B1:eval('return config_incarnation'), 1)

    -- Revert all hacks in fixtures
    B1:eval([[
        local vars = require('cartridge.vars').new('cartridge.failover')
        vars.client.session.get_vclockkeeper = _get_vclockkeeper_backup
    ]])
end)

local function transform_vclock(vclock)
    local vclock_data = {}
    for k, v in pairs(vclock) do
        vclock_data[tonumber(k)] = v
    end
    return vclock_data
end

add('test_enabling', function(g)
    -- Scenario:
    -- 1. State provider goes down
    -- 2. Reenable failover
    -- 3. B1 is stuck on fetching first appointments, but remains writable
    -- 4. State provider returns
    -- 5. B1 persists his vclock
    -- 6. Enable failover-coordinator role, it shouldn't spoil vclock value

    A1:eval(q_set_wait_lsn_timeout, {0.2})
    B1:eval(q_set_wait_lsn_timeout, {0.2})

    -- State provider is unavailable
    g.state_provider:stop()
    g.session:drop()

    -- Turn it off and on again
    local q_set_failover_params = [[
        local cartridge = require("cartridge")
        return cartridge.failover_set_params(...)
    ]]
    A1:eval(q_set_failover_params, {{mode = 'disabled'}})
    A1:eval(q_set_failover_params, {{mode = 'stateful'}})

    -- Constituting oneself fails, but it remains writable
    t.assert_equals(B1:eval(q_leadership, {uB}), uB1)
    t.assert_equals(B1:eval(q_readonliness), false)
    t.assert_equals(B1:eval(q_is_vclockkeeper), false)
    if helpers.tarantool_version_ge('2.10.0') then
        local issues = helpers.list_cluster_issues(A1)
        t.assert_str_matches(issues[1].message, "Can't obtain failover coordinator:.*")
        t.assert_equals(issues[1].level, "warning")
        t.assert_str_matches(issues[2].message, "Failover is stuck on.*")
        t.assert_str_matches(issues[3].message, "Failover is stuck on.*")
        t.assert_str_matches(issues[4].message, "Failover is stuck on.*")
        t.assert_str_matches(issues[5].message, "Consistency on .* isn't reached yet")
    else
        t.assert_items_include(
            helpers.list_cluster_issues(A1),
            {{
                level = "warning",
                topic = "failover",
                instance_uuid = box.NULL,
                replicaset_uuid = box.NULL,
                message = "Can't obtain failover coordinator: " ..(
                    g.name == 'integration.switchover.etcd2' and
                    g.state_provider.client_url .. "/v2/members:" ..
                    " Couldn't connect to server" or
                    "State provider unavailable"),
            }, {
                level = "warning",
                topic = "failover",
                instance_uuid = uA1,
                replicaset_uuid = box.NULL  ,
                message = "Failover is stuck on " .. A1.advertise_uri ..
                    " (A1): Error fetching first appointments: " ..(
                    g.name == 'integration.switchover.etcd2' and
                    g.state_provider.client_url .. "/v2/members:" ..
                    " Couldn't connect to server" or
                    '"127.0.0.1:14401": Connection refused'),
            }, {
                level = "warning",
                topic = "switchover",
                instance_uuid = uB1,
                replicaset_uuid = uB,
                message = "Consistency on " .. B1.advertise_uri .. " (B1)" ..
                    " isn't reached yet",
            }}
        )
    end

    -- Repair state provider (empty)
    fio.rmtree(g.state_provider.workdir)
    g.state_provider:start()
    helpers.retrying({}, function()
        g.state_provider:connect_net_box()
    end)
    g.session = g.client:get_session()

    -- B1 becomes a legitimate vclockkeeper
    t.assert_equals(g.session:get_leaders(), {})
    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_is_vclockkeeper), true)
    end)

    t.assert_equals(g.session:get_leaders(), {})
    local vclockkeeper_data = g.session:get_vclockkeeper(uB)
    local vclock = B1:eval('return box.info.vclock')

    t.assert_equals({
        replicaset_uuid = vclockkeeper_data.replicaset_uuid,
        instance_uuid = vclockkeeper_data.instance_uuid,
    }, {
        replicaset_uuid = uB,
        instance_uuid = uB1,
    })

    t.assert_equals(vclock, transform_vclock(vclockkeeper_data.vclock))

    -- Enable coordinator
    A1:eval(
        [[require("cartridge").admin_edit_topology(...)]],
        {{replicasets = {{uuid = uA, roles = {'failover-coordinator'}}}}}
    )

    -- Coordinator promotes B1, but shouldn't spoil vclock
    helpers.retrying({}, function()
        t.assert_covers(g.session:get_leaders(), {[uB] = uB1})
    end)

    local vclockkeeper_data = g.session:get_vclockkeeper(uB)
    local vclock = B1:eval('return box.info.vclock')
    t.assert_equals({
        replicaset_uuid = vclockkeeper_data.replicaset_uuid,
        instance_uuid = vclockkeeper_data.instance_uuid,
    }, {
        replicaset_uuid = uB,
        instance_uuid = uB1,
    })

    t.assert_equals(vclock, transform_vclock(vclockkeeper_data.vclock))
    -- Everything is fine now
    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_leadership, {uB}), uB1)
        t.assert_equals(B1:eval(q_readonliness), false)
        t.assert_equals(B1:eval(q_is_vclockkeeper), true)
        t.assert_equals(helpers.list_cluster_issues(A1), {})
    end)

    -- Revert all hacks in fixtures
    A1:eval(
        [[require("cartridge").admin_edit_topology(...)]],
        {{replicasets = {{uuid = uA, roles = {}}}}}
    )
    helpers.retrying({}, function()
        t.assert_equals(g.session:get_coordinator(), box.NULL)
    end)
end)

add('test_api', function(g)
   -- Enable coordinator
    g.client:drop_session()
    g.session = g.client:get_session()
    t.assert_equals(g.session:get_coordinator(), box.NULL)
    A1:eval(q_set_wait_lsn_timeout, {0.2})
    B2:eval(q_set_wait_lsn_timeout, {0.2})
    helpers.protect_from_rw(B2)

    A1:eval(
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
            $force: Boolean
        ) {
        cluster {
            failover_promote(
                replicaset_uuid: $replicaset_uuid
                instance_uuid: $instance_uuid
                force_inconsistency: $force
            )
        }
    }]]

    -- Disrupt successfull switchover
    t.assert(g.session:set_vclockkeeper(uB, 'nobody'))

    -- Hack set_vclockkeeper (inconcistency forcing) to fail
    A1:eval([[
        local vars = require('cartridge.vars').new('cartridge.failover')
        vars.client.session.set_vclockkeeper = function()
            return nil, require('errors').new('ArtificialError', 'Boo')
        end
    ]])
    helpers.retrying({}, function()
        t.assert_error_msg_equals(
            "Promotion succeeded, but inconsistency wasn't forced: Boo",
            A1.graphql, A1, {
                query = query,
                variables = {
                    replicaset_uuid = uB,
                    instance_uuid = uB2,
                    force = true,
                },
            }
        )
    end)

    -- Check intermediate state: B2 is a leader, but can't sync up
    helpers.retrying({}, function()
        t.assert_equals(B2:eval(q_leadership, {uB}), uB2)
    end)
    t.assert_equals(B2:eval(q_is_vclockkeeper), false)
    t.assert_equals(
        helpers.list_cluster_issues(A1),
        {{
            level = "warning",
            topic = "switchover",
            instance_uuid = uB2,
            replicaset_uuid = uB,
            message = "Consistency on " .. B2.advertise_uri ..
                " (B2) isn't reached yet",
        }}
    )

    -- Revert the hack
    A1:eval([[
        local vars = require('cartridge.vars').new('cartridge.failover')
        vars.client:drop_session()
        vars.client:get_session()
    ]])

    -- Consistent promotion fails because the keeper is still "nobody"
    t.assert_error_msg_equals(
        '"localhost:13303": timed out',
        A1.graphql, A1, {
            query = query,
            variables = {
                replicaset_uuid = uB,
                instance_uuid = uB2,
            },
        }
    )

    -- Now force inconsistency
    helpers.unprotect(B2)
    local resp = A1:graphql({
        query = query,
        variables = {
            replicaset_uuid = uB,
            instance_uuid = uB2,
            force = true,
        }
    })
    t.assert_type(resp['data'], 'table')
    t.assert_equals(resp.data, {cluster = {failover_promote = true}})
    helpers.retrying({}, function()
        t.assert_equals(B2:eval(q_is_vclockkeeper), true)
    end)
    t.assert_equals(helpers.list_cluster_issues(A1), {})
    local vclockkeeper_data = g.session:get_vclockkeeper(uB)
    if helpers.tarantool_version_ge('2.6.1') then
        -- promote adds 1 to vclocks

        vclockkeeper_data.vclock = transform_vclock(vclockkeeper_data.vclock)
        vclockkeeper_data.vclock[0] = vclockkeeper_data.vclock[0] + 1
        vclockkeeper_data.vclock[2] = vclockkeeper_data.vclock[2] + 1
    end

    t.assert_equals(vclockkeeper_data, {
        replicaset_uuid = uB,
        instance_uuid = uB2,
        vclock = B2:eval('return box.info.vclock'),
    })

    -- Revert all hacks in fixtures
    helpers.retrying({}, function()
        A1:exec(function(...)
            require("cartridge").admin_edit_topology(...)
        end, {{replicasets = {{uuid = uA, roles = {}}}}})
        t.assert_equals(g.session:get_coordinator(), box.NULL)
    end)
end)

add('test_all_rw', function(g)
    -- Replicasets with all_rw flag shouldn't fail on box.ctl.wait_ro().

    -- Make sure that B1 is a leader
    t.assert(g.session:set_leaders({{uB, uB1}}))
    helpers.retrying({}, function()
        t.assert_equals(A1:eval(q_leadership, {uB}), uB1)
        t.assert_equals(B1:eval(q_leadership, {uB}), uB1)
    end)

    -- Leader is rw, replica is ro
    helpers.retrying({}, function()
        t.assert_equals(B1:eval(q_is_vclockkeeper), true)
        t.assert_equals(B1:eval(q_readonliness), false)
        t.assert_equals(B2:eval(q_readonliness), true)
    end)
    local function set_all_rw(yesno)
        A1:eval(
            'require("cartridge").admin_edit_topology(...)',
            {{replicasets = {{uuid = uB, all_rw = yesno}}}}
        )
    end

    -- B: all_rw = true
    set_all_rw(true)
    t.assert_equals(B1:eval(q_is_vclockkeeper), false)
    t.assert_equals(B1:eval(q_readonliness), false)
    t.assert_equals(B2:eval(q_readonliness), false)

    -- Promote B1 (inconsistently)
    -- wait_ro is doomed to fail, but it won't be executed
    t.assert(g.session:set_leaders({{uB, uB2}}))
    helpers.retrying({}, function()
        t.assert_equals(B2:eval(q_leadership, {uB}), uB2)
    end)

    t.assert_equals(helpers.list_cluster_issues(A1), {})

    -- Revert all hacks in fixtures
    set_all_rw(false)
end)

add('test_alone_instance', function(g)
    -- Single-instance replicaset doesn't need consistency.

    t.assert_equals(A1:eval(q_readonliness), false)
    t.assert_equals(A1:eval(q_is_vclockkeeper), false)
    t.assert_equals(A1:eval(q_leadership, {uA}), uA1)
    t.assert_equals(g.session:get_vclockkeeper(uA), {
        replicaset_uuid = uA,
        instance_uuid = uA1,
        vclock = nil,
    })
end)
