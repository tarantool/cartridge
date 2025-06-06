local fio = require('fio')
local t = require('luatest')
local g_auto = t.group('integration.vshard_storage_disabling.auto')
local g_default = t.group('integration.vshard_storage_disabling.default')

local helpers = require('test.helper')

local function setup_replica_backoff_interval(srv)
    srv:exec(function()
        require('vshard.consts').REPLICA_BACKOFF_INTERVAL = 0.1
    end)
end
local function setup_cluster(g, auto_disable)
    t.skip_if(not helpers.tarantool_version_ge('1.10.1'))
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        use_vshard = true,
        replicasets = {{
            alias = 'router',
            uuid = helpers.uuid('a'),
            roles = {'vshard-router'},
            servers = {{instance_uuid = helpers.uuid('a', 'a', 1)}},
        }, {
            alias = 'storage',
            uuid = helpers.uuid('b'),
            roles = {'vshard-router', 'vshard-storage', 'myrole'},
            servers = {
                {instance_uuid = helpers.uuid('b', 'b', 1)},
                {instance_uuid = helpers.uuid('c', 'c', 1)},
            },
        }},
        env = {
            TARANTOOL_BUCKET_COUNT = 300,
            TARANTOOL_AUTO_DISABLE_VSHARD_STORAGE = tostring(auto_disable),
        }
    })
    g.cluster:start()
    g.router = g.cluster:server('router-1')
    g.storage_master = g.cluster:server('storage-1')
    g.storage_replica = g.cluster:server('storage-2')

    g.cluster:wait_until_healthy()

    -- Just to speedup tests
    setup_replica_backoff_interval(g.router)

    -- Wait vshard will be OK and remote control will be stopped.
    helpers.retrying({}, function()
        local info = helpers.run_remotely(g.router, function()
            local vshard = require('vshard')
            return vshard.router.info()
        end)
        assert(#info.alerts == 0)
    end)
end

local function inject_operation_error(srv)
    helpers.run_remotely(srv, function()
        local myrole = package.loaded['mymodule']
        rawset(_G, 'apply_config_original', myrole.apply_config)
        myrole.apply_config = function()
            error('Artificial Error', 0)
        end
    end)
end

local function dismiss_operation_error(srv)
    helpers.run_remotely(srv, function()
        local myrole = package.loaded['mymodule']
        myrole.apply_config = rawget(_G, 'apply_config_original')
    end)
end

local function apply_config(srv)
    return srv:exec(function()
        return require("cartridge").config_patch_clusterwide({uuid = require("uuid").str()})
    end)
end

for _, case in pairs({{g_auto, true}, {g_default, false}}) do
    local g, auto_disable = case[1], case[2]

    local function set_failover(mode)
        local response = g.cluster.main_server:graphql({
            query = [[
                mutation($mode: String) {
                    cluster {
                        failover_params(
                            mode: $mode
                        ) {
                            mode
                        }
                    }
                }
            ]],
            variables = { mode = mode },
            raise = false,
        })
        if response.errors then
            error(response.errors[1].message, 2)
        end
    end

    g.before_all = function()
        setup_cluster(g, auto_disable)
    end

    g.after_all = function()
        g.cluster:stop()
        fio.rmtree(g.cluster.datadir)
    end

    g.before_test('test_disabled_on_failover', function()
        set_failover('eventual')
    end)

    function g.test_disabled_on_failover()
        -- Break replica instance
        inject_operation_error(g.storage_replica)

        g.storage_master:stop()

        helpers.retrying({timeout = 30}, function()
            g.storage_replica:exec(function()
                assert(box.info.ro == false)
            end)
        end)

        local res = g.storage_replica:exec(function()
            local cartridge = require('cartridge')
            return cartridge.service_get('myrole').was_vshard_enabled_on_apply()
        end)
        if auto_disable then
            for _, v in ipairs(res) do
                t.assert_not(v)
            end
        else
            local res = g.storage_replica:exec(function()
                local vshard = rawget(_G, 'vshard')
                return vshard.storage.internal.is_enabled
            end)
            t.assert_not(res)
        end
    end

    g.after_test('test_disabled_on_failover', function ()
        g.storage_master:start()
        g.cluster:wait_until_healthy()
        dismiss_operation_error(g.storage_replica)
        set_failover('disabled')
    end)

    function g.test_disabled_on_apply_config()
        inject_operation_error(g.storage_replica)
        apply_config(g.router)

        local res = g.storage_replica:exec(function()
            local cartridge = require('cartridge')
            return cartridge.service_get('myrole').was_vshard_enabled_on_apply()
        end)
        if auto_disable then
            for _, v in ipairs(res) do
                t.assert_not(v)
            end
        else
            local res = g.storage_replica:exec(function()
                local vshard = rawget(_G, 'vshard')
                return vshard.storage.internal.is_enabled
            end)
            t.assert_not(res)
        end
    end

    g.after_test('test_disabled_on_apply_config', function ()
        dismiss_operation_error(g.storage_replica)
        apply_config(g.router)
    end)
end

g_default.test_disabled_on_first_apply = function ()
    local res = g_default.storage_master:exec(function()
        local cartridge = require('cartridge')
        return cartridge.service_get('myrole').was_vshard_enabled_on_apply()
    end)

    t.assert_not(res[1])
    for i = 2, #res do
        t.assert(res[i])
    end

    local res = g_default.storage_replica:exec(function()
        local cartridge = require('cartridge')
        return cartridge.service_get('myrole').was_vshard_enabled_on_apply()
    end)

    t.assert_not(res[1])
end
