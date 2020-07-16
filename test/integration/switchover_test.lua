local log = require('log')
local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local X = helpers.uuid('a')
local X1 = helpers.uuid('a', 1, 1)

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
            TARANTOOL_LOCK_DELAY = "9000",
            TARANTOOL_PASSWORD = g.kvpassword,
        },
    })
    g.stateboard:start()
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
    end)
    assert(g.stateboard.net_box:call('acquire_lock', {{uuid = 'test-uuid', uri = 'test'}}))
    assert(g.stateboard.net_box:call('set_leaders', {{{X, 'nobody'}}}))
    assert(g.stateboard.net_box:call('set_vclockkeeper', {X, 'nobody', {}}))

    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {{
            uuid = X,
            roles = {},
            servers = {{alias = 'X1', instance_uuid = X1}},
        }},
    })

    g.cluster:start()
    g.cluster.main_server.net_box:eval([[
        local vars = require('cartridge.vars').new('cartridge.failover')
        vars.options.WAITLSN_TIMEOUT = 0.2
    ]])
    g.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            mode = 'stateful',
            state_provider = 'tarantool',
            tarantool_params = {
                uri = g.stateboard.net_box_uri,
                password = g.kvpassword,
            },
        }}
    )
end)

g.after_all(function()
    g.cluster:stop()
    g.stateboard:stop()
    fio.rmtree(g.datadir)
end)

local q_readonliness = "return box.info.ro"
local q_patch_clusterwide = [[
    local cartridge = require('cartridge')
    return cartridge.config_patch_clusterwide(...)
]]
local q_leadership = [[
    local failover = require('cartridge.failover')
    return failover.get_active_leaders()[...]
]]
local function eval(alias, ...)
    return g.cluster:server(alias).net_box:eval(...)
end

function g.test_consistent_promote()
    -- Testing scenario:
    -- 1. Promote X1 as a leader
    -- 2. Trigger two-phase commit
    -- 3. An attempt to constitute_oneself fails
    -- 4. Manually set X1 as vclockkeeper
    -- 5. Expect it to become rw

    t.assert_equals(eval('X1', q_leadership, {X}), 'nobody')
    t.assert_equals(eval('X1', q_readonliness), true)
    t.assert_items_equals(helpers.list_cluster_issues(g.cluster.main_server), {})

    -- Promote X1 as a leader
    t.assert(g.stateboard.net_box:call('set_leaders', {{{X, X1}}}))

    helpers.retrying({}, function()
        t.assert_equals(eval('X1', q_leadership, {X}), X1)
    end)
    t.assert_equals(eval('X1', q_readonliness), true)
    t.assert_items_equals(helpers.list_cluster_issues(g.cluster.main_server), {{
        level = "warning",
        topic = "failover",
        instance_uuid = X1,
        replicaset_uuid = box.NULL,
        message = "Failover is stuck on " ..
            g.cluster:server('X1').advertise_uri ..
            " (X1): Consistency not reached yet",
    }})

    -- Trigger two-phase commit
    -- An attempt to constitute_oneself fails
    local ok, err = eval('X1', q_patch_clusterwide, {{secret = '42867f0'}})
    t.assert_equals({ok, err}, {true, nil})

    -- Manually set X1 as vclockkeeper
    t.assert(g.stateboard.net_box:call('set_vclockkeeper', {X, X1, {}}))

    -- Expect it to become rw
    helpers.retrying({}, function()
        t.assert_equals(eval('X1', q_readonliness), false)
    end)
end

