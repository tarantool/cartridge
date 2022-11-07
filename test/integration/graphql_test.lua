local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local cluster

g.before_all = function()
    cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
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

g.test_simple = function()
    local server = cluster.main_server

    server:eval([[
        package.loaded['test'] = package.loaded['test'] or {}
        package.loaded['test']['test'] = function(root, args)
            return args[1].value
        end

        local graphql = require('cartridge.graphql')
        local types = require('graphql.types')
        graphql.add_callback({
            name = 'test',
            doc = '',
            args = {
                arg=types.string.nonNull,
                arg2=types.string,
                arg3=types.int,
                arg4=types.long,
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

    server:eval([[
        package.loaded['test']['test'] = function(root, args)
            local result = ''
            for _, tuple in ipairs(getmetatable(args).__index) do
                result = result .. tuple.value
            end
            return result
        end
    ]])
end

g.test_errors_in_handlers = function()
    local server = cluster.main_server

    server:eval([[
        package.loaded['test']['test'] = function(root, args)
            error('Error C', 0)
        end
    ]])
    t.assert_error_msg_equals('Error C',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )

    server:eval([[
        package.loaded['test']['test'] = function(root, args)
            error({Error = 'D'})
        end
    ]])
    t.assert_error_msg_equals('{"Error":"D"}',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )

    server:eval([[
        package.loaded['test']['test'] = function(root, args)
            return nil, 'Error E'
        end
    ]])
    t.assert_error_msg_equals('Error E',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )

    server:eval([[
        package.loaded['test']['test'] = function(root, args)
            return nil, require('errors').new('CustomError', 'Error F')
        end
    ]])
    t.assert_error_msg_equals('Error F',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )

    server:eval([[
        package.loaded['test']['test'] = function(root, args)
            return nil, {Error = "G"}
        end
    ]])
    t.assert_error_msg_equals('{"Error":"G"}',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )

    server:eval([[
        package.loaded['test']['test'] = function(root, args)
            return nil, require('errors').new('CustomError', {Error = "H"})
        end
    ]])
    t.assert_error_msg_equals('{"Error":"H"}',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )

    -- Fields sub-selections
    t.assert_error_msg_equals(
        'Scalar field "uri" cannot have subselections',
        function() return cluster.main_server:graphql({
            query = [[
                { cluster { self { uuid uri { x } state } } }
            ]]
        }) end
    )

    t.assert_error_msg_equals(
        'Composite field "replicaset" must have subselections',
        function() return cluster.main_server:graphql({
            query = [[
                { servers { alias replicaset storage { uri } uuid } }
            ]]
        }) end
    )

    t.assert_error_msg_equals(
        'Field "unknown" is not defined on type "Server"',
        function() return cluster.main_server:graphql({
            query = [[
                { servers { unknown } }
            ]]
        }) end
    )
end

g.test_reread_request = function()
    local server = cluster.main_server

    server:eval([[
        local httpd = require('cartridge').service_get('httpd')
        httpd:hook('before_dispatch', function(self, req)
            req:read_cached()
        end)
    ]])

    server:graphql({ query = '{ servers  { uri } }' })
end

g.test_unknown_query_mutation = function()
    local server = cluster.main_server
    t.assert_error_msg_equals(
        'Field "UNKNOWN_TYPE" is not defined on type "Query"',
        function() return server:graphql({
            query = [[
                query { UNKNOWN_TYPE(arg: "") }
            ]], variables = {}
        }) end
    )

    t.assert_error_msg_equals(
        'Field "UNKNOWN_TYPE" is not defined on type "Mutation"',
        function() return server:graphql({
            query = [[
                mutation { UNKNOWN_TYPE(arg: "") }
            ]], variables = {}
        }) end
    )
end

function g.test_error_extensions()
    local request = {
        query = [[mutation($uuids: [String!]) {
            cluster {
                disable_servers(uuids: $uuids) { uuid }
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
    --t.assert_str_matches(
    --    extensions['io.tarantool.errors.stack'],
    --    '^stack traceback:\n.+'
    --)
    t.assert_equals(
        extensions['io.tarantool.errors.class_name'],
        'Invalid cluster topology config'
    )
end

function g.test_middleware()
    local server = cluster.main_server

    -- GraphQL execution can be interrupted by raising error in trigger
    server:eval([[
        local errors = require('errors')
        graphql = require('cartridge.graphql')
        function raise()
            local err = errors.new('E', 'You are not welcome here')
            err.graphql_extensions = {code = 403}
            error(err)
        end
        graphql.on_resolve(raise)
    ]])
    t.assert_error_msg_equals(
        "You are not welcome here",
        server.graphql, server, { query = '{replicasets{ uuid }}' }
    )

    local response = server:graphql({
        query = '{servers{ uri }}',
        raise = false,
    })
    local extensions = response.errors[1].extensions
    t.assert_equals(extensions['io.tarantool.errors.class_name'], 'E')
    t.assert_equals(extensions['code'], 403)

    -- GraphQL callbacks exections can be tracked
    server:eval([[
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
            servers { uri }
            cluster {self { uuid }}
        }
    ]]})

    server:graphql({ query = [[
        mutation($uri: String!) {
            probe_server(uri: $uri)
            cluster { edit_topology { servers { uri } } }
        }
    ]], variables = {uri = server.advertise_uri}})

    t.assert_equals(
        server:eval('return tracks'),
        {
            {'query',    'servers'},
            {'query',    'cluster.self'},
            {'mutation', 'probe_server'},
            {'mutation', 'cluster.edit_topology'},
        }
    )
end
