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
        package.loaded['test'] = package.loaded['test'] or {}
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

    t.assert_error_msg_equals(
        'Variable "arg2" expected to be non-null',
        function() return server:graphql({
            query = [[
                query ($arg: String! $arg2: String!)
                    { test(arg: $arg, arg2: $arg2) }
            ]], variables = {}
        }) end
    )

    t.assert_error_msg_equals(
        'Variable "arg" type mismatch:' ..
        ' the variable type "String" is not compatible' ..
        ' with the argument type "NonNull(String)"',
        function() return server:graphql({
            query = [[
                query ($arg: String)
                    { test(arg: $arg) }
            ]], variables = {}
        }) end
    )

    t.assert_error_msg_equals(
        'Required argument "arg" was not supplied.',
        function() return server:graphql({
            query = [[
                query { test(arg2: "") }
            ]]
        }) end
    )

    t.assert_error_msg_equals(
        'Unknown variable "unknown_arg"',
        function() return server:graphql({
            query = [[
                query { test(arg: $unknown_arg) }
            ]]
        }) end
    )

    t.assert_error_msg_equals(
        'There is no declaration for the variable "unknown_arg"',
        function() return server:graphql({
            query = [[
                query { test(arg: "") }
            ]], variables = {unknown_arg = ''}
        }) end
    )

    t.assert_error_msg_equals(
        'Could not coerce value "8589934592" to type "Int"',
        function() return server:graphql({
            query = [[
                query { test(arg: "", arg3: 8589934592) }
            ]], variables = {}
        }) end
    )

    t.assert_error_msg_equals(
        'Could not coerce value "123.4" to type "Int"',
        function() return server:graphql({
            query = [[
                query { test(arg: "", arg3: 123.4) }
            ]], variables = {}
        }) end
    )

    t.assert_error_msg_equals(
        'Could not coerce value "18446744073709551614" to type "Long"',
        function() return server:graphql({
            query = [[
                query { test(arg: "", arg4: 18446744073709551614) }
            ]], variables = {}
        }) end
    )

    t.assert_error_msg_equals(
        'Could not coerce value "123.4" to type "Long"',
        function() return server:graphql({
            query = [[
                query { test(arg: "", arg4: 123.4) }
            ]], variables = {}
        }) end
    )

    t.assert_error_msg_equals(
        'Could not coerce value "inputObject" to type "String"',
        function() return server:graphql({
            query = [[
                query { test(arg: {a: "123"}, arg4: 123) }
            ]], variables = {}
        }) end
    )

    t.assert_error_msg_equals(
        'Could not coerce value "list" to type "String"',
        function() return server:graphql({
            query = [[
                query { test(arg: ["123"], arg4: 123) }
            ]], variables = {}
        }) end
    )

    -- Errors in handlers
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

    server.net_box:eval([[
        local httpd = require('cartridge').service_get('httpd')
        httpd:hook('before_dispatch', function(self, req)
            req:read_cached()
        end)
    ]])

    server:graphql({ query = '{ servers  { uri } }' })
end


g.test_enum_input = function()
    local server = cluster.main_server

    server.net_box:eval([[
        package.loaded['test'] = package.loaded['test'] or {}
        package.loaded['test']['test_enum'] = function(root, args)
            return args.arg.field
        end

        local graphql = require('cartridge.graphql')
        local types = require('cartridge.graphql.types')

        local simple_enum = types.enum {
            name = 'simple_enum',
            values = {
                a = { value = 'a' },
                b = { value = 'b' },
            },
        }

        local input_object = types.inputObject({
            name = 'simple_input_object',
            fields = {
                field = simple_enum,
            }
        })

        graphql.add_callback({
            name = 'simple_enum',
            args = {
                arg = input_object,
            },
            kind = types.string,
            callback = 'test.test_enum',
        })
    ]])

    t.assert_equals(
        server:graphql({
            query = [[
                query($arg: simple_input_object) {
                    simple_enum(arg: $arg)
                }
            ]],
        variables = {arg = {field = 'a'}}}
        ).data.simple_enum, 'a'
    )


    t.assert_error_msg_equals(
            'Wrong variable "arg.field" for the Enum "simple_enum" with value "d"',
            function() return server:graphql({
            query = [[
                query($arg: simple_input_object) {
                    simple_enum(arg: $arg)
                }
            ]],
        variables = {arg = {field = 'd'}}}
        )
    end)
end

g.test_enum_output = function()
    local server = cluster.main_server

    server.net_box:eval([[
        package.loaded['test'] = package.loaded['test'] or {}
        package.loaded['test']['test_enum_output'] = function(_, _)
            return {value = 'a'}
        end

        local graphql = require('cartridge.graphql')
        local types = require('cartridge.graphql.types')

        local simple_enum = types.enum {
            name = 'simple_enum_output',
            values = {
                a = { value = 'a' },
                b = { value = 'b' },
            },
        }

        local object = types.object({
            name = 'simple_object',
            fields = {
                value = simple_enum,
            }
        })

        graphql.add_callback({
            name = 'test_enum_output',
            args = {},
            kind = object,
            callback = 'test.test_enum_output',
        })
    ]])

    t.assert_equals(
        server:graphql({
            query = [[
                query {
                    test_enum_output{ value }
                }
            ]],
        variables = {}}
        ).data.test_enum_output.value, 'a'
    )
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

g.test_custom_type_scalar_variables = function()
    local server = cluster.main_server

    server.net_box:eval([[
        package.loaded['test'] = {}
        package.loaded['test']['test_custom_type_scalar'] = function(_, args)
            return args.field
        end
        package.loaded['test']['test_custom_type_scalar_list'] = function(_, args)
            return args.fields[1]
        end
        package.loaded['test']['test_json_type'] = function(_, args)
            if args.field == nil then
                return nil
            end
            assert(type(args.field) == 'table', "Field is not a table! ")
            assert(args.field.test ~= nil, "No field 'test' in object!")
            return args.field
        end
        package.loaded['test']['test_custom_type_scalar_inputObject'] = function(_, args)
            return args.object.nested_object.field
        end

        local json = require('json')
        local graphql = require('cartridge.graphql')
        local types = require('cartridge.graphql.types')

        local function isString(value)
            return type(value) == 'string'
        end

        local function coerceString(value)
            if value ~= nil then
                value = tostring(value)
                if not isString(value) then return end
            end

            return value
        end

        local custom_string = types.scalar({
            name = 'CustomString',
            description = 'Custom string type',
            serialize = coerceString,
            parseValue = coerceString,
            parseLiteral = function(node)
                return coerceString(node.value)
            end,
            isValueOfTheType = isString,
        })

        local function decodeJson(value)
            if value ~= nil then
                return json.decode(value)
            end
            return value
        end

        local json_type = types.scalar({
            name = 'Json',
            description = 'Custom type with JSON decoding',
            serialize = json.encode,
            parseValue = decodeJson,
            parseLiteral = function(node)
                return decodeJson(node.value)
            end,
            isValueOfTheType = isString,
        })

        graphql.add_callback({
            name = 'test_custom_type_scalar',
            args = {
                field = custom_string.nonNull,
            },
            kind = types.string,
            callback = 'test.test_custom_type_scalar',
        })

        graphql.add_callback({
            name = 'test_json_type',
            args = {
                field = json_type,
            },
            kind = json_type,
            callback = 'test.test_json_type',
        })

        graphql.add_callback({
            name = 'test_custom_type_scalar_list',
            args = {
                fields = types.list(custom_string.nonNull).nonNull,
            },
            kind = types.string,
            callback = 'test.test_custom_type_scalar_list',
        })

        graphql.add_callback({
            name = 'test_custom_type_scalar_inputObject',
            args = {
                object = types.inputObject({
                    name = 'ComplexCustomInputObject',
                    fields = {
                        nested_object = types.inputObject({
                            name = 'ComplexCustomNestedInputObject',
                            fields = {
                                field = custom_string,
                            }
                        }),
                    }
                }),
            },
            kind = types.string,
            callback = 'test.test_custom_type_scalar_inputObject',
        })
    ]])

    t.assert_equals(
        server:graphql({
            query = [[
                query($field: Json) {
                    test_json_type(
                        field: $field
                    )
                }
            ]],
            variables = {field = '{"test": 123}'}}
        ).data.test_json_type, '{"test":123}'
    )

    t.assert_equals(
        server:graphql({
            query = [[
                query($field: Json) {
                    test_json_type(
                        field: $field
                    )
                }
            ]],
            variables = {field = box.NULL}}
        ).data.test_json_type, 'null'
    )

    t.assert_equals(
        server:graphql({
            query = [[
                query {
                    test_json_type(
                        field: "null"
                    )
                }
            ]],
            variables = {}}
        ).data.test_json_type, 'null'
    )

    t.assert_equals(
        server:graphql({
            query = [[
                query($field: CustomString!) {
                    test_custom_type_scalar(
                        field: $field
                    )
                }
            ]],
        variables = {field = 'echo'}}
        ).data.test_custom_type_scalar, 'echo'
    )

    t.assert_error_msg_equals('Variable "field" type mismatch: ' ..
            'the variable type "NonNull(String)" is not compatible with the argument type '..
            '"NonNull(CustomString)"', function()
        return server:graphql({
            query = [[
                query($field: String!) {
                    test_custom_type_scalar(
                        field: $field
                    )
                }
            ]],
        variables = {field = 'echo'}}
        )
    end)

    t.assert_equals(
        server:graphql({
            query = [[
                query($field: CustomString!) {
                    test_custom_type_scalar_list(
                        fields: [$field]
                    )
                }
            ]],
        variables = {field = 'echo'}}
        ).data.test_custom_type_scalar_list, 'echo'
    )

    t.assert_error_msg_equals('Could not coerce value "inputObject" ' ..
        'to type "CustomString"', function()
        return server:graphql({
            query = [[
                query {
                    test_custom_type_scalar_list(
                        fields: [{a: "2"}]
                    )
                }
            ]]})
    end)

    t.assert_error_msg_equals('Variable "field" type mismatch: ' ..
            'the variable type "NonNull(String)" is not compatible with the argument type '..
            '"NonNull(CustomString)"', function()
        return server:graphql({
            query = [[
                query($field: String!) {
                    test_custom_type_scalar_list(
                        fields: [$field]
                    )
                }
            ]],
        variables = {field = 'echo'}}
        )
    end)

    t.assert_equals(
        server:graphql({
            query = [[
                query($fields: [CustomString!]!) {
                    test_custom_type_scalar_list(
                        fields: $fields
                    )
                }
            ]],
        variables = {fields = {'echo'}}}
        ).data.test_custom_type_scalar_list, 'echo'
    )

    t.assert_error_msg_equals('Variable "fields" type mismatch: ' ..
            'the variable type "NonNull(List(NonNull(String)))" is not compatible with the argument type '..
            '"NonNull(List(NonNull(CustomString)))"', function()
        return server:graphql({
            query = [[
                query($fields: [String!]!) {
                    test_custom_type_scalar_list(
                        fields: $fields
                    )
                }
            ]],
        variables = {fields = {'echo'}}}
        )
    end)

    t.assert_error_msg_equals('Variable "fields" type mismatch: ' ..
            'the variable type "List(NonNull(String))" is not compatible with the argument type '..
            '"NonNull(List(NonNull(CustomString)))"', function()
        return server:graphql({
            query = [[
                query($fields: [String!]) {
                    test_custom_type_scalar_list(
                        fields: $fields
                    )
                }
            ]],
        variables = {fields = {'echo'}}}
        )
    end)

    t.assert_equals(
        server:graphql({
            query = [[
                query($field: CustomString!) {
                    test_custom_type_scalar_inputObject(
                        object: { nested_object: { field: $field } }
                    )
                }
            ]],
        variables = {field = 'echo'}}
        ).data.test_custom_type_scalar_inputObject, 'echo'
    )

    t.assert_error_msg_equals('Variable "field" type mismatch: ' ..
            'the variable type "NonNull(String)" is not compatible with the argument type '..
            '"CustomString"', function()
        return server:graphql({
            query = [[
                query($field: String!) {
                    test_custom_type_scalar_inputObject(
                        object: { nested_object: { field: $field } }
                    )
                }
            ]],
        variables = {field = 'echo'}}
        )
    end)
end

g.test_output_type_mismatch_error = function()
    local server = cluster.main_server

    server.net_box:eval([[
        package.loaded['test'] = {}
        package.loaded['test']['callback'] = function(_, _)
            return true
        end

        package.loaded['test']['callback_for_nested'] = function(_, _)
            return { values = true }
        end

        local graphql = require('cartridge.graphql')
        local types = require('cartridge.graphql.types')

        local obj_type = types.object({
            name = 'ObjectWithValue',
            fields = {
                value = types.string,
            },
        })

        local nested_obj_type = types.object({
            name = 'NestedObjectWithValue',
            fields = {
                value = types.string,
            },
        })

        local complex_obj_type = types.object({
            name = 'ComplexObjectWithValue',
            fields = {
                values = types.list(nested_obj_type),
            },
        })

        graphql.add_callback({
            name = 'expected_nonnull_list',
            kind = types.list(types.int.nonNull),
            callback = 'test.callback',
        })

        graphql.add_callback({
            name = 'expected_obj',
            kind = obj_type,
            callback = 'test.callback',
        })

        graphql.add_callback({
            name = 'expected_list',
            kind = types.list(types.int),
            callback = 'test.callback',
        })

        graphql.add_callback({
            name = 'expected_list_with_nested',
            kind = types.list(complex_obj_type),
            callback = 'test.callback_for_nested',
        })
    ]])

    t.assert_error_msg_equals('Expected "expected_nonnull_list" to be an "array", got "boolean"', function()
        return server:graphql({
            query = [[
                query {
                    expected_nonnull_list
                }
            ]]})
    end)

    t.assert_error_msg_equals('Expected "expected_obj" to be a "map", got "boolean"', function()
        return server:graphql({
            query = [[
                query {
                    expected_obj { value }
                }
            ]]})
    end)

    t.assert_error_msg_equals('Expected "expected_list" to be an "array", got "boolean"', function()
        return server:graphql({
            query = [[
                query {
                    expected_list
                }
            ]]})
    end)

    t.assert_error_msg_equals('Expected "expected_list_with_nested" to be an "array", got "map"', function()
        return server:graphql({
            query = [[
                query {
                    expected_list_with_nested { values { value } }
                }
            ]]})
    end)
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
        server.net_box:eval('return tracks'),
        {
            {'query',    'servers'},
            {'query',    'cluster.self'},
            {'mutation', 'probe_server'},
            {'mutation', 'cluster.edit_topology'},
        }
    )
end

g.test_default_values = function()
    local server = cluster.main_server

    server.net_box:eval([[
        package.loaded['test'] = package.loaded['test'] or {}
        package.loaded['test']['test_default_value'] = function(_, args)
            if args.arg == nil then
                return 'nil'
            end
            return args.arg
        end

        package.loaded['test']['test_default_list'] = function(_, args)
            if args.arg == nil then
                return 'nil'
            end
            return args.arg[1]
        end

        package.loaded['test']['test_default_object'] = function(_, args)
            if args.arg == nil then
                return 'nil'
            end
            return args.arg.field
        end

        package.loaded['test']['test_json_type'] = function(_, args)
            if args.field == nil then
                return nil
            end
            assert(type(args.field) == 'table', "Field is not a table! ")
            assert(args.field.test ~= nil, "No field 'test' in object!")
            return args.field
        end

        local json = require('json')
        local graphql = require('cartridge.graphql')
        local types = require('cartridge.graphql.types')

        local function decodeJson(value)
            if value ~= nil then
                return json.decode(value)
            end
            return value
        end

        local json_type = types.scalar({
            name = 'Json',
            description = 'Custom type with JSON decoding',
            serialize = json.encode,
            parseValue = decodeJson,
            parseLiteral = function(node)
                return decodeJson(node.value)
            end,
            isValueOfTheType = function(value) return type(value) == 'string' end,
        })

        graphql.add_callback({
            name = 'test_json_type',
            args = {
                field = json_type,
            },
            kind = json_type,
            callback = 'test.test_json_type',
        })

        graphql.add_callback({
            name = 'test_default_value',
            args = {
                arg = types.string,
            },
            kind = types.string,
            callback = 'test.test_default_value',
        })

        graphql.add_callback({
            name = 'test_default_list',
            args = {
                arg = types.list(types.string),
            },
            kind = types.string,
            callback = 'test.test_default_list',
        })

        local input_object = types.inputObject({
            name = 'default_input_object',
            fields = {
                field = types.string,
            }
        })

        graphql.add_callback({
            name = 'test_default_object',
            args = {
                arg = input_object,
            },
            kind = types.string,
            callback = 'test.test_default_object',
        })
    ]])

    t.assert_equals(
        server:graphql({
            query = [[
                query($arg: String = "default_value") {
                    test_default_value(arg: $arg)
                }
            ]],
        variables = {}}
        ).data.test_default_value, 'default_value'
    )

    t.assert_equals(
        server:graphql({
            query = [[
                query($arg: String = "default_value") {
                    test_default_value(arg: $arg)
                }
            ]],
        variables = {arg = box.NULL}}
        ).data.test_default_value, 'nil'
    )

    t.assert_equals(
        server:graphql({
            query = [[
                query($arg: [String] = ["default_value"]) {
                    test_default_list(arg: $arg)
                }
            ]],
        variables = {}}
        ).data.test_default_list, 'default_value'
    )

    t.assert_equals(
        server:graphql({
            query = [[
                query($arg: [String] = ["default_value"]) {
                    test_default_list(arg: $arg)
                }
            ]],
        variables = {arg = box.NULL}}
        ).data.test_default_list, 'nil'
    )

    t.assert_equals(
        server:graphql({
            query = [[
                query($arg: default_input_object = {field: "default_value"}) {
                    test_default_object(arg: $arg)
                }
            ]],
        variables = {}}
        ).data.test_default_object, 'default_value'
    )

    t.assert_equals(
        server:graphql({
            query = [[
                query($arg: default_input_object = {field: "default_value"}) {
                    test_default_object(arg: $arg)
                }
            ]],
        variables = {arg = box.NULL}}
        ).data.test_default_object, 'nil'
    )

    t.assert_equals(
        server:graphql({
            query = [[
                query($field: Json = "{\"test\": 123}") {
                    test_json_type(
                        field: $field
                    )
                }
            ]],
            variables = {}}
        ).data.test_json_type, '{"test":123}'
    )
end

g.test_null = function()
    local server = cluster.main_server

    server.net_box:eval([[
        package.loaded['test'] = package.loaded['test'] or {}
        package.loaded['test']['test_null'] = function(_, args)
            if args.arg == nil then
                return 'nil'
            end
            return args.arg
        end

        local graphql = require('cartridge.graphql')
        local types = require('cartridge.graphql.types')

        graphql.add_callback({
            name = 'test_null_nullable',
            args = {
                arg = types.string,
            },
            kind = types.string,
            callback = 'test.test_null',
        })

        graphql.add_callback({
            name = 'test_null_non_nullable',
            args = {
                arg = types.string.nonNull,
            },
            kind = types.string,
            callback = 'test.test_null',
        })
    ]])

    t.assert_equals(
        server:graphql({
            query = [[
                query {
                    test_null_nullable(arg: null)
                }
            ]],
        variables = {}}
        ).data.test_null_nullable, 'nil'
    )

    t.assert_error_msg_equals('Expected non-null for "NonNull(String)", got null', function()
        return server:graphql({
            query = [[
                query {
                    test_null_non_nullable(arg: null)
                }
            ]]})
    end)
end
