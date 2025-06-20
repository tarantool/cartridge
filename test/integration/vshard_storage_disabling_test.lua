local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')


local function initialize_functions(srv)
    return srv:exec(function()
        local confapplier = require('cartridge.confapplier')
        local function get(...)
            if confapplier.get_state() == 'OperationError' then
                error('Invalid state')
            end
            return box.space.test:get(...)
        end
        local function put(...)
            if confapplier.get_state() == 'OperationError' then
                error('Invalid state')
            end
            return box.space.test:put(...)
        end
        rawset(_G, 'get', get)
        rawset(_G, 'put', put)
    end)
end

local function setup_replica_backoff_interval(srv)
    srv:exec(function()
        require('vshard.consts').REPLICA_BACKOFF_INTERVAL = 0.1
    end)
end

g.before_all = function()
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
        }
    })
    g.cluster:start()
    g.router = g.cluster:server('router-1')
    g.storage_master = g.cluster:server('storage-1')
    g.storage_replica = g.cluster:server('storage-2')

    local test_schema = {
        engine = 'memtx',
        is_local = false,
        temporary = false,
        format = {
            {name = 'bucket_id', type = 'unsigned', is_nullable = false},
            {name = 'record_id', type = 'unsigned', is_nullable = false},
        },
        indexes = {{
            name = 'pk', type = 'TREE', unique = true,
            parts = {{path = 'record_id', is_nullable = false, type = 'unsigned'}},
        },  {
            name = 'bucket_id', type = 'TREE', unique = false,
            parts = {{path = 'bucket_id', is_nullable = false, type = 'unsigned'}},
        }},
        sharding_key = {'record_id'},
    }
    g.cluster.main_server:call('cartridge_set_schema',
        {require('yaml').encode({spaces = {test = test_schema}})}
    )

    g.cluster:wait_until_healthy()

    initialize_functions(g.storage_master)
    initialize_functions(g.storage_replica)
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

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

g.after_each = function()
    g.storage_master:exec(function()
        box.space.test:truncate()
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

local function get_state(srv)
    return srv:eval('return require("cartridge.confapplier").get_state()')
end

local function get(srv, i)
    return srv:eval(
        'return require("vshard").router.callro(...)',
        {i, 'get', {i}}
    )
end

local function put(srv, i)
    return srv:eval('return require("vshard").router.callrw(...)',
        {i, 'put', {{i, i, string.format('i%04d', i)}}}
    )
end

local function apply_config(srv)
    return srv:eval('return require("cartridge").config_patch_clusterwide({uuid = require("uuid").str()})')
end

function g.test_vshard_storage_disable()
    -- Read/write data from/to healthy cluster
    t.assert_equals(put(g.router, 1), {1, 1, 'i0001'})
    t.assert_equals(get(g.router, 1), {1, 1, 'i0001'})

    -- Break master instance
    inject_operation_error(g.storage_master)
    apply_config(g.router)
    t.assert_equals(get_state(g.storage_master), 'OperationError')
    t.assert_equals(get_state(g.storage_replica), 'RolesConfigured')

    for _ = 1, 1000 do
        t.assert_equals(get(g.router, 1), {1, 1, 'i0001'})
    end

    local data, err = put(g.router, 2)
    t.assert_equals(data, box.NULL)
    t.assert_equals(err.message, 'Storage is disabled: storage is disabled explicitly')

    -- Fix master state
    dismiss_operation_error(g.storage_master)
    apply_config(g.router)
    t.assert_not_equals(get_state(g.storage_master), 'OperationError')
    t.assert_not_equals(get_state(g.storage_replica), 'OperationError')

    t.assert_equals(put(g.router, 2), {2, 2, 'i0002'})
    for _ = 1, 1000 do
        t.assert_equals(get(g.router, 2), {2, 2, 'i0002'})
    end

    -- Break replica instance
    inject_operation_error(g.storage_replica)
    apply_config(g.router)
    t.assert_not_equals(get_state(g.storage_master), 'OperationError')
    t.assert_equals(get_state(g.storage_replica), 'OperationError')

    t.assert_equals(put(g.router, 3), {3, 3, 'i0003'})
    for _ = 1, 1000 do
        t.assert_equals(get(g.router, 3), {3, 3, 'i0003'})
    end

    -- Fix replica state
    dismiss_operation_error(g.storage_replica)
    apply_config(g.router)
    t.assert_not_equals(get_state(g.storage_master), 'OperationError')
    t.assert_not_equals(get_state(g.storage_replica), 'OperationError')

    t.assert_equals(put(g.router, 4), {4, 4, 'i0004'})
    for _ = 1, 1000 do
        t.assert_equals(get(g.router, 4), {4, 4, 'i0004'})
    end
end

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

function g.test_vshard_storage_disable_on_failover()
    set_failover('eventual')

    -- Read/write data from/to healthy cluster
    t.assert_equals(put(g.router, 1), {1, 1, 'i0001'})
    t.assert_equals(get(g.router, 1), {1, 1, 'i0001'})

    -- Break replica instance
    inject_operation_error(g.storage_replica)

    g.storage_master:stop()

    helpers.retrying({timeout = 30}, function()
        g.storage_replica:exec(function()
            assert(box.info.ro == false)
        end)
    end)

    helpers.retrying({}, function()
        local data, err = put(g.router, 2)
        t.assert_equals(data, box.NULL)
        t.assert_equals(err.message, 'Storage is disabled: storage is disabled explicitly')
    end)

    g.storage_master:start()
    g.cluster:wait_until_healthy()
    initialize_functions(g.storage_master)

    -- Fix replica state
    dismiss_operation_error(g.storage_replica)

    g.cluster:wait_until_healthy()
    t.assert_not_equals(get_state(g.storage_master), 'OperationError')
    t.assert_not_equals(get_state(g.storage_replica), 'OperationError')

    t.assert_equals(put(g.router, 2), {2, 2, 'i0002'})
    for _ = 1, 1000 do
        t.assert_equals(get(g.router, 2), {2, 2, 'i0002'})
    end

    set_failover('disabled')
end

g.test_disabled_on_first_apply = function ()
    local res = g.storage_master:exec(function()
        local cartridge = require('cartridge')
        return cartridge.service_get('myrole').was_vshard_enabled_on_apply()
    end)

    -- last applied config
    apply_config(g.router)

    t.assert_not(res[1])
    t.assert(res[#res], 'enabled on last apply')

    res = g.storage_replica:exec(function()
        local cartridge = require('cartridge')
        return cartridge.service_get('myrole').was_vshard_enabled_on_apply()
    end)

    t.assert_not(res[1])
    t.assert(res[#res], 'enabled on last apply')
end
