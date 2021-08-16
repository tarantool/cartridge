local t = require('luatest')
local g = t.group()

local fio = require('fio')
local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
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
        }, {
            uuid = helpers.uuid('b'),
            roles = {'vshard-storage'},
            servers = {{
                alias = 'master1',
                instance_uuid = helpers.uuid('b', 'b', 1)
            }}
        }, {
            uuid = helpers.uuid('c'),
            roles = {'vshard-router'},
            servers = {{
                alias = 'router',
                instance_uuid = helpers.uuid('c', 'c', 1)
            }},
        }},
        env = {
            TARANTOOL_CLOCK_DELTA_THRESHOLD_WARNING = math.huge,
            TARANTOOL_FRAGMENTATION_THRESHOLD_WARNING = 1,
            TARANTOOL_FRAGMENTATION_THRESHOLD_CRITICAL = 1,
        }
    })
    g.cluster:start()

    g.master = g.cluster:server('master')
    g.replica1 = g.cluster:server('replica1')
    g.replica2 = g.cluster:server('replica2')

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

g.before_each(function()
    helpers.retrying({}, function()
        t.assert_equals(
            helpers.list_cluster_issues(g.cluster.main_server),
            {}
        )
    end)
end)

function g.test_issues_limits()
    local server = g.cluster:server('master')

    t.assert_equals(
        server:eval("return require('cartridge.vars').new('cartridge.issues').limits"),
        {
            clock_delta_threshold_warning = math.huge,
            fragmentation_threshold_warning = 1,
            fragmentation_threshold_critical = 1,
        }
    )

    server:eval([[
        local cartridge_issues = require("cartridge.issues")
        cartridge_issues.set_limits(cartridge_issues.default_limits)
    ]])
    t.assert_equals(
        server:eval("return require('cartridge.vars').new('cartridge.issues').limits"),
        {
            clock_delta_threshold_warning = 5,
            fragmentation_threshold_warning = 0.6,
            fragmentation_threshold_critical = 0.9
        }
    )

    t.assert_equals(helpers.list_cluster_issues(server), {})
end

function g.test_broken_replica()
    g.master:eval([[
        __replication = box.cfg.replication
        box.cfg{replication = box.NULL}
    ]])

    g.replica1:eval([[
        box.cfg{read_only = false}
        box.schema.space.create('test')
    ]])
    t.helpers.retrying({}, function()
        g.replica2:eval('assert(box.space.test)')
    end)

    g.master:eval([[
        box.schema.space.create('test')
        pcall(box.cfg, {replication = __replication})
        __replication = nil
    ]])

    local function issue_fmt(from, to)
        local message
        if helpers.tarantool_version_ge('2.8.0') then
            message = string.format("Replication" ..
                " from %s (%s) to %s (%s) state \"stopped\"" ..
                " (Duplicate key exists in unique index" ..
                " \"primary\" in space \"_space\"" ..
                " with old tuple - [512, 1, \"test\"," ..
                " \"memtx\", 0, {}, []] and new tuple -"..
                " [512, 1, \"test\", \"memtx\", 0, {}, []])",
                g.cluster:server(from).advertise_uri, from,
                g.cluster:server(to).advertise_uri, to
            )
        else
            message = string.format("Replication" ..
                " from %s (%s) to %s (%s) state \"stopped\"" ..
                " (Duplicate key exists in unique index" ..
                " 'primary' in space '_space')",
                g.cluster:server(from).advertise_uri, from,
                g.cluster:server(to).advertise_uri, to
            )
        end

        return {
            level = 'critical',
            topic = 'replication',
            replicaset_uuid = g.cluster:server(to).replicaset_uuid,
            instance_uuid = g.cluster:server(to).instance_uuid,
            message = message
        }
    end

    t.helpers.retrying({}, function()
        t.assert_items_equals(helpers.list_cluster_issues(g.master), {
            issue_fmt('master', 'replica1'),
            issue_fmt('master', 'replica2'),
            issue_fmt('replica1', 'master'),
            issue_fmt('replica2', 'master'),
        })

        t.assert_items_equals(
            helpers.get_suggestions(g.master).restart_replication, {
            {uuid = g.cluster:server('master').instance_uuid},
            {uuid = g.cluster:server('replica1').instance_uuid},
            {uuid = g.cluster:server('replica2').instance_uuid},
        })
    end)

    for _, srv in ipairs({g.master, g.replica1, g.replica2}) do
        srv:eval([[
            box.cfg({replication_skip_conflict = true})
        ]])
    end

    -- Test restart_replication API
    g.master:graphql({
        query = [[
            mutation ($uuids : [String!]) {
                cluster {
                    restart_replication(uuids: $uuids)
                }
            }
        ]],
        variables = {uuids = {
            g.master.instance_uuid,
            g.replica1.instance_uuid,
            g.replica2.instance_uuid
        }}
    })


    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.master), {})
    end)

    g.master:eval([[
        box.space.test:drop()
    ]])
end

function g.test_replication_idle()
    -- Set up network partitioning to avoid request hanging.
    -- Without it, the issues query does pool.map_call
    -- and waits for timeout on stopped replicas.
    -- With this hack, pool.map_call returns "Connection refused"
    -- immediately.
    g.replica1:call('box.cfg', {{listen = box.NULL}})
    g.replica2:call('box.cfg', {{listen = box.NULL}})
    g.master:eval([[
        local pool = require('cartridge.pool')
        pool.connect('localhost:13302', {wait_connected = false}):close()
        pool.connect('localhost:13303', {wait_connected = false}):close()
    ]])

    g.replica1.process:kill('STOP')
    g.replica2.process:kill('STOP')

    local resp

    t.helpers.retrying({}, function()
        resp = g.master:graphql({query = [[{
            cluster {
                issues { level topic instance_uuid replicaset_uuid }
                issues_msg: issues { message }
                suggestions { restart_replication {uuid} }
            }
        }]]}).data.cluster

        -- there're two similar issues for each replica
        local _i = {
            level = 'warning',
            topic = 'replication',
            instance_uuid = g.master.instance_uuid,
            replicaset_uuid = g.master.replicaset_uuid,
        }
        t.assert_equals(resp.issues, {_i, _i})
    end)

    t.assert_str_matches(
        resp.issues_msg[1].message,
        'Replication from localhost:1330[23] %(replica[12]%)' ..
        ' to localhost:13301 %(master%): long idle %(.+ > 1%)'
    )

    -- Warning isn't a reason for showing suggestion
    t.assert_equals(
        resp.suggestions,
        {restart_replication = box.NULL}
    )
end

g.after_test('test_replication_idle', function()
    -- Revert all the hacks
    g.replica1.process:kill('CONT')
    g.replica2.process:kill('CONT')
    g.cluster:stop()
    g.cluster:start()

    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.master), {})
    end)
end)

function g.test_config_mismatch()
    g.replica2:eval([[
        local confapplier = require('cartridge.confapplier')
        local cfg = confapplier.get_active_config():copy()
        cfg:set_plaintext('todo1.txt', '- Test config mismatch')
        cfg:lock()
        confapplier.apply_config(cfg)
    ]])

    t.assert_items_include(
        helpers.list_cluster_issues(g.master),
        {{
            level = 'warning',
            topic = 'config_mismatch',
            instance_uuid = helpers.uuid('a', 'a', 3),
            replicaset_uuid = helpers.uuid('a'),
            message = 'Configuration checksum mismatch' ..
                ' on localhost:13303 (replica2)',
        }}
    )

    g.replica2:eval([[
        local confapplier = require('cartridge.confapplier')
        local cfg = confapplier.get_active_config():copy()
        cfg:set_plaintext('todo1.txt', nil)
        cfg:lock()
        confapplier.apply_config(cfg)
    ]])

    t.assert_equals(helpers.list_cluster_issues(g.master), {})
end

function g.test_twophase_config_locked()
    t.assert_equals(helpers.list_cluster_issues(g.master), {})
    t.assert_equals(helpers.list_cluster_issues(g.replica1), {})

    -- Make validate_config hang on replica2
    g.replica2:eval([[
        _G.inf_sleep = true
        local prepare_2pc = _G.__cartridge_clusterwide_config_prepare_2pc
        _G.__cartridge_clusterwide_config_prepare_2pc = function(...)
            while _G.inf_sleep do
                require('fiber').sleep(0.1)
            end
            return prepare_2pc(...)
        end
    ]])

    local future = g.master:call(
        'package.loaded.cartridge.config_patch_clusterwide',
        {{['todo2.txt'] = '- Test 2pc lock'}},
        {is_async = true}
    )

    t.helpers.retrying({}, function()
        t.assert_equals(fio.path.exists(g.master.workdir .. '/config.prepare'), true)
        t.assert_equals(fio.path.exists(g.replica1.workdir .. '/config.prepare'), true)
        t.assert_equals(fio.path.exists(g.replica2.workdir .. '/config.prepare'), false)
    end)

    -- It's not an issue when config is locked while 2pc is in progress
    t.assert_equals(helpers.list_cluster_issues(g.master), {})

    -- But it's an issue from replicas point of view
    t.assert_items_include(helpers.list_cluster_issues(g.replica1), {{
        level = 'warning',
        topic = 'config_locked',
        instance_uuid = g.master.instance_uuid,
        replicaset_uuid = g.master.replicaset_uuid,
        message = 'Configuration is prepared and locked'..
            ' on localhost:13301 (master)',
    }})

    t.assert_equals(future:is_ready(), false)
    g.replica2:eval('_G.inf_sleep = nil')
    t.assert_equals(future:wait_result(), {true})

    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.master), {})
    end)
end

function g.test_state_hangs()
    local set_state = [[
        require('cartridge.confapplier').set_state(...)
    ]]
    local set_timeout = [[
        require('cartridge.vars').new('cartridge.confapplier').
        state_notification_timeout = ...
    ]]

    t.assert_equals(helpers.list_cluster_issues(g.master), {})

    g.replica1:eval(set_timeout, {0.1})
    g.replica1:eval(set_state, {'ConfiguringRoles'})

    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.master), {{
            level = 'warning',
            topic = 'state_stuck',
            instance_uuid = g.replica1.instance_uuid,
            replicaset_uuid = g.replica1.replicaset_uuid,
            message = 'Configuring roles is stuck'..
                ' on localhost:13302 (replica1)' ..
                ' and hangs for 1s so far',
        }})
    end)

    -- nil will restore default timeout value
    g.replica1:eval(set_timeout, {})
    g.replica1:eval(set_state, {'RolesConfigured'})

    t.assert_equals(helpers.list_cluster_issues(g.master), {})
end

function g.test_aliens()
    g.alien:start()

    -- Test restart_replication API
    local _, err = g.alien:eval([[
        return require('cartridge.confapplier').restart_replication()
    ]])
    t.assert_equals(err.err, "Current instance isn't bootstrapped yet")

    helpers.run_remotely(g.alien, function()
        local membership = require('membership')
        membership.set_payload('uuid', '( OO )')
        membership.probe_uri('localhost:13301')
    end)

    t.assert_equals(helpers.list_cluster_issues(g.master), {{
        level = 'warning',
        topic = 'aliens',
        message = 'Instance localhost:13309 (alien)' ..
            ' with alien uuid is in the membership',
    }})
end

g.after_test('test_aliens', function()
    g.alien:stop()
    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.master), {})
    end)
end)

function g.test_vshard_buckets_invalid_cfg()
    g.cluster:server('router').net_box:eval([[
        __module_vshard_router.routers._static_router.known_bucket_count = 3500
    ]])

    t.assert_covers(helpers.list_cluster_issues(g.master), {{
        level = "warning",
        message = "Invalid configuration: "..
            "probably router's cfg.bucket_count is different from storages' one, difference is 500",
        topic = "vshard",
        instance_uuid = g.cluster:server('router').instance_uuid,
        replicaset_uuid = g.cluster:server('router').replicaset_uuid,
    }})

end

g.after_test('test_vshard_buckets_invalid_cfg', function()
    g.cluster:server('router').net_box:eval([[
        __module_vshard_router.routers._static_router.known_bucket_count = 3000
    ]])
end)

function g.test_vshard_buckets_not_discovered()
    g.cluster.main_server.net_box:eval([[
        require('cartridge').admin_disable_servers({...})
    ]], {g.cluster:server('master1').instance_uuid})

    t.assert_covers(helpers.list_cluster_issues(g.master), {{
        level = "warning",
        message = "3000 buckets are not discovered",
        topic = "vshard",
        instance_uuid = g.cluster:server('router').instance_uuid,
        replicaset_uuid = g.cluster:server('router').replicaset_uuid,
    }})

end

g.after_test('test_vshard_buckets_not_discovered', function()
    g.cluster.main_server.net_box:eval([[
        require('cartridge').admin_enable_servers({...})
    ]], {g.cluster:server('master1').instance_uuid})
end)
