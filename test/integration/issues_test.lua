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
end)

g.after_all(function()
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
            level = 'warning',
            topic = 'replication',
            replicaset_uuid = g.cluster:server(to).replicaset_uuid,
            instance_uuid = g.cluster:server(to).instance_uuid,
            message = string.format("Replication" ..
                " from %s (%s) to %s (%s) is stopped" ..
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
            topic = 'configuration',
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
    require('log').info('test started')

    local master = g.cluster.main_server
    local replica1 = g.cluster:server('replica1')
    local replica2 = g.cluster:server('replica2')
    t.assert_equals(helpers.list_cluster_issues(master), {})
    t.assert_equals(helpers.list_cluster_issues(replica1), {})

    -- Make validate_config hang on replica2
    replica2.process:kill('STOP')

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
        topic = 'configuration',
        instance_uuid = master.instance_uuid,
        replicaset_uuid = master.replicaset_uuid,
        message = 'Configuration is prepared and locked'..
            ' on localhost:13301 (master)',
    }})

    t.assert_equals(future:is_ready(), false)
    replica2.process:kill('CONT')
    t.assert_equals(future:wait_result(), {true})

    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(master), {})
    end)
end
