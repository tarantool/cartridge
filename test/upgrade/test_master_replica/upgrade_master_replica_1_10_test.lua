local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    local cwd = fio.cwd()
    local test_data_dir  = fio.pathjoin(cwd, 'test/upgrade/test_master_replica/data')
    local datadir = fio.tempdir()
    local ok, err = fio.copytree(test_data_dir, datadir)
    assert(ok, err)

    local cookie = 'upgrade-1.10-2.2'

    g.cluster = helpers.Cluster:new({
        datadir = datadir,
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = cookie,
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = {
                    {
                        alias = 'router',
                        instance_uuid = helpers.uuid('a', 'a', 1),
                        advertise_port = 13301,
                        env = {
                            TARANTOOL_UPGRADE_SCHEMA = 'true',
                        },
                    },
                },
            },
            {
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                servers = {
                    {
                        alias = 'storage-1',
                        instance_uuid = helpers.uuid('b', 'b', 1),
                        advertise_port = 13303,
                        env = {
                            TARANTOOL_UPGRADE_SCHEMA = 'true',
                        },
                    }, {
                        alias = 'storage-2',
                        instance_uuid = helpers.uuid('b', 'b', 2),
                        advertise_port = 13305,
                        env = {
                            TARANTOOL_UPGRADE_SCHEMA = 'true',
                        },
                    },
                },
            },
        },
    })
    -- We start cluster from existing 1.10 snapshots
    -- with schema version {'1', '10', '2'}
    g.cluster.bootstrapped = true
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_upgrade()
    local tarantool_version = _G._TARANTOOL
    t.skip_if(tarantool_version < '2.0', 'Tarantool version should be greater 2.0')

    local schema_version_1 = g.cluster:server('storage-1').net_box.space._schema:get({'version'})
    t.assert(schema_version_1[1] > '1', 'Schema version is upgraded to 2+')

    local schema_version_2 = g.cluster:server('storage-2').net_box.space._schema:get({'version'})
    t.assert(schema_version_2[1] > '1', 'Schema version is upgraded to 2+')

    -- Test replication is not broken
    local storage_1 = g.cluster:server('storage-1').net_box
    local storage_2 = g.cluster:server('storage-2').net_box

    storage_1:eval([[
        box.schema.space.create('test')
        box.space.test:create_index('pk')
    ]])

    local tuple = {1, 0.1, 'str', {a = 'a'}, {1, 2}}
    storage_1.space.test:insert(tuple)

    local storage2_tuple = storage_2:eval('return box.space.test:get({1})')
    t.assert_equals(storage2_tuple, tuple)
end
