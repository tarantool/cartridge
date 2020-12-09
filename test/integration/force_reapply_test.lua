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
            alias = 'A',
            roles = {},
            servers = 3,
        }},
    })
    g.cluster:start()
    g.A1 = g.cluster:server('A-1')
    g.A2 = g.cluster:server('A-2')
    g.A3 = g.cluster:server('A-3')
    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.A1), {})
    end)
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)


function g.test_twophase_config_locked()
    -- Let's put a spoke in two-phase's wheel
    local config = g.A1.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        return confapplier.get_active_config():get_plaintext()
    ]])
    config['hey.txt'] = 'Hello, locks'
    g.A2.net_box:call(
        '_G.__cartridge_clusterwide_config_prepare_2pc', {config}
    )

    t.assert_equals(fio.path.exists(g.A1.workdir .. '/config.prepare'), false)
    t.assert_equals(fio.path.exists(g.A2.workdir .. '/config.prepare'), true)
    t.assert_equals(fio.path.exists(g.A3.workdir .. '/config.prepare'), false)
    t.assert_equals(helpers.list_cluster_issues(g.A1), {{
        level = 'warning',
        topic = 'configuration',
        instance_uuid = g.A2.instance_uuid,
        replicaset_uuid = g.A2.replicaset_uuid,
        message = 'Configuration is prepared and locked'..
            ' on localhost:13302 (A-2)',
    }})

    -- Eventually commit is locked
    local ok, err = g.A1.net_box:call(
        'package.loaded.cartridge.config_patch_clusterwide',
        {{['bye.txt'] = 'Googbye, locks'}}
    )
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'Prepare2pcError',
        err = 'Two-phase commit is locked',
    })

    -- But force reapply comes to the rescue!
    local ok, err = g.A1.net_box:call(
        'package.loaded.cartridge.config_force_reapply',
        {{g.A2.instance_uuid}}
    )
    t.assert_equals({ok, err}, {true, nil})

    -- The lock is gone
    t.assert_equals(fio.path.exists(g.A2.workdir .. '/config.prepare'), false)

    -- And patch_clusterwide succeeds
    local ok, err = g.A1.net_box:call(
        'package.loaded.cartridge.config_patch_clusterwide',
        {{['bye.txt'] = 'Googbye, locks'}}
    )
    t.assert_equals({ok, err}, {true, nil})

    t.assert_equals(helpers.list_cluster_issues(g.A1), {})
    t.assert_equals(
        g.cluster:download_config(),
        {['bye.txt'] = 'Googbye, locks'}
    )
end
