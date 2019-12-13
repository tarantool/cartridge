local fio = require('fio')
local t = require('luatest')
local g = t.group('api_join')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        use_vshard = true,
        cookie = 'test-cluster-cookie',

        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {'vshard-router', 'vshard-storage'},
            servers = {
                {
                    alias = 'main',
                    instance_uuid = helpers.uuid('a', 'a', 1),
                    advertise_port = 13301,
                    http_port = 8081,
                }
            }
        }}
    })

    g.server = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'spare',
        command = test_helper.server_command,
        replicaset_uuid = helpers.uuid('b'),
        instance_uuid = helpers.uuid('b', 'b', 1),
        http_port = 8082,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13302,
    })

    g.cluster:start()

    g.server:start()
    t.helpers.retrying({timeout = 5}, function()
        g.server:graphql({query = '{}'})
    end)
end

g.after_all = function()
    g.cluster:stop()
    g.server:stop()
    fio.rmtree(g.cluster.datadir)
    fio.rmtree(g.server.workdir)
end

function g.test_join_server()
    local main = g.cluster:server('main')

    local resp = main:graphql({
        query = [[mutation {
            probe_server(
                uri: "localhost:13302"
            )
        }]]
    })
    t.assert(resp['data']['probe_server'])

    local function get_peer_uuid(uri)
        return main.net_box:eval([[
            local errors = require('errors')
            local pool = require('cartridge.pool')
            local conn, err = errors.assert('E', pool.connect(...))
            return conn.peer_uuid
        ]], {uri})
    end

    t.assert_equals(
        -- g.server isn't bootstrapped yet
        -- remote-control connection can be established
        get_peer_uuid(g.server.advertise_uri),
        "00000000-0000-0000-0000-000000000000"
    )

    t.assert_error_msg_contains(
        'Server "aaaaaaaa-aaaa-0000-0000-000000000001" is already joined',
        function()
            return main:graphql({
                query = [[mutation {
                    join_server(
                        uri: "localhost:13302"
                        instance_uuid: "aaaaaaaa-aaaa-0000-0000-000000000001"
                    )
                }]]
            })
        end
    )

    t.assert_error_msg_contains(
        'replicasets[bbbbbbbb-0000-0000-0000-000000000000].weight' ..
        ' must be non-negative, got -0.3',
        function()
            return main:graphql({
                query = [[mutation {
                    join_server(
                        uri: "localhost:13302"
                        instance_uuid: "bbbbbbbb-bbbb-0000-0000-000000000001"
                        replicaset_uuid: "bbbbbbbb-0000-0000-0000-000000000000"
                        roles: ["vshard-storage"]
                        replicaset_weight: -0.3
                    )
                }]]
            })
        end
    )

    t.assert_error_msg_contains(
        [[replicasets[bbbbbbbb-0000-0000-0000-000000000000].vshard_group]] ..
        [[ "unknown" doesn't exist]],
        function()
            return main:graphql({
                query = [[mutation {
                    join_server(
                        uri: "localhost:13302"
                        instance_uuid: "bbbbbbbb-bbbb-0000-0000-000000000001"
                        replicaset_uuid: "bbbbbbbb-0000-0000-0000-000000000000"
                        roles: ["vshard-storage"]
                        vshard_group: "unknown"
                    )
                }]]
            })
        end
    )

    main:graphql({
        query = [[mutation {
            join_server(
                uri: "localhost:13302"
                instance_uuid: "bbbbbbbb-bbbb-0000-0000-000000000001"
                replicaset_uuid: "bbbbbbbb-0000-0000-0000-000000000000"
                replicaset_alias: "spare-set"
                roles: ["vshard-storage"]
            )
        }]]
    })

    t.helpers.retrying({timeout = 5, delay = 0.1}, function()
         g.server:graphql({query = '{}'})
    end)

    t.helpers.retrying({timeout = 5, delay = 0.1}, function()
        main.net_box:eval([[
            local cartridge = package.loaded['cartridge']
            return assert(cartridge) and assert(cartridge.is_healthy())
        ]])
    end)

    t.assert_equals(
        -- g.server is already bootstrapped
        -- pool.connect should reconnectwith full-featured iproto
        get_peer_uuid(g.server.advertise_uri),
        g.server.instance_uuid
    )

    local resp = main:graphql({
        query = [[{
            servers {
                uri
                uuid
                status
                replicaset { alias uuid status roles weight }
            }
        }]]
    })

    local servers = resp['data']['servers']

    t.assert_equals(#servers, 2)

    t.assert_equals(
        test_helper.table_find_by_attr(servers, 'uuid', g.server.instance_uuid),
        {
            uri = 'localhost:13302',
            uuid = g.server.instance_uuid,
            status = 'healthy',
            replicaset = {
                alias = 'spare-set',
                uuid = g.server.replicaset_uuid,
                roles = {"vshard-storage"},
                status = 'healthy',
                weight = 0,
            }
        }
    )
end
