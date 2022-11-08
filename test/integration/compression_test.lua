local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    local datadir = fio.tempdir()

    g.cluster = helpers.Cluster:new({
        datadir = datadir,
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = helpers.random_cookie(),

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

    g.cluster:start()

end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_compression()
    local tarantool_version = _G._TARANTOOL
    t.skip_if(tarantool_version < '2.10.0', 'Tarantool version '..tarantool_version..' should be 2.10 EE or greater')
    --t.skip_if(not helpers.tarantool_version_ge('2.10.0'), 'Tarantool version  should be 2.10 EE or greater')

    for _, srv in pairs(g.cluster.servers) do
        local ok, v = pcall(function()
            return srv.net_box.space._schema:get({'version'})
        end)
        t.assert(ok, string.format("Error inspecting %s: %s", srv.alias, v))
        t.assert(v[1] > '1', srv.alias .. ' upgrate to 2.x failed')
    end

    local storage_1 = g.cluster:server('storage-1').net_box

    storage_1:eval([[
        box.schema.space.create('test1')
        box.space.test1:format({ {'idx',type='number'}, {'str',type='string'} })
        box.space.test1:create_index('pk', {unique = true, parts = { {field = 1, type = 'number'}, }})

        box.schema.space.create('test2')
        box.space.test2:format({ {'idx',type='number'}, {'arr1',type='array'} })
        box.space.test2:create_index('pk', {unique = true, parts = { {field = 1, type = 'number'}, }})
    ]])

    for i=1,200 do
        local str = ""
        for _ = 1, math.random(100, 10000) do
            str = str .. string.char(math.random(97, 122))
        end
        local tuple = {i, str}
        storage_1.space.test1:insert(tuple)
    end


    for i=1,200 do
        local arr = {}
        for i = 1, math.random(100, 10000) do
            arr[i] = math.random(-1000000000, 1000000000)
        end
        local tuple = {i, arr}
        storage_1.space.test2:insert(tuple)
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
                        space_name = "test1",
                        fields_be_compressed = {
                            {
                                compression_percentage = 61, field_name = "str"
                            }
                        },
                    },
                    {
                        space_name = "test2",
                        fields_be_compressed = {
                            {
                                compression_percentage = 90, field_name = "arr1"
                            }
                        },
                    },
                },
            },
        },
    })

end
