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

g.test_upload_good = function()
    local server = cluster.main_server

    server.net_box:eval([[
        package.loaded['test'] = {}
        package.loaded['test']['test'] = function(root, args)
          return args[1].value
        end

        package.loaded['test']['test2'] = function(root, args)
          local result = ''
          for _, tuple in ipairs(getmetatable(args).__index) do
            result = result .. tuple.value
          end
          return result
        end

        local graphql = require('cartridge.graphql')
        local types = require('cartridge.graphql.types')
        graphql.add_callback({
            name = 'test',
            doc = '',
            args = {arg=types.string.nonNull},
            kind = types.string.nonNull,
            callback = 'test.test',
        })
        graphql.add_callback({
            name = 'test2',
            doc = '',
            args = {arg=types.string.nonNull,
                    arg2=types.string.nonNull,
            },
            kind = types.string.nonNull,
            callback = 'test.test2',
        })
    ]])

    t.assert_equals(server:graphql({query = '{ test(arg:"TEST") }'}).data.test, 'TEST')
    t.assert_equals(server:graphql({query = '{ test2(arg:"TEST", arg2:"22") }'}).data.test2, 'TEST22')
end

g.test_resolver_error = function()
    local server = cluster.main_server

    server.net_box:eval([[
        package.loaded['test'] = {}
        package.loaded['test']['test'] = function(root, args)
          return nil, 'Internal error from my test function'
        end

        local graphql = require('cartridge.graphql')
        local types = require('cartridge.graphql.types')
        graphql.add_callback({
            name = 'test',
            doc = '',
            args = {arg=types.string.nonNull},
            kind = types.string.nonNull,
            callback = 'test.test',
        })
    ]])

    t.assert_error_msg_contains('Internal error from my test function', function()
        server:graphql({query = '{ test(arg:"TEST") }'})
    end)
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
