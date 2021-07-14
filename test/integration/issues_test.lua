local t = require('luatest')
local g = t.group()

local fio = require('fio')
local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {},
            servers = {{
                alias = 'master',
                instance_uuid = helpers.uuid('a', 'a', 1)
            }, {
                alias = 'replica1',
                instance_uuid = helpers.uuid('a', 'a', 2)
            }, {
                alias = 'replica2',
                instance_uuid = helpers.uuid('a', 'a', 3)
            }},
        }},
        env = {
            TARANTOOL_CLOCK_DELTA_THRESHOLD_WARNING = 100000000,
            TARANTOOL_FRAGMENTATION_THRESHOLD_WARNING = 100000000,
            TARANTOOL_FRAGMENTATION_THRESHOLD_CRITICAL = 100000000,
        }
    })
    g.cluster:start()

    g.alien = helpers.Server:new({
        alias = 'alien',
        workdir = fio.pathjoin(g.cluster.datadir, 'alien'),
        command = helpers.entrypoint('srv_basic'),
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13309,
        http_port = 8089,
    })
end)

g.after_all(function()
    g.alien:stop()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_issues_limits()
    local server = g.cluster:server('master')
    t.assert_equals(
        server.net_box:eval("return require('cartridge.vars').new('cartridge.issues').limits"),
        {
            clock_delta_threshold_warning = 100000000,
            fragmentation_threshold_warning = 100000000,
            fragmentation_threshold_critical = 100000000
        }
    )

    -- restore to defaults by calling set_limits
    server.net_box:eval([[require("cartridge.issues").set_limits({
        clock_delta_threshold_warning = 5,
        fragmentation_threshold_warning = 0.6,
        fragmentation_threshold_critical = 0.9
    })]])
    t.assert_equals(
        server.net_box:eval("return require('cartridge.vars').new('cartridge.issues').limits"),
        {
            clock_delta_threshold_warning = 5,
            fragmentation_threshold_warning = 0.6,
            fragmentation_threshold_critical = 0.9
        }
    )

    t.assert_equals(helpers.list_cluster_issues(server), {})
end

function g.test_broken_replica()
    local master = g.cluster.main_server
    local replica1 = g.cluster:server('replica1')
    local replica2 = g.cluster:server('replica2')

    master.net_box:eval([[
        __replication = box.cfg.replication
        box.cfg{replication = box.NULL}
    ]])

    replica1.net_box:eval([[
        box.cfg{read_only = false}
        box.schema.space.create('test')
    ]])
    t.helpers.retrying({}, function()
        replica2.net_box:eval('assert(box.space.test)')
    end)

    master.net_box:eval([[
        box.schema.space.create('test')
        pcall(box.cfg, {replication = __replication})
        __replication = nil
    ]])

    local function issue_fmt(from, to)
        return {
            level = 'critical',
            topic = 'replication',
            replicaset_uuid = g.cluster:server(to).replicaset_uuid,
            instance_uuid = g.cluster:server(to).instance_uuid,
            message = string.format("Replication" ..
                " from %s (%s) to %s (%s) state \"stopped\"" ..
                " (Duplicate key exists in unique index" ..
                " 'primary' in space '_space')",
                g.cluster:server(from).advertise_uri, from,
                g.cluster:server(to).advertise_uri, to
            )
        }
    end

    t.helpers.retrying({}, function()
        t.assert_items_equals(helpers.list_cluster_issues(master), {
            issue_fmt('master', 'replica1'),
            issue_fmt('master', 'replica2'),
            issue_fmt('replica1', 'master'),
            issue_fmt('replica2', 'master'),
        })
    end)

    for _, srv in ipairs({master, replica1, replica2}) do
        srv.net_box:eval([[
            box.cfg({replication_skip_conflict = true})
            __replication = box.cfg.replication
            pcall(box.cfg, {replication = box.NULL})
            pcall(box.cfg, {replication = __replication})
            __replication = nil
        ]])
    end

    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(master), {})
    end)

    master.net_box:eval([[
        box.space.test:drop()
    ]])
end

function g.test_replication_idle()
    local master = g.cluster.main_server
    local replica1 = g.cluster:server('replica1')
    local replica2 = g.cluster:server('replica2')

    -- Set up network partitioning to avoid request hanging.
    -- Without it, the issues query does pool.map_call
    -- and waits for timeout on stopped replicas.
    -- With this hack, pool.map_call returns "Connection refused"
    -- immediately.
    replica1.net_box:call('box.cfg', {{listen = box.NULL}})
    replica2.net_box:call('box.cfg', {{listen = box.NULL}})
    master.net_box:eval([[
        local pool = require('cartridge.pool')
        pool.connect('localhost:13302', {wait_connected = false}):close()
        pool.connect('localhost:13303', {wait_connected = false}):close()
    ]])

    replica1.process:kill('STOP')
    replica2.process:kill('STOP')

    local resp

    t.helpers.retrying({}, function()
        resp = master:graphql({query = [[{
            cluster {
                issues { level topic instance_uuid replicaset_uuid }
                issues_msg: issues { message }
            }
        }]]}).data.cluster

        -- there're two similar issues for each replica
        local _i = {
            level = 'warning',
            topic = 'replication',
            instance_uuid = master.instance_uuid,
            replicaset_uuid = master.replicaset_uuid,
        }
        t.assert_equals(resp.issues, {_i, _i})
    end)

    t.assert_str_matches(
        resp.issues_msg[1].message,
        'Replication from localhost:1330[23] %(replica[12]%)' ..
        ' to localhost:13301 %(master%): long idle %(.+ > 1%)'
    )

    -- Revert all the hacks
    replica1.process:kill('CONT')
    replica2.process:kill('CONT')
    g.cluster:stop()
    g.cluster:start()

    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(master), {})
    end)
end

function g.test_config_mismatch()
    local master = g.cluster.main_server
    local replica2 = g.cluster:server('replica2')
    replica2.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        local cfg = confapplier.get_active_config():copy()
        cfg:set_plaintext('todo1.txt', '- Test config mismatch')
        cfg:lock()
        confapplier.apply_config(cfg)
    ]])

    t.assert_items_include(
        helpers.list_cluster_issues(master),
        {{
            level = 'warning',
            topic = 'config_mismatch',
            instance_uuid = helpers.uuid('a', 'a', 3),
            replicaset_uuid = helpers.uuid('a'),
            message = 'Configuration checksum mismatch' ..
                ' on localhost:13303 (replica2)',
        }}
    )

    replica2.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        local cfg = confapplier.get_active_config():copy()
        cfg:set_plaintext('todo1.txt', nil)
        cfg:lock()
        confapplier.apply_config(cfg)
    ]])

    t.assert_equals(helpers.list_cluster_issues(master), {})
end

function g.test_twophase_config_locked()
    local master = g.cluster.main_server
    local replica1 = g.cluster:server('replica1')
    local replica2 = g.cluster:server('replica2')
    t.assert_equals(helpers.list_cluster_issues(master), {})
    t.assert_equals(helpers.list_cluster_issues(replica1), {})

    -- Make validate_config hang on replica2
    replica2.net_box:eval([[
        _G.inf_sleep = true
        local prepare_2pc = _G.__cartridge_clusterwide_config_prepare_2pc
        _G.__cartridge_clusterwide_config_prepare_2pc = function(...)
            while _G.inf_sleep do
                require('fiber').sleep(0.1)
            end
            return prepare_2pc(...)
        end
    ]])

    local future = master.net_box:call(
        'package.loaded.cartridge.config_patch_clusterwide',
        {{['todo2.txt'] = '- Test 2pc lock'}},
        {is_async = true}
    )

    t.helpers.retrying({}, function()
        t.assert_equals(fio.path.exists(master.workdir .. '/config.prepare'), true)
        t.assert_equals(fio.path.exists(replica1.workdir .. '/config.prepare'), true)
        t.assert_equals(fio.path.exists(replica2.workdir .. '/config.prepare'), false)
    end)

    -- It's not an issue when config is locked while 2pc is in progress
    t.assert_equals(helpers.list_cluster_issues(master), {})

    -- But it's an issue from replicas point of view
    t.assert_items_include(helpers.list_cluster_issues(replica1), {{
        level = 'warning',
        topic = 'config_locked',
        instance_uuid = master.instance_uuid,
        replicaset_uuid = master.replicaset_uuid,
        message = 'Configuration is prepared and locked'..
            ' on localhost:13301 (master)',
    }})

    t.assert_equals(future:is_ready(), false)
    replica2.net_box:eval('_G.inf_sleep = nil')
    t.assert_equals(future:wait_result(), {true})

    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(master), {})
    end)
end

function g.test_state_hangs()
    local master = g.cluster.main_server
    local replica1 = g.cluster:server('replica1')

    local set_state = [[
        require('cartridge.confapplier').set_state(...)
    ]]
    local set_timeout = [[
        require('cartridge.vars').new('cartridge.confapplier').
        state_notification_timeout = ...
    ]]

    t.assert_equals(helpers.list_cluster_issues(master), {})

    replica1.net_box:eval(set_timeout, {0.1})
    replica1.net_box:eval(set_state, {'ConfiguringRoles'})

    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(master), {{
            level = 'warning',
            topic = 'state_stuck',
            instance_uuid = replica1.instance_uuid,
            replicaset_uuid = replica1.replicaset_uuid,
            message = 'Configuring roles is stuck'..
                ' on localhost:13302 (replica1)' ..
                ' and hangs for 1s so far',
        }})
    end)

    -- nil will restore default timeout value
    replica1.net_box:eval(set_timeout, {})
    replica1.net_box:eval(set_state, {'RolesConfigured'})

    t.assert_equals(helpers.list_cluster_issues(master), {})
end

function g.test_aliens()
    local master = g.cluster.main_server

    g.alien:start()
    helpers.run_remotely(g.alien, function()
        local membership = require('membership')
        membership.set_payload('uuid', '( OO )')
        membership.probe_uri('localhost:13301')
    end)

    t.assert_equals(helpers.list_cluster_issues(master), {{
        level = 'warning',
        topic = 'aliens',
        message = 'Instance localhost:13309 (alien)' ..
            ' with alien uuid is in the membership',
    }})

    g.alien:stop()
    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(master), {})
    end)
end
