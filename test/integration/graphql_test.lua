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
        cookie = require('digest').urandom(6):hex(),
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

    -- Variables
    t.assert_equals(
        server:graphql({
            query = [[
                query ($arg: String! $arg2: String!)
                    { test(arg: $arg, arg2: $arg2) }
            ]], variables = {arg = 'B', arg2 = '22'}}
        ).data.test, 'B22'
    )

    t.assert_error_msg_equals('Variable "arg2" expected to be non-null',
        server.graphql, server, {
            query = [[
                query ($arg: String! $arg2: String!)
                    { test(arg: $arg, arg2: $arg2) }
            ]], variables = {}})

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
    t.assert_error_msg_equals('{"Error":"D"}',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )

    server.net_box:eval([[
        package.loaded['test']['test'] = function(root, args)
            return nil, 'Error E'
        end
    ]])
    t.assert_error_msg_equals('Error E',
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
    t.assert_error_msg_equals('{"Error":"G"}',
        helpers.Server.graphql, server,
        {query = '{ test(arg: "TEST") }'}
    )

    server.net_box:eval([[
        package.loaded['test']['test'] = function(root, args)
            return nil, require('errors').new('CustomError', {Error = "H"})
        end
    ]])
    t.assert_error_msg_equals('{"Error":"H"}',
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

g.test_nested_input = function()
    local server = cluster.main_server

    server.net_box:eval([[
        package.loaded['test'] = {}
        package.loaded['test']['test_nested_InputObject'] = function(root, args)
          return args.servers[1].field
        end

        package.loaded['test']['test_nested_list'] = function(root, args)
          return args.servers[1]
        end

        package.loaded['test']['test_nested_InputObject_complex'] = function(root, args)
          return ('%s+%s+%s'):format(args.upvalue, args.servers.field2, args.servers.test.field[1])
        end

        local graphql = require('cartridge.graphql')
        local types = require('cartridge.graphql.types')

        local nested_InputObject = types.inputObject {
            name = 'nested_InputObject',
            fields = {
                field = types.string.nonNull,
            }
        }

        graphql.add_mutation({
            name = 'test_nested_InputObject',
            args = {
                servers = types.list(nested_InputObject),
            },
            kind = types.string,
            callback = 'test.test_nested_InputObject',
        })

        graphql.add_mutation({
            name = 'test_nested_list',
            args = {
                servers = types.list(types.string),
            },
            kind = types.string,
            callback = 'test.test_nested_list',
        })

        graphql.add_callback({
            name = 'test_nested_InputObject_complex',
            args = {
                upvalue = types.string,
                servers = types.inputObject({
                    name = 'ComplexInputObject',
                    fields = {
                        field2 = types.string,
                        test = types.inputObject({
                            name = 'ComplexNestedInputObject',
                            fields = {
                                field = types.list(types.string)
                            }
                        }),
                    }
                }),
            },
            kind = types.string,
            callback = 'test.test_nested_InputObject_complex',
        })
    ]])

    t.assert_equals(
        server:graphql({
            query = [[
                mutation($field: String!) {
                    test_nested_InputObject(
                        servers: [{ field: $field }]
                    )
                }
            ]],
        variables = {field = 'echo'}}
        ).data.test_nested_InputObject, 'echo'
    )

    t.assert_error_msg_equals('Unused variable "field"', function()
        return server:graphql({
            query = [[
                mutation($field: String!) {
                    test_nested_InputObject(
                        servers: [{ field: "not-variable" }]
                    )
                }
            ]],
        variables = {field = 'echo'}}
        )
    end)

    t.assert_equals(
        server:graphql({
            query = [[
                mutation($field: String!) {
                    test_nested_list(
                        servers: [$field]
                    )
                }
            ]],
        variables = {field = 'echo'}}
        ).data.test_nested_list, 'echo'
    )

    t.assert_equals(
        server:graphql({
            query = [[
                query($field: String! $field2: String! $upvalue: String!) {
                    test_nested_InputObject_complex(
                        upvalue: $upvalue,
                        servers: {
                            field2: $field2
                            test: { field: [$field] }
                        }
                    )
                }
            ]],
        variables = {field = 'echo', field2 = 'field', upvalue = 'upvalue'}}
        ).data.test_nested_InputObject_complex, 'upvalue+field+echo'
    )
end

g.test_missed_variable = function()
    local server = cluster.main_server

    server.net_box:eval([[
        package.loaded['test'] = package.loaded['test'] or {}
        package.loaded['test']['test_missed_var'] = function(root, args)
          return 'ok'
        end
        local graphql = require('cartridge.graphql')
        local types = require('cartridge.graphql.types')

        graphql.add_mutation({
            name = 'test_missed_var',
            args = {
                arg = types.string,
                arg2 = types.string,
            },
            kind = types.string,
            callback = 'test.missed_var',
        })
    ]])

    t.assert_error_msg_contains('Unknown variable "arg"', function()
         server:graphql({
            query = [[
                mutation($arg2: String) {
                    test_missed_var(arg: $arg, arg2: $arg2)
                }
            ]],
            variables = {arg = 'arg', arg2 = 'arg2'}}
        )
    end)
end

function g.test_fail_validate()
    t.assert_error_msg_equals('Scalar field "uri" cannot have subselections', function()
        return cluster.main_server:graphql({
            query = [[
                { cluster { self { uuid uri { x } state } } }
            ]]
        })
    end)

    t.assert_error_msg_equals('Composite field "replicaset" must have subselections', function()
        return cluster.main_server:graphql({
            query = [[
                { servers { alias replicaset storage { } uuid } }
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
        server.graphql, server, { query = '{replicasets{}}' }
    )

    local response = server:graphql({
        query = '{servers{}}',
        raise = false,
    })
    local extensions = response.errors[1].extensions
    t.assert_equals(extensions['io.tarantool.errors.class_name'], 'E')
    t.assert_equals(extensions['code'], 403)

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
            {'query',    'servers'},
            {'query',    'cluster.self'},
            {'mutation', 'probe_server'},
            {'mutation', 'cluster.edit_topology'},
        }
    )
end
