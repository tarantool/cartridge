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
local checks = require('checks')
local errno = require('errno')
local socket = require('socket')
local cartridge = require('cartridge')
local membership = require('membership')

function g.before_all()
    g.tempdir = fio.tempdir()
end

function g.after_all()
    fio.rmtree(g.tempdir)
end

function g.mock_membership()
    g.membership_backup = {
        init = membership.init,
        probe_uri = membership.probe_uri,
        broadcast = membership.broadcast,
        myself = require('membership.members').myself,
    }

    local fn_true = function()
        return true
    end
    membership.probe_uri = fn_true
    membership.broadcast = fn_true

    membership.init = function(host, port)
        require('membership.options').set_advertise_uri(host .. ':' .. port)
        return true
    end

    require('membership.members').myself = function()
        return {
            uri = 'unused:0',
            status = require('membership.options').ALIVE,
            incarnation = 1,
            payload = {},
        }
    end
end

function g.teardown()
    if g.membership_backup ~= nil then
        membership.init = g.membership_backup.init
        membership.probe_uri = g.membership_backup.probe_uri
        membership.broadcast = g.membership_backup.broadcast
        require('membership.members').myself =
            g.membership_backup.myself
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
end

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
    check_error('Socket bind error: ' .. errno.strerror(errno.EADDRINUSE),
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

-- ok -------------------------------------------------------------------------
-------------------------------------------------------------------------------

g.test_positive = function()
    g.mock_membership()
    -- Test successful cartridge.cfg

    local opts = {
            workdir = '/tmp',
            advertise_uri = 'unused:0',
            http_enabled = false,
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
