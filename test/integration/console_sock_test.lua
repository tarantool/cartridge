local fio = require('fio')
local socket = require('socket')

local t = require('luatest')
local g = t.group('console_sock')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

local server
local tmpdir

g.before_all = function()
    tmpdir = fio.tempdir()
    server = helpers.Server:new({
        alias = 'server',
        workdir = tmpdir,
        command = test_helper.server_command,
        advertise_port = 13301,
        http_port = 8080,
        cluster_cookie = 'super-cluster-cookie',
        env = {
            TARANTOOL_CONSOLE_SOCK = fio.pathjoin(tmpdir, '/foo.sock')
        },
    })
    server:start()
    t.helpers.retrying({}, function() server:graphql({query = '{}'}) end)
end

g.after_all = function()
    server:stop()
    fio.rmtree(tmpdir)
end

g.test_console_sock = function()
    local s = socket.tcp_connect('unix/', fio.pathjoin(tmpdir, 'foo.sock'))
    t.assert(s)
    local greeting = s:read('\n')
    t.assert(greeting)
    t.assert_str_matches(greeting:strip(), 'Tarantool.*%(Lua console%)')
end
