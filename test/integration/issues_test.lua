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
end

function g.test_broken_replica()
    local master = g.cluster.main_server
    local replica1 = g.cluster:server('replica1')

    master.net_box:eval([[
        __replication = box.cfg.replication
        box.cfg{replication = box.NULL}
    ]])

    replica1.net_box:eval([[
        box.cfg{read_only = false}
        box.schema.space.create('test')
    ]])

    master.net_box:eval([[
        box.schema.space.create('test')
        pcall(box.cfg, {replication = __replication})
        __replication = nil
    ]])


    t.helpers.retrying({}, function()
        local issues = helpers.list_cluster_issues(master)

        t.assert_equals(
            helpers.table_find_by_attr(
                issues, 'instance_uuid', helpers.uuid('a', 'a', 2)
            ), {
                level = 'warning',
                topic = 'replication',
                replicaset_uuid = helpers.uuid('a'),
                instance_uuid = helpers.uuid('a', 'a', 2),
                message = "Replication from localhost:13301 (master)" ..
                    " to localhost:13302 (replica1) is stopped" ..
                    " (Duplicate key exists in unique index" ..
                    " 'primary' in space '_space')",
            }
        )
        t.assert_equals(
            helpers.table_find_by_attr(
                issues, 'instance_uuid', helpers.uuid('a', 'a', 3)
            ), {
                level = 'warning',
                topic = 'replication',
                replicaset_uuid = helpers.uuid('a'),
                instance_uuid = helpers.uuid('a', 'a', 3),
                message = "Replication from localhost:13301 (master)" ..
                    " to localhost:13303 (replica2) is stopped" ..
                    " (Duplicate key exists in unique index" ..
                    " 'primary' in space '_space')",
            }
        )
        if #issues ~= 4 then
            t.assert_not(issues)
        end
    end)
end

function g.test_config_mismatch()
    local master = g.cluster.main_server
    local replica2 = g.cluster:server('replica2')
    replica2.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        local cfg = confapplier.get_active_config():copy()
        cfg:set_plaintext('todo.txt', '- Test config mismatch')
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
end

function g.test_twophase_config_locked()
    local master = g.cluster.main_server
    local current_issues = helpers.list_cluster_issues(master)
    master.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        local cfg = confapplier.get_active_config():copy()
        require('cartridge.twophase').patch_clusterwide(cfg:get_plaintext())
    ]])

    -- Issue shouldn't appear during or after valid two-phase commit
    t.assert_items_equals(
        helpers.list_cluster_issues(master),
        current_issues
    )

    local issue = {
            level = 'warning',
            topic = 'configuration',
            instance_uuid = helpers.uuid('a', 'a', 3),
            replicaset_uuid = helpers.uuid('a'),
            message = 'Configuration is prepared and locked'..
                ' on localhost:13303 (replica2) but two-phase'..
                ' is not in progress',
    }

    local replica2 = g.cluster:server('replica2')
    replica2.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        local cfg = confapplier.get_active_config():copy()
        _G.__cartridge_clusterwide_config_prepare_2pc(cfg:get_plaintext())
    ]])

    -- It appears after a single prepare 2pc
    t.assert_items_include(
        helpers.list_cluster_issues(master),
        {issue}
    )

    -- And remains after instance's restart
    replica2:stop()
    replica2:start()
    t.assert_items_include(
        helpers.list_cluster_issues(master),
        {issue}
    )
end
