local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local fio = require('fio')

g.server = t.Server:new({
    command = helpers.entrypoint('srv_empty'),
    workdir = fio.tempdir(),
    net_box_port = 13300,
    net_box_credentials = {user = 'admin', password = ''},
})

g.before_each(function()
    g.server:start()
    helpers.retrying({}, function() g.server:connect_net_box() end)
end)

g.after_each(function()
    g.server:stop()
    fio.rmtree(g.server.workdir)
end)

local function mock()
    local fiber = require('fiber')
    local fn_true = function() return true end

    package.loaded['membership'] = {
        init = fn_true,
        probe_uri = fn_true,
        broadcast = fn_true,
        set_payload = fn_true,
        set_encryption_key = fn_true,
        subscribe = function() return fiber.cond() end,
        myself = function()
            return {
                uri = '127.0.0.1:0',
                status = 1,
                incarnation = 1,
                payload = {},
            }
        end,
    }

    package.loaded['cartridge.remote-control'] = {
        bind = fn_true,
        accept = fn_true,
    }
end

-- workdir --------------------------------------------------------------------
-------------------------------------------------------------------------------
g.test_workdir = function()
    helpers.run_remotely(g.server, mock)
    helpers.run_remotely(g.server, function()
        local t = require('luatest')
        os.setenv('TARANTOOL_WORKDIR', nil)
        -- Test malformed opts.workdir
        local ok, err = require('cartridge').cfg({
            advertise_uri = '127.0.0.1:0',
            workdir = '/dev/null',
            roles = {},
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'MktreeError',
            err = 'Error creating directory "/dev/null": File exists',
        })
    end)
end

-- advertise_uri --------------------------------------------------------------
-------------------------------------------------------------------------------

g.test_advertise_uri = function()
    helpers.run_remotely(g.server, function()
        local t = require('luatest')

        local ok, err = require('cartridge').cfg({
            advertise_uri = 'localhost:invalid',
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'CartridgeCfgError',
            err = 'Invalid port in advertise_uri "localhost:invalid"',
        })
    end)

    helpers.run_remotely(g.server, function()
        local t = require('luatest')

        local ok, err = require('cartridge').cfg({
            advertise_uri = ':1111',
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'CartridgeCfgError',
            err = 'Invalid advertise_uri ":1111"',
        })
    end)

    helpers.run_remotely(g.server, function()
        local t = require('luatest')
        local errno = require('errno')

        local _sock = require('socket')('AF_INET', 'SOCK_DGRAM', 'udp')
        _sock:bind('0.0.0.0', 13301)

        local ok, err = require('cartridge').cfg({
            advertise_uri = 'localhost:13301',
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'CartridgeCfgError',
            err = 'Socket bind error (13301/udp): ' ..
                errno.strerror(assert(errno.EADDRINUSE)),
        })

        _sock:close()
    end)

    helpers.run_remotely(g.server, function()
        local t = require('luatest')

        local ok, err = require('cartridge').cfg({
            advertise_uri = 'invalid-host:13301',
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'CartridgeCfgError',
            err = 'Can not ping myself: ping was not sent',
        })
    end)
end

-- http -----------------------------------------------------------------------
-------------------------------------------------------------------------------


g.test_http = function()
    helpers.run_remotely(g.server, function()
        local t = require('luatest')
        local errno = require('errno')

        local ok, err = require('cartridge').cfg({
            swim_broadcast = false,
            advertise_uri = 'localhost:13301',
            http_host = '255.255.255.255',
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {class_name = 'HttpInitError'})
        t.assert_str_matches(err.err, '.+: ' ..
            "Can't create tcp_server: " ..
                errno.strerror(assert(errno.EINVAL))
        )
    end)

    helpers.run_remotely(g.server, function()
        local t = require('luatest')
        local errno = require('errno')

        local _sock = require('socket')('AF_INET', 'SOCK_STREAM', 'tcp')
        _sock:bind('0.0.0.0', 18080)

        local ok, err = require('cartridge').cfg({
            swim_broadcast = false,
            advertise_uri = 'localhost:13301',
            http_port = 18080,
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {class_name = 'HttpInitError'})
        t.assert_str_matches(err.err, '.+: ' ..
            "Can't create tcp_server: " ..
                errno.strerror(assert(errno.EADDRINUSE))
        )

        _sock:close()
    end)
end

-- issues_limits --------------------------------------------------------------
-------------------------------------------------------------------------------

g.test_issues_limits = function()
    helpers.run_remotely(g.server, function()
        local t = require('luatest')
        os.setenv('TARANTOOL_CLOCK_DELTA_THRESHOLD_WARNING', '-1')

        local ok, err = require('cartridge').cfg({
            swim_broadcast = false,
            advertise_uri = 'localhost:13301',
            http_enabled = false,
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'ValidateConfigError',
            err = 'limits.clock_delta_threshold_warning must be in range [0, inf]',
        })
    end)
end
g.after_test('test_issues_limits', function()
    helpers.run_remotely(g.server, function()
        os.setenv('TARANTOOL_CLOCK_DELTA_THRESHOLD_WARNING', nil)
    end)
end)

-- roles ----------------------------------------------------------------------
-------------------------------------------------------------------------------
g.test_roles = function()
    helpers.run_remotely(g.server, function()
        local t = require('luatest')

        local ok, err = require('cartridge').cfg({
            advertise_uri = 'localhost:13301',
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {'unknown-role'},
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {class_name = 'RegisterRoleError'})
        t.assert_str_matches(err.err, "module 'unknown%-role' not found:\n.+")
    end)
end

-- auth_backend ---------------------------------------------------------------
-------------------------------------------------------------------------------

g.test_custom_auth_backend = function()
    helpers.run_remotely(g.server, mock)
    helpers.run_remotely(g.server, function()
        local t = require('luatest')

        local ok, err = require('cartridge').cfg({
            advertise_uri = '127.0.0.1:0',
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
            auth_backend_name = 'unknown-auth',
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {class_name = 'CartridgeCfgError'})
        t.assert_str_matches(err.err, "module 'unknown%-auth' not found:\n.+")
    end)

    helpers.run_remotely(g.server, function()
        local t = require('luatest')

        package.loaded.myauth = nil
        package.preload['myauth'] = function()
            error('My auth can not be loaded', 0)
        end
        local ok, err = require('cartridge').cfg({
            advertise_uri = '127.0.0.1:0',
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
            auth_backend_name = 'myauth',
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'CartridgeCfgError',
            err = 'My auth can not be loaded',
        })
    end)

    helpers.run_remotely(g.server, function()
        local t = require('luatest')

        package.loaded.myauth = nil
        package.preload['myauth'] = function() return '' end
        local ok, err = require('cartridge').cfg({
            advertise_uri = '127.0.0.1:0',
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
            auth_backend_name = 'myauth',
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'CartridgeCfgError',
            err = 'Auth backend must export a table, got string',
        })
    end)

    helpers.run_remotely(g.server, function()
        local t = require('luatest')

        package.loaded.myauth = nil
        package.preload['myauth'] = function()
            return { check_password = 'not-a-function' }
        end
        local ok, err = require('cartridge').cfg({
            advertise_uri = '127.0.0.1:0',
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
            auth_backend_name = 'myauth',
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {class_name = 'CartridgeCfgError'})
        t.assert_equals(err.err,
            "Invalid auth callback 'check_password'" ..
            " (function expected, got string)"
        )
    end)

    helpers.run_remotely(g.server, function()
        local t = require('luatest')

        package.loaded.myauth = nil
        package.preload['myauth'] = function()
            return { unknown_method = function() end }
        end
        local ok, err = require('cartridge').cfg({
            advertise_uri = '127.0.0.1:0',
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
            auth_backend_name = 'myauth',
        })

        t.assert_equals(err, nil)
        t.assert_equals(ok, true)
    end)
end

g.test_default_auth_backend = function()
    helpers.run_remotely(g.server, mock)
    helpers.run_remotely(g.server, function()
        local t = require('luatest')

        -- Invalidate argparse cache before modifying environment
        require('cartridge.vars').new('cartridge.argparse').args = nil
        os.setenv('TARANTOOL_AUTH_BUILTIN_ADMIN_ENABLED', 'abracadabra')

        local ok, err = require('cartridge').cfg({
            advertise_uri = '127.0.0.1:0',
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {class_name = 'TypeCastError'})
        t.assert_equals(err.err, "can't typecast" ..
            " auth_builtin_admin_enabled=\"abracadabra\" to boolean"
        )
    end)
end

g.test_console_sock_enobufs = function()
    helpers.run_remotely(g.server, mock)
    helpers.run_remotely(g.server, function()
        local t = require('luatest')
        local fio = require('fio')
        local workdir = os.getenv('TARANTOOL_WORKDIR')

        local sock_dir = fio.pathjoin(workdir, 'sock')
        local sock_name = sock_dir .. '/' .. ('a'):rep(110) .. '.sock'
        fio.mktree(sock_dir)

        local ok, err = require('cartridge').cfg({
            advertise_uri = '127.0.0.1:0',
            http_enabled = false,
            workdir = workdir,
            roles = {},
            console_sock = sock_name,
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'ConsoleListenError',
            err = 'unix/:' .. sock_name .. ': ' ..
                'Too long console_sock exceeds UNIX_PATH_MAX limit',
        })
        t.assert_equals(fio.listdir(sock_dir), {})
    end)
end

g.test_console_sock_enoent = function()
    helpers.run_remotely(g.server, mock)
    helpers.run_remotely(g.server, function()
        local t = require('luatest')
        local errno = require('errno')

        local ok, err = require('cartridge').cfg({
            advertise_uri = '127.0.0.1:0',
            http_enabled = false,
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
            console_sock = '/no/such/file',
        })

        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'ConsoleListenError',
            err = 'unix/:/no/such/file: ' ..
                errno.strerror(assert(errno.ENOENT)),
        })
    end)
end

-- resolve_dns ----------------------------------------------------------------
-------------------------------------------------------------------------------

g.test_dns_resolve_timeout = function()
    helpers.run_remotely(g.server, mock)
    helpers.run_remotely(g.server, function()
        local t = require('luatest')
        local fiber = require('fiber')
        t.assert_not(package.loaded['cartridge'])
        t.assert_not(package.loaded['cartridge.confapplier'])
        local membership = assert(package.loaded.membership)

        os.setenv('TARANTOOL_PROBE_URI_TIMEOUT', '0.3')
        membership.probe_uri = function() return false, 'go away' end

        local start_time = fiber.clock()
        local ok, err = require('cartridge').cfg({
            advertise_uri = '127.0.0.1:0',
            http_enabled = false,
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
        })


        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'CartridgeCfgError',
            err = 'Can not ping myself: go away',
        })

        t.assert(fiber.clock() - start_time > 0.3,
            'Waited time < probe_uri_timeout')
    end)

    helpers.run_remotely(g.server, function()
        local t = require('luatest')
        local fiber = require('fiber')
        local membership = assert(package.loaded.membership)

        fiber.new(function()
            -- sleep time < probe_uri_timeout == 0.3
            fiber.sleep(0.1)
            membership.probe_uri = function() return true end
        end)

        local ok, err = require('cartridge').cfg({
            advertise_uri = '127.0.0.1:0',
            http_enabled = false,
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            roles = {},
        })

        t.assert(ok, err)
    end)
end

-- ok -------------------------------------------------------------------------
-------------------------------------------------------------------------------

g.test_positive = function()
    helpers.run_remotely(g.server, mock)
    helpers.run_remotely(g.server, function()
        local t = require('luatest')
        local fun = require('fun')
        local membership = assert(package.loaded.membership)
        membership.broadcast = function() error('Forbidden', 0) end

        local opts = {
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            advertise_uri = '127.0.0.1:0',
            http_host = '127.0.0.1',
            http_enabled = true,
            webui_enabled = false,
            swim_broadcast = false,
            roles = {
                'cartridge.roles.vshard-storage',
                'cartridge.roles.vshard-router',
            },
        }

        local ok, err = require('cartridge').cfg(opts)
        t.assert(ok, err)

        local service = require('cartridge.service-registry')
        local httpd = service.get('httpd')
        t.assert_equals(
            setmetatable(httpd.tcp_server:name(), nil),
            {
                protocol = "tcp",
                family = "AF_INET",
                type = "SOCK_STREAM",
                host = "127.0.0.1",
                port = 8081,
            }
        )
        t.assert_items_equals(
            fun.map(function(r) return r.path end, httpd.routes):totable(),
            {"/login", "/logout", "/admin/api"}
        )

        local ok, err = require('cartridge').cfg(opts)
        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'CartridgeCfgError',
            err = 'Cluster is already initialized',
        })
    end)
end

g.test_webui_prefix = function()
    helpers.run_remotely(g.server, mock)
    helpers.run_remotely(g.server, function()
        local t = require('luatest')
        local fun = require('fun')
        local membership = assert(package.loaded.membership)
        membership.broadcast = function() error('Forbidden', 0) end

        local opts = {
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            advertise_uri = '127.0.0.1:0',
            http_host = '127.0.0.1',
            http_enabled = true,
            webui_enabled = true,
            webui_prefix = '/prefix',
            swim_broadcast = false,
            roles = {
                'cartridge.roles.vshard-storage',
                'cartridge.roles.vshard-router',
            },
        }

        local ok, err = require('cartridge').cfg(opts)
        t.assert(ok, err)

        local service = require('cartridge.service-registry')
        local httpd = service.get('httpd')
        t.assert_equals(
            setmetatable(httpd.tcp_server:name(), nil),
            {
                protocol = "tcp",
                family = "AF_INET",
                type = "SOCK_STREAM",
                host = "127.0.0.1",
                port = 8081,
            }
        )
        t.assert_items_include(
            fun.map(function(r) return r.path end, httpd.routes):totable(),
            {"/prefix/login", "/prefix/logout", "/prefix/admin/api", "/prefix/admin/config"}
        )

        local ok, err = require('cartridge').cfg(opts)
        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'CartridgeCfgError',
            err = 'Cluster is already initialized',
        })
    end)
end

g.test_advertise_uri_error = function()
    helpers.run_remotely(g.server, mock)

    helpers.run_remotely(g.server, function()
        local t = require('luatest')

        local ok, err = require('cartridge').cfg({
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            advertise_uri = '',
            roles = {},
        })
        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'CartridgeCfgError',
            err = 'Invalid advertise_uri ""',
        })
        local getaddrinfo = package.loaded.socket.getaddrinfo

        package.loaded.socket.getaddrinfo = function()
            return nil, 'error'
        end

        local ok, err = require('cartridge').cfg({
            workdir = os.getenv('TARANTOOL_WORKDIR'),
            advertise_uri = '127.0.0.1:0',
            roles = {},
        })
        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'InitError',
            err = 'Could not resolve advertise uri 127.0.0.1:0'
        })
        package.loaded.socket.getaddrinfo = getaddrinfo
    end)
end
