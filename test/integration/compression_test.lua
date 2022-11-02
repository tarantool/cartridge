local fio = require('fio')
local t = require('luatest')
local g = t.group()
local log = require('log')

local helpers = require('test.helper')

g.before_all(function()
    local datadir = fio.tempdir()
    --local ok, err = fio.copytree(  -- какие полезные данные тут есть? 
    --    fio.pathjoin(
    --        helpers.project_root,
    --        'test/upgrade/data_1.10.5'
    --    ),
    --    datadir
    --)
    --assert(ok, err)

    g.cluster = helpers.Cluster:new({
        datadir = datadir,
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = helpers.random_cookie(),
        env = {
            TARANTOOL_UPGRADE_SCHEMA = 'true', -- а надо ли ?
            --TARANTOOL_LOG = '| cat', -- добавил из api_join_test.lua
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
    --g.cluster.bootstrapped = true

    g.cluster:start()

end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_compression()
    local tarantool_version = _G._TARANTOOL
    --t.skip_if(tarantool_version < '2.8', 'Tarantool version '..tarantool_version..' should be greater 2.8') -- с какой верси включена компресия и  как включить ентерпрайс

    for _, srv in pairs(g.cluster.servers) do
        local ok, v = pcall(function()
            return srv.net_box.space._schema:get({'version'})
        end)
        t.assert(ok, string.format("Error inspecting %s: %s", srv.alias, v))
        t.assert(v[1] > '1', srv.alias .. ' upgrate to 2.x failed')
    end

    local router = g.cluster:server('router')
    local storage_1 = g.cluster:server('storage-1').net_box
    -- compressed
    --local storage_2 = g.cluster:server('storage-2').net_box
    -- compressed 'zstd' -- zstd lz4

    storage_1:eval([[
        box.schema.space.create('test')
        box.space.test:format({{'idx',type='number'},{'str',type='string'}})
        box.space.test:create_index('pk', {unique = true, parts = {{field = 1, type = 'number'},}})
    ]])

    for i=1,400 do
        local str = ""
        for i = 1, math.random(100, 1000) do
            str = str .. string.char(math.random(97, 122))
        end
        local tuple = {i, str}
        storage_1.space.test:insert(tuple)
    end

    local cluster_compression = g.cluster.main_server:graphql({query = [[
        {
            cluster {
                cluster_compression {
                    compression_info {
                        instance_id
                        instance_compression_info {
                            space_name
                            fields_be_compressed {
                                field_name
                                compression_percentage
                            }
                        }
                    }
                }
            }
        }
    ]]}).data.cluster.cluster_compression

    t.assert_equals(cluster_compression, {
        compression_info = {
            {
                instance_id = "bbbbbbbb-bbbb-0000-0000-000000000001",
                instance_compression_info = {
                    {
                        space_name = "test",
                        fields_be_compressed = {
                            {
                                compression_percentage = 69, field_name = "str"
                            }
                        },
                    },
                },
            },
        },
    })

end
