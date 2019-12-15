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
            TARANTOOL_CONSOLE_SOCK = fio.pathjoin(tmpdir, '/foo.sock'),
            NOTIFY_SOCKET = fio.pathjoin(tmpdir, '/notify.sock')
        },
    })
    local notify_socket = assert(socket('AF_UNIX', 'SOCK_DGRAM', 0), 'Can not create socket')
    assert(notify_socket:bind('unix/', server.env.NOTIFY_SOCKET), notify_socket:error())
    server:start()
    t.helpers.retrying({}, function() 
        while not notify_socket:readable(1) do
            msg = notify_socket:recv()
            if msg:match('READY=1') then
                    return
            end
        end 
    end)
end

g.after_all = function()
    server:stop()
    fio.rmtree(tmpdir)
end

g.test_console_sock = function()
    local s = socket.tcp_connect('unix/', fio.pathjoin(tmpdir, 'foo.sock'))
    t.assertTrue(s ~= nil)
    local greeting = s:read('\n')
    t.assertNotNil(greeting)
    t.assertStrMatches(greeting:strip(), 'Tarantool.*%(Lua console%)')
end
