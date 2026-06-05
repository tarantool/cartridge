local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local utils = require('cartridge.utils')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = false,
        cookie = helpers.random_cookie(),
        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {},
            servers = {
                {alias = 'master'},
                {alias = 'replica'},
            },
        }},
    })

    g.cluster:start()
    g.master = g.cluster:server('master')
    g.replica = g.cluster:server('replica')
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_bootstrap_strategy_is_auto_on_boot()
    t.skip_if(not utils.version_is_at_least(2, 11, 0), "bootstrap_strategy is available only since Tarantool 2.11.0")

    local strategy = g.master:exec(function()
        return box.cfg.bootstrap_strategy
    end)
    t.assert_equals(strategy, "auto")
end

function g.test_bootstrap_strategy_after_apply_config()
    t.skip_if(not utils.version_is_at_least(2, 11, 0), "bootstrap_strategy is available only since Tarantool 2.11.0")

    local ok, err = g.master:exec(function()
        local confapplier = require('cartridge.confapplier')
        local active_config = confapplier.get_active_config()
        return confapplier.apply_config(active_config)
    end)

    t.assert_equals({ok, err}, {true, nil})

    local cfg_state = g.master:exec(function()
        return {
            strategy = box.cfg.bootstrap_strategy,
            quorum = box.cfg.replication_connect_quorum
        }
    end)

    t.assert_equals(cfg_state.strategy, "auto")
    t.assert_equals(cfg_state.quorum, nil)
end
