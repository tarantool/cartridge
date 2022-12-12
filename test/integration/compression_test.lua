local fio = require('fio')
local t = require('luatest')
local g = t.group()
local tarantool = require('tarantool')
local semver = require('vshard.version')

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
    local is_enterprise = (tarantool.package == 'Tarantool Enterprise')
    local tnt_version = semver.parse(_TARANTOOL)
    local function version_is_at_least(...)
        return tnt_version >= semver.new(...)
    end

    t.skip_if(not is_enterprise, 'Tarantool should be Enterprise version')
    t.skip_if(not version_is_at_least(2, 10, 0, nil, 0, 0), 'Tarantool version should be 2.10 or greater')

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

    for _, instance in pairs(cluster_compression.compression_info[1].instance_compression_info) do
        for _, field in pairs(instance.fields_be_compressed) do
            if field.field_name == "str" then
                t.assert_le(field.compression_percentage, 63, "compression must be less or equal then 63%")
            end
            if field.field_name == "arr1" then
                t.assert_le(field.compression_percentage, 92, "compression must be less or equal then 92%")
            end
        end
    end

end
