local fio = require('fio')
local t = require('luatest')
local g = t.group()

local test_helper = require('test.helper')

local helpers = require('cartridge.test-helpers')

local cluster

g.before_all = function()
    cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = test_helper.server_command,
        replicasets = {
            {
                alias = 'router',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router', 'vshard-storage'},
                servers = {
                    {instance_uuid = helpers.uuid('a', 'a', 1)},
                },
            },
        },
    })
    cluster:start()
end
g.after_all = function()
    cluster:stop()
    fio.rmtree(cluster.datadir)
end

g.test_upload = function()
    local server = cluster.main_server

    server.net_box:eval([[
        package.loaded['test'] = {}
        package.loaded['test']['test'] = function(root, args)
          return args[1].value
        end

        local graphql = require('cartridge.graphql')
        local types = require('cartridge.graphql.types')
        graphql.add_callback({
            name = 'test',
            doc = '',
            args = {
                arg=types.string.nonNull,
                arg2=types.string,
            },
            kind = types.string.nonNull,
            callback = 'test.test',
        })
    ]])
    t.assert_equals(
        server:graphql(
            {query = '{ test(arg: "A") }'}
        ).data.test, 'A'
    )

    server.net_box:eval([[
        package.loaded['test']['test'] = function(root, args)
            local result = ''
            for _, tuple in ipairs(getmetatable(args).__index) do
                result = result .. tuple.value
            end
            return result
        end
    ]])
    -- Order matters
    t.assert_equals(
        server:graphql(
            {query = '{ test(arg: "B", arg2: "22") }'}
        ).data.test, 'B22'
    )
    t.assert_equals(
        server:graphql(
            {query = '{ test(arg2: "22", arg: "B") }'}
        ).data.test, '22B'
    )

    server.net_box:eval([[
        package.loaded['test']['test'] = function(root, args)
            error('Error C', 0)
        end
    ]])
    t.assert_error_msg_equals('Error C',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )

    server.net_box:eval([[
        package.loaded['test']['test'] = function(root, args)
            error({Error = 'D'})
        end
    ]])
    t.assert_error_msg_matches('{"Error":"D"}',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )

    server.net_box:eval([[
        package.loaded['test']['test'] = function(root, args)
            return nil, 'Error E'
        end
    ]])
    t.assert_error_msg_contains('Error E',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )

    server.net_box:eval([[
        package.loaded['test']['test'] = function(root, args)
            return nil, require('errors').new('CustomError', 'Error F')
        end
    ]])
    t.assert_error_msg_equals('Error F',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )

    server.net_box:eval([[
        package.loaded['test']['test'] = function(root, args)
            return nil, {Error = "G"}
        end
    ]])
    t.assert_error_msg_matches('{"Error":"G"}',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )

    server.net_box:eval([[
        package.loaded['test']['test'] = function(root, args)
            return nil, require('errors').new('CustomError', {Error = "H"})
        end
    ]])
    t.assert_error_msg_matches('{"Error":"H"}',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )
end

function g.test_reread_request()
    local server = cluster.main_server

    server.net_box:eval([[
        local httpd = require('cartridge').service_get('httpd')
        httpd:hook('before_dispatch', function(self, req)
            req:read_cached()
        end)
    ]])

    server:graphql({ query = '{}' })
end

function g.test_fail_validate()
    t.assert_error_msg_contains('Field "x" is not defined on type "String"', function()
        cluster.main_server:graphql({
            query = [[
                { cluster { self { uri { x } } } }
            ]]
        })
    end)
end

function g.test_error_extensions()
    local request = {
        query = [[mutation($uuids: [String!]) {
            cluster {
                disable_servers(uuids: $uuids) {}
            }
        }]],
        variables = {uuids = {cluster.main_server.instance_uuid}},
        raise = box.NULL,
    }

    t.assert_error_msg_equals(
        'Current instance "localhost:13301" can not be disabled',
        helpers.Server.graphql, cluster.main_server, request
    )

    request.raise = false
    local response = cluster.main_server:graphql(request)
    local extensions = response.errors[1].extensions
    t.assert_str_matches(
        extensions['io.tarantool.errors.stack'],
        '^stack traceback:\n.+'
    )
    t.assert_equals(
        extensions['io.tarantool.errors.class_name'],
        'Invalid cluster topology config'
    )
end

function g.test_middleware()
    local server = cluster.main_server

    -- GraphQL execution can be interrupted by raising error in trigger
    server.net_box:eval([[
        graphql = require('cartridge.graphql')
        function raise()
            error("You are not welcome here", 0)
        end
        graphql.on_resolve(raise)
    ]])
    t.assert_error_msg_equals(
        "You are not welcome here",
        server.graphql, server, { query = '{replicasets{}}' }
    )

    -- GraphQL callbacks exections can be tracked
    server.net_box:eval([[
        graphql.on_resolve(nil, raise)
        graphql.on_resolve(require('log').warn)

        tracks = {}
        function track_graphql(...)
            table.insert(tracks, {...})
        end
        graphql.on_resolve(track_graphql)
    ]])

    server:graphql({ query = [[
        query {
            servers {}
            cluster {self {}}
        }
    ]]})

    server:graphql({ query = [[
        mutation($uri: String!) {
            probe_server(uri: $uri)
            cluster { edit_topology {} }
        }
    ]], variables = {uri = server.advertise_uri}})

    t.assert_equals(
        server.net_box:eval('return tracks'),
        {
            {{operation = 'query',    field = 'servers'}},
            {{operation = 'query',    field = 'cluster.self'}},
            {{operation = 'mutation', field = 'probe_server'}},
            {{operation = 'mutation', field = 'cluster.edit_topology'}},
        }
    )
end
