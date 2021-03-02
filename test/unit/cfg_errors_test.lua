#!/usr/bin/env tarantool

local t = require('luatest')
local g = t.group()

if not pcall(require, 'cartridge.front-bundle') then
    -- to be loaded in development environment
    package.preload['cartridge.front-bundle'] = function()
        return require('webui.build.bundle')
    end
end

local log = require('log')
local fio = require('fio')
local errno = require('errno')
local fiber = require('fiber')
local checks = require('checks')
local socket = require('socket')
local cartridge = require('cartridge')
local membership = require('membership')

g.before_all(function()
    g.tempdir = fio.tempdir()
    g.membership_backup = table.copy(membership)
end)

g.after_all(function()
    fio.rmtree(g.tempdir)
end)

local fn_true = function() return true end
local fn_false = function() return false end

function g.mock_membership()
    table.clear(membership)
    membership.init = fn_true
    membership.probe_uri = fn_true
    membership.broadcast = fn_true
    membership.set_encryption_key = fn_true
    membership.set_payload = fn_true
    membership.subscribe = function()
        return fiber.cond()
    end
    membership.myself = function()
        return {
            uri = 'unused:0',
            status = require('membership.options').ALIVE,
            incarnation = 1,
            payload = {},
        }
    end
end

g.after_each(function()
    table.clear(membership)
    for k, v in pairs(g.membership_backup) do
        membership[k] = v
    end

    cartridge = nil
    for name, _ in pairs(package.loaded) do
        if name:startswith('cartridge') then
            package.loaded[name] = nil
        end
    end
    rawset(_G, "_cluster_vars_defaults", nil)
    rawset(_G, "_cluster_vars_values", nil)
    cartridge = require('cartridge')
end)

local function check_error(expected_error, fn, ...)
    checks('string', 'function')
    local ok, err = fn(...)
    if type(ok) ~= 'nil' then
        error("Call succeded, but it shouldn't", 2)
    end

    for _, l in pairs(string.split(tostring(err), '\n')) do
        log.info('-- %s', l)
    end

    if not string.find(err.err, expected_error, nil, true) then
        local e = string.format(
            "Mismatching error message:\n" ..
            "expected: %s\n" ..
            "  actual: %s\n",
            expected_error, err
        )
        log.error('\n%s', e)
        error(e, 2)
    end
end

-- workdir --------------------------------------------------------------------
-------------------------------------------------------------------------------
g.test_workdir = function()
    -- Test malformed opts.workdir
    check_error(
        'Error creating directory "/dev/null": File exists',
        cartridge.cfg, {
            workdir = '/dev/null',
            advertise_uri = 'localhost:13301',
            roles = {},
        }
    )
end

-- advertise_uri --------------------------------------------------------------
-------------------------------------------------------------------------------

g.test_advertise_uri = function()
    -- Test malformed opts.advertise_uri
    check_error('Invalid port in advertise_uri "localhost:invalid"',
        cartridge.cfg, {
            workdir = g.tempdir,
            advertise_uri = 'localhost:invalid',
            roles = {},
        }
    )

    check_error('Invalid advertise_uri ":1111"',
        cartridge.cfg, {
            workdir = g.tempdir,
            advertise_uri = ':1111',
            roles = {},
        }
    )

    local _sock = socket('AF_INET', 'SOCK_DGRAM', 'udp')
    _sock:bind('0.0.0.0', 13301)
    check_error(
        'Socket bind error (13301/udp): ' ..
        errno.strerror(errno.EADDRINUSE),
        cartridge.cfg, {
            workdir = g.tempdir,
            advertise_uri = 'localhost:13301',
            roles = {},
        }
    )
    _sock:close()

    check_error('Can not ping myself',
        cartridge.cfg, {
            workdir = g.tempdir,
            advertise_uri = 'invalid-host:13301',
            roles = {},
        }
    )
    membership.leave()

end

-- roles ----------------------------------------------------------------------
-------------------------------------------------------------------------------
g.test_roles = function()
    g.mock_membership()
    -- Test malformed opts.roles

    check_error([[module 'unknown-role' not found]],
        cartridge.cfg, {
            workdir = g.tempdir,
            advertise_uri = 'unused:0',
            http_enabled = false,
            roles = {
                'cartridge.roles.vshard-storage',
                'cartridge.roles.vshard-router',
                'unknown-role',
            },
        }
    )
end


-- auth_backend ---------------------------------------------------------------
-------------------------------------------------------------------------------

g.test_auth_backend = function()
    g.mock_membership()
    -- Test malformed opts.auth_backend_name

    check_error([[module 'unknown-auth' not found]],
        cartridge.cfg, {
            workdir = g.tempdir,
            advertise_uri = 'unused:0',
            auth_backend_name = 'unknown-auth',
            roles = {},
        }
    )


    package.preload['myauth'] = function()
        error('My auth can not be loaded')
    end
    check_error('My auth can not be loaded',
        cartridge.cfg, {
            workdir = g.tempdir,
            advertise_uri = 'unused:0',
            auth_backend_name = 'myauth',
            roles = {},
        }
    )

    package.preload['auth-unknown-method'] = function()
        return {
            unknown_method = function() end,
        }
    end
    check_error('unexpected argument callbacks.unknown_method to set_callbacks',
        cartridge.cfg, {
            workdir = g.tempdir,
            advertise_uri = 'unused:0',
            auth_backend_name = 'auth-unknown-method',
            roles = {},
        }
    )

    package.preload['auth-invalid-method'] = function()
        return {
            check_password = 'not-a-function',
        }
    end
    check_error('bad argument callbacks.check_password to set_callbacks',
        cartridge.cfg, {
            workdir = g.tempdir,
            advertise_uri = 'unused:0',
            auth_backend_name = 'auth-invalid-method',
            roles = {},
        }
    )
end

g.test_console_sock_enobufs = function()
    g.mock_membership()

    local sock_dir = fio.pathjoin(g.tempdir, 'sock')
    local sock_name = string.format('%s/%s.sock', sock_dir, ('a'):rep(110))
    fio.mktree(sock_dir)

    local ok, err = cartridge.cfg({
        workdir = '/tmp',
        advertise_uri = 'unused:0',
        http_enabled = false,
        roles = {},
        console_sock = sock_name,
    })

    t.assert_not(ok)
    log.info('%s', err)
    t.assert_covers(err, {
        class_name = 'ConsoleListenError',
        err = 'unix/:' .. sock_name .. ': ' ..
            'Too long console_sock exceeds UNIX_PATH_MAX limit',
    })
    t.assert_equals(fio.listdir(sock_dir), {})
end

g.test_console_sock_enoent = function()
    g.mock_membership()

    local sock_name = fio.pathjoin(g.tempdir, 'no', 'such', 'file')

    local ok, err = cartridge.cfg({
        workdir = '/tmp',
        advertise_uri = 'unused:0',
        http_enabled = false,
        roles = {},
        console_sock = sock_name,
    })

    t.assert_not(ok)
    log.info('%s', err)
    t.assert_covers(err, {
        class_name = 'ConsoleListenError',
        err = 'unix/:' .. sock_name .. ': ' .. errno.strerror(errno.ENOENT),
    })
end

-- resolve_dns ----------------------------------------------------------------
-------------------------------------------------------------------------------

g.test_dns_resolve_after_wait = function()
    g.mock_membership()
    membership.probe_uri = fn_false
    os.setenv('TARANTOOL_PROBE_URI_TIMEOUT', '0.3')

    fiber.create(function()
        -- sleep time < probe_uri_timeout == 0.3
        fiber.sleep(0.1)
        membership.probe_uri = fn_true
    end)

    local ok, err = cartridge.cfg({
        workdir = g.tempdir,
        advertise_uri = 'localhost:13001',
        roles = {},
        http_enabled = false,
    })
    t.assert(ok, err)

    os.setenv('TARANTOOL_PROBE_URI_TIMEOUT', nil)
    membership.probe_uri = fn_true
end

g.test_dns_not_resolve_after_wait = function()
    g.mock_membership()
    membership.probe_uri = fn_false
    os.setenv('TARANTOOL_PROBE_URI_TIMEOUT', '0.3')

    local start_time = fiber.clock()
    check_error('Can not ping myself',
        cartridge.cfg, {
            workdir = g.tempdir,
            advertise_uri = 'localhost:13001',
            roles = {},
            http_enabled = false,
        }
    )
    t.assert(fiber.clock() - start_time > 0.3, 'Waited time < probe_uri_timeout')

    os.setenv('TARANTOOL_PROBE_URI_TIMEOUT', nil)
    membership.probe_uri = fn_true
end

-- ok -------------------------------------------------------------------------
-------------------------------------------------------------------------------

g.test_positive = function()
    g.mock_membership()
    membership.broadcast = function() error('Forbidden', 0) end
    -- Test successful cartridge.cfg

    local opts = {
            workdir = '/tmp',
            advertise_uri = 'unused:0',
            http_enabled = false,
            swim_broadcast = false,
        roles = {
            'cartridge.roles.vshard-storage',
            'cartridge.roles.vshard-router',
        },
    }

    local ok, err = cartridge.cfg(opts)
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    log.info('----------------')

    check_error('Cluster is already initialized',
        cartridge.cfg, opts
    )
end

g.test_webui_disabled = function()
    g.mock_membership()
    membership.broadcast = function() error('Forbidden', 0) end

    local opts = {
        workdir = '/tmp',
        advertise_uri = 'unused:0',
        http_enabled = true,
        webui_enabled = false,
        swim_broadcast = false,
        roles = {
            'cartridge.roles.vshard-storage',
            'cartridge.roles.vshard-router',
        },
    }

    local ok, err = cartridge.cfg(opts)
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)

    local service = require('cartridge.service-registry')
    local httpd = service.get('httpd')
    t.assert_items_equals(
        require('fun').iter(httpd.routes):map(function(r) return r.path end):totable(),
        {"/login", "/logout", "/admin/api"}
    )

    httpd:stop()
end
