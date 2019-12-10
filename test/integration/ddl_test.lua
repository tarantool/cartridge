local fio = require('fio')
local t = require('luatest')
local g = t.group('ddl')
local log = require('log')
local yaml = require('yaml')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

local function _get_schema(server)
    local ret = server:graphql({query = [[{
        cluster {
            schema {
                as_yaml
            }
        }
    }]]})

    return ret.data.cluster.schema
end

local function _set_schema(server, as_yaml)
    local ret = server:graphql({query = [[
        mutation($yaml: String!) {
            cluster {
                schema(as_yaml: $yaml) {
                    as_yaml
                }
            }
        }]],
        variables = {yaml = as_yaml}
    })

    return ret.data.cluster.schema
end

local function _check_schema(server, as_yaml)
    local ret = server:graphql({query = [[
        mutation($yaml: String!) {
            cluster {
                check_schema(as_yaml: $yaml) {
                    error
                }
            }
        }]],
        variables = {yaml = as_yaml}
    })

    return ret.data.cluster.check_schema
end

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        use_vshard = true,
        cookie = 'test-cluster-cookie',
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = {
                    {
                        alias = 'router',
                        instance_uuid = helpers.uuid('a', 'a', 1),
                    }
                }
            }, {
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                servers = {
                    {
                        alias = 'storage-1',
                        instance_uuid = helpers.uuid('b', 'b', 1),
                    }, {
                        alias = 'storage-2',
                        instance_uuid = helpers.uuid('b', 'b', 2),
                    }
                }
            }
        }
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local _schema = [[
spaces:
  test_space:
    engine: memtx
    is_local: false
    temporary: false
    format:
    - name: x
      type: unsigned
      is_nullable: false
    indexes:
    - name: pk
      type: TREE
      unique: true
      parts:
      - path: x
        is_nullable: false
        type: unsigned
]]

--------------------------------------------------------------------------------

function g.test_luaapi()
    local function call(...)
        return g.cluster.main_server.net_box:call(...)
    end

    log.info('Applying valid schema...')
    local schema = _schema .. "# P.S. It's fun\n"

    t.assert_equals(
        call('cartridge_set_schema', {schema}),
        schema
    )

    log.info('Reapplying valid schema...')

    t.assert_equals(
        call('cartridge_set_schema', {schema}),
        schema
    )

    t.assert_equals(
        call('cartridge_get_schema'),
        schema
    )

    -- Applying schema on a replica may take a while, so we don't check it
    -- See: https://github.com/tarantool/tarantool/issues/4668
    for _, alias in pairs({'router', 'storage-1'}) do
        local srv = g.cluster:server(alias)
        t.assert_equals(
            {[srv.alias] = srv.net_box:eval([[
                return require('ddl').get_schema().spaces.test_space
            ]])},
            {[srv.alias] = yaml.decode(_schema).spaces.test_space}
        )
    end

    log.info('Patching with invalid schema...')

    t.assert_equals(
        {call('cartridge_set_schema', {'{"spaces":{}}'})},
        {box.NULL, 'Missing space "test_space" in schema,' ..
        ' removing spaces is forbidden'}
    )

    t.assert_equals(
        _get_schema(g.cluster.main_server).as_yaml,
        schema
    )
end

function g.test_formatting_preserved()
    -- cartridge should preserve yaml formatting
    local server = g.cluster.main_server
    local schema = _schema .. '# I hope my comments are preserved\n'

    t.assert_equals(_check_schema(server, schema), {error = box.NULL})
    t.assert_equals(_set_schema(server, schema), {as_yaml = schema})
    t.assert_equals(_get_schema(server), {as_yaml = schema})
end

function g.test_replicas()
    -- check_schema should work on read-only replicas

    for _, srv in pairs(g.cluster.servers) do
        t.assert_equals(
            {[srv.alias] = _check_schema(srv, _schema)},
            {[srv.alias] = {error = box.NULL}}
        )

        t.assert_equals(
            {[srv.alias] = _check_schema(srv, '---\n...')},
            {[srv.alias] = {error = 'Schema must be a table, got string'}}
        )
    end
end

function g.test_graphql_errors()
    local server = g.cluster.main_server
    _set_schema(server, _schema)

    local function _test(schema, expected_error)
        t.assert_equals(
            _check_schema(server, schema),
            {error = expected_error}
        )
        t.assert_error_msg_contains(
            expected_error,
            _set_schema, server, schema
        )
    end

    _test('][', 'unexpected END event')
    _test('42', 'Schema must be a table, got number')
    _test('spaces: false',
        'Bad argument #1 to ddl.check_schema' ..
        ' invalid schema.spaces (?table expected, got boolean)'
    )
    _test('spaces: {}',
        'Missing space "test_space" in schema,' ..
        ' removing spaces is forbidden'
    )
    _test(_schema:gsub('memtx', 'vinyl'),
        'Incompatible schema: space["test_space"]' ..
        ' //engine (expected memtx, got vinyl)'
    )
end

