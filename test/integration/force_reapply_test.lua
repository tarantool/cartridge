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
        env = {}
    })
    g.cluster:start()
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)


function g.test_twophase_config_locked()
    local master = g.cluster.main_server
    local replica1 = g.cluster:server('replica1')

    -- Make validate_config hang on replica2
    local config = master.net_box:eval(
            'return require(\'cartridge.confapplier\').'..
            'get_active_config():get_plaintext()'
    )

    config['hey.yml'] = 'that is new'

    -- let's put a spoke in two-phase's wheel
    replica1.net_box:call(
        '_G.__cartridge_clusterwide_config_prepare_2pc',
        {config}
    )

    t.helpers.retrying({}, function()
        t.assert_equals(fio.path.exists(replica1.workdir .. '/config.prepare'), true)
    end)

    local status, err = master.net_box:call(
        'package.loaded.cartridge.config_patch_clusterwide',
        {config}
    )

    -- Eventually commit is locked
    t.assert_equals(status, nil)
    t.assert_covers(err, {err = "Two-phase commit is locked"})

    -- But force reapply comes to the rescue!
    master.net_box:call(
        'package.loaded.cartridge.config_force_reapply',
        {{replica1.instance_uuid}}
    )

    -- Lock is gone
    t.helpers.retrying({}, function()
        t.assert_equals(fio.path.exists(replica1.workdir .. '/config.prepare'), false)
    end)

    local status, err = master.net_box:call(
        'package.loaded.cartridge.config_patch_clusterwide',
        {config}
    )

    -- And patch_clusterwide has succeed
    t.assert_equals(status, true)
    t.assert_equals(err, nil)
end
