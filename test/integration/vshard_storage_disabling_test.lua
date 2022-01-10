local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
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
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function initialize_functions(srv)
    return srv:eval([[
        local confapplier = require('cartridge.confapplier')
        function get(...)
            if confapplier.get_state() == 'OperationError' then
                error('Invalid state')
            end
            return box.space.test:get(...)
        end
        function put(...)
            if confapplier.get_state() == 'OperationError' then
                error('Invalid state')
            end
            return box.space.test:put(...)
        end
    ]])
end

local function setup_replica_backoff_interval(srv)
    helpers.run_remotely(srv, function()
        require('vshard.consts').REPLICA_BACKOFF_INTERVAL = 0.1
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
    initialize_functions(g.storage_master)
    initialize_functions(g.storage_replica)

    -- Just to speedup test
    setup_replica_backoff_interval(g.router)

    -- Wait vshard will be OK and remote control will be stopped.
    helpers.retrying({}, function()
        local info = helpers.run_remotely(g.router, function()
            local vshard = require('vshard')
            return vshard.router.info()
        end)
        assert(#info.alerts == 0)
    end)

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
