local fio = require('fio')
local socket = require('socket')
local log = require('log')

local t = require('luatest')
local g = t.group('console_sock')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

local server
local tmpdir

local notify_socket 

local function build_notify_socket()
    notify_socket = assert(socket('AF_UNIX', 'SOCK_DGRAM', 0), 'Can not create socket')
    assert(notify_socket:bind('unix/', server.env.TARANTOOL_NOTIFY_SOCK), notify_socket:error())
    fio.chmod(server.env.TARANTOOL_NOTIFY_SOCK, tonumber('0666', 8))
end

local function wait_notify()
    while true do
        if notify_socket:readable(1) then
            local msg = notify_socket:recv()
            if msg:match('READY=1') then
                fio.unlink(server.env.TARANTOOL_NOTIFY_SOCK)
                return
            end
        end
    end
end

g.before_all = function()
    log.level(7)
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
            TARANTOOL_NOTIFY_SOCK = fio.pathjoin(tmpdir, '/notify.sock')
        },
    })
    build_notify_socket()
    server:start()
    wait_notify()
    --t.helpers.retrying({}, function() server:graphql({query = '{}'}) end)
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
