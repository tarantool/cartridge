local fio = require('fio')
local socket = require('socket')
local log = require('log')

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
    -- build notify socket
    local notify_socket = assert(socket('AF_UNIX', 'SOCK_DGRAM', 0), 'Can not create socket')
    if fio.stat(server.env.NOTIFY_SOCKET) then
        assert(fio.unlink(server.env.NOTIFY_SOCKET))
    end
    assert(notify_socket:bind('unix/', server.env.NOTIFY_SOCKET), notify_socket:error())
    fio.chmod(server.env.NOTIFY_SOCKET, tonumber('0666', 8))
    server:start()
    -- wait notify
    while true do
        if notify_socket:readable(1) then
            local msg = notify_socket:recv()
            log.info(msg)
            if msg:match('READY=1') then
                fio.unlink(server.env.NOTIFY_SOCKET)
                return
            end
        end
    end
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
