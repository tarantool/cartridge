local fio = require('fio')
local t = require('luatest')
local g = t.group()

local test_helper = require('test.helper')

local helpers = require('cartridge.test-helpers')

local cluster
local servers

g.before_all = function()
    cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = test_helper.server_command,
        replicasets = {
            {
                alias = 'firstling',
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {{
                    http_port = 8081,
                    advertise_port = 13301,
                    instance_uuid = helpers.uuid('a', 'a', 1)
                }},
            }
        },
    })

    servers = {}
    for i = 2, 3 do
        local http_port = 8080 + i
        local advertise_port = 13300 + i
        local alias = string.format('twin%d', i)

        servers[i] = helpers.Server:new({
            alias = alias,
            command = test_helper.server_command,
            workdir = fio.pathjoin(cluster.datadir, alias),
            cluster_cookie = cluster.cookie,
            http_port = http_port,
            advertise_port = advertise_port,
            replicaset_uuid = helpers.uuid('a'),
            instance_uuid = helpers.uuid('a', 'a', i),
        })
    end

    for _, server in pairs(servers) do
        server:start()
    end
    cluster:start()
end

g.after_all = function()
    for _, server in pairs(servers or {}) do
        server:stop()
    end
    cluster:stop()

    fio.rmtree(cluster.datadir)
    cluster = nil
    servers = nil
end

g.test_patch_topology = function()
    -- t.skip("Fails due to https://github.com/tarantool/tarantool/issues/4527")

    cluster.main_server:graphql({
        query = [[mutation(
            $replicasets: [EditReplicasetInput!]
        ){
            cluster {
                edit_topology(replicasets:$replicasets){}
            }
        }]],
        variables = {
            replicasets = {{
                uuid = cluster.main_server.replicaset_uuid,
                join_servers = {{
                    uri = servers[2].advertise_uri,
                    uuid = servers[2].instance_uuid,
                }, {
                    uri = servers[3].advertise_uri,
                    uuid = servers[3].instance_uuid,
                }}
            }}
        }
    })

    cluster:retrying({}, function() servers[2]:connect_net_box() end)
    cluster:retrying({}, function() servers[3]:connect_net_box() end)
    cluster:wait_until_healthy()
end
