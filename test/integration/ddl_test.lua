local fio = require('fio')
local t = require('luatest')
local g = t.group()
local log = require('log')
local yaml = require('yaml')

local helpers = require('test.helper')

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

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = require('digest').urandom(6):hex(),
        replicasets = {{
            alias = 'main',
            roles = {'vshard-router', 'vshard-storage'},
            servers = 2
        }}
    })
    g.cluster:start()

    _set_schema(g.cluster.main_server, 'spaces: {}')
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

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
        return g.cluster.main_server:call(...)
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
    local srv = g.cluster:server('main-1')
    t.assert_equals(
        {[srv.alias] = srv:eval([[
            return require('ddl').get_schema().spaces.test_space
        ]])},
        {[srv.alias] = yaml.decode(_schema).spaces.test_space}
    )

    log.info('Patching with invalid schema...')

    local ok, err = call('cartridge_set_schema', {'{}'})
    t.assert_equals(ok, box.NULL)
    t.assert_covers(err, {
        class_name = 'CheckSchemaError',
        err = '"localhost:13301": spaces: must be a table, got nil'
    })

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

    end
    t.assert_equals(
        _check_schema(g.cluster:server('main-1'), '---\n...'),
        {
            error = 'Invalid schema (table expected, got string)',
        }
    )

    t.assert_equals(
        _check_schema(g.cluster:server('main-2'), '---\n...'),
        {
            error = '"localhost:13301": Invalid schema' ..
                ' (table expected, got string)',
        }
    )
end

function g.test_graphql_errors()
    local server = g.cluster.main_server
    _set_schema(server, _schema)

    t.assert_equals(
        _check_schema(server, ']['),
        {error = 'Invalid YAML: unexpected END event'}
    )
    t.assert_error_msg_contains(
        'Error parsing section "schema.yml": unexpected END event',
        _set_schema, server, ']['
    )

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

    _test('42', 'Invalid schema (table expected, got number)')
    _test('{}', 'spaces: must be a table, got nil')
    _test('spaces: false', 'spaces: must be a table, got boolean')
    _test(_schema:gsub('memtx', 'vinyl'),
        'Incompatible schema: spaces["test_space"]' ..
        ' //engine (expected memtx, got vinyl)'
    )
end

function g.test_space_removal()
    local server = g.cluster.main_server
    _set_schema(server, _schema)
    _set_schema(server, 'spaces: {}')

    for _, srv in pairs(g.cluster.servers) do
        helpers.retrying({}, function()
            srv.net_box:ping()
            t.assert(srv.net_box.space.test_space,
                string.format('Missing test_space on %s', srv.alias)
            )
        end)
    end
end

function g.test_example_schema()
    local server = g.cluster.main_server
    t.assert_str_matches(
        _set_schema(server, '').as_yaml,
        '## Example:\n.+'
    )

    local fun = require('fun')
    local example_yml = fun.map(
        function(l) return l:gsub('^# ', '') end,
        _get_schema(server).as_yaml:split('\n')
    ):totable()
    example_yml = table.concat(example_yml, '\n')

    _set_schema(server, example_yml)

    local space_name = next(yaml.decode(example_yml).spaces)

    for _, srv in pairs(g.cluster.servers) do
        helpers.retrying({}, function()
            srv.net_box:ping()
            t.assert(srv.net_box.space[space_name],
                string.format('Missing space %q on %s', space_name, srv.alias)
            )
        end)
    end
end

function g.test_no_instances_to_check_schema()
    local s1 = g.cluster:server('main-1')
    local s2 = g.cluster:server('main-2')

    -- restrict connection to the leader
    s1:call('box.cfg', {{listen = box.NULL}})
    s2:eval([[
        local pool = require('cartridge.pool')
        pool.connect(...):close()
        local conn = pool.connect(...)
        assert(conn:wait_connected() == false)
    ]], {s1.advertise_uri, {wait_connected = false}})

    t.assert_error_msg_matches(
        '.*"localhost:13301":.*Connection refused',
        _check_schema, s2, _schema
    )
end

g.after_test('test_no_instances_to_check_schema', function()
    -- restore box listen
    local s1 = g.cluster:server('main-1')
    s1:call('box.cfg', {{listen = s1.net_box_port}})
end)
