local fio = require('fio')

local helpers = require('test.helper')
local t = require('luatest')
local g = t.group()

function g.before_all()
    g.tempdir = fio.tempdir()
    g.srv_basic = helpers.entrypoint('srv_basic')
    g.cluster = helpers.Cluster:new({
        datadir = g.tempdir,
        use_vshard = true,
        cookie = 'test-cluster-cookie',
        server_command = g.srv_basic,
        args = nil,
        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {'vshard-router', 'vshard-storage'},
            servers = {{
                alias = 'leader',
                instance_uuid = helpers.uuid('a', 'a', 1),
                advertise_port = 13301,
                http_port = 8081,
                env = {
                    TARANTOOL_AUTO_UPGRADE_SCHEMA = 'true',
                },
            }, {
                alias = 'replica',
                instance_uuid = helpers.uuid('a', 'a', 2),
                advertise_port = 13302,
                http_port = 8082,
            }},
        }},
    })
end

function g.after_all()
    fio.rmtree(g.tempdir)
end

local function start_cartridge(server_command, ...)
    g.cluster.server_command = server_command
    g.cluster.args = {...}
    for _, server in ipairs(g.cluster.servers) do
        server.command = server_command
        server.args = {...}
    end
    g.cluster:start()
end

function g.test_upgrade()
    local tarantool_older_path = os.getenv('TARANTOOL_OLDER_PATH')
    local tarantool_newer_path = os.getenv('TARANTOOL_NEWER_PATH')
    t.skip_if(
        tarantool_older_path == nil or tarantool_newer_path == nil,
        'No older or newer version provided. Skipping'
    )

    start_cartridge(tarantool_older_path, g.srv_basic)
    g.cluster.main_server.net_box:eval([[
box.schema.create_space('test', {
    format = {
        id = 'unsigned',
        name = 'string'
    }
})
]])
    local old_tarantool_version = string.split(
        g.cluster.main_server.net_box:eval('return _TARANTOOL'), '.'
    )
    local old_schema_version = g.cluster.main_server.net_box.space._schema:get{'version'}
    t.assert_equals(old_schema_version[2], tonumber(old_tarantool_version[1]))
    t.assert_equals(old_schema_version[3], tonumber(old_tarantool_version[2]))
    local old_space = g.cluster.main_server.net_box:eval('return box.space')
    g.cluster:stop()

    start_cartridge(tarantool_newer_path, g.srv_basic)
    local new_tarantool_version = string.split(
        g.cluster.main_server.net_box:eval('return _TARANTOOL'), '.'
    )
    local new_schema_version = g.cluster.main_server.net_box.space._schema:get{'version'}
    t.assert_equals(new_schema_version[2], tonumber(new_tarantool_version[1]))
    t.assert_equals(new_schema_version[3], tonumber(new_tarantool_version[2]))

    local new_space = g.cluster.main_server.net_box:eval('return box.space')
    t.assert_equals(old_space, new_space)
    g.cluster:stop()
end
