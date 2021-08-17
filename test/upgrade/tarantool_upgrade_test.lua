local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    local datadir = fio.tempdir()
    local ok, err = fio.copytree(
        fio.pathjoin(
            helpers.project_root,
            'test/upgrade/data_1.10.5'
        ),
        datadir
    )
    assert(ok, err)

    g.cluster = helpers.Cluster:new({
        datadir = datadir,
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = require('digest').urandom(6):hex(),
        env = {
            TARANTOOL_UPGRADE_SCHEMA = 'true',
        },
        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {'vshard-router'},
            servers = {{
                alias = 'router',
                instance_uuid = helpers.uuid('a', 'a', 1),
                advertise_port = 13301,
            }},
        }, {
            uuid = helpers.uuid('b'),
            roles = {'vshard-storage'},
            servers = {{
                alias = 'storage-1',
                instance_uuid = helpers.uuid('b', 'b', 1),
                advertise_port = 13303,
            }, {
                alias = 'storage-2',
                instance_uuid = helpers.uuid('b', 'b', 2),
                advertise_port = 13305,
            }},
        }},
    })

    -- We start cluster from existing snapshots
    -- Don't try to bootstrap it again
    g.cluster.bootstrapped = true

    g.cluster:start()
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_upgrade()
    local tarantool_version = _G._TARANTOOL
    t.skip_if(tarantool_version < '2.0', 'Tarantool version should be greater 2.0')

    for _, srv in pairs(g.cluster.servers) do
        local ok, v = pcall(function()
            return srv.net_box.space._schema:get({'version'})
        end)
        t.assert(ok, string.format("Error inspecting %s: %s", srv.alias, v))
        t.assert(v[1] > '1', srv.alias .. ' upgrate to 2.x failed')
    end

    -- Test replication is not broken
    local storage_1 = g.cluster:server('storage-1').net_box
    local storage_2 = g.cluster:server('storage-2').net_box

    storage_1:eval([[
        box.schema.space.create('test')
        box.space.test:create_index('pk')
    ]])

    local tuple = {1, 0.1, 'str', {a = 'a'}, {1, 2}}
    storage_1.space.test:insert(tuple)

    helpers.retrying({}, function()
        t.assert_equals(
            storage_2:eval('return box.space.test:get({1})'),
            tuple
        )
    end)
end
