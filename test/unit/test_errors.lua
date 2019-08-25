#!/usr/bin/env tarantool

if not pcall(require, 'cartridge.front-bundle') then
    -- to be loaded in development environment
    package.preload['cartridge.front-bundle'] = function()
        return require('webui.build.bundle')
    end
end

local log = require('log')
local tap = require('tap')
local socket = require('socket')
local cartridge = require('cartridge')
local membership = require('membership')

local test = tap.test('cartridge.cfg')

test:plan(12)

local function check_error(expected_error, fn, ...)
    local ok, err = fn(...)
    if err == nil then
        test:fail(expected_error)
        return
    end

    for _, l in pairs(string.split(tostring(err), '\n')) do
        test:diag('%s', l)
    end
    test:like(err.err, expected_error, expected_error)
end

-- workdir --------------------------------------------------------------------
-------------------------------------------------------------------------------
test:diag('Test malformed opts.workdir')
check_error('Error creating directory "/dev/null": File exists',
    cartridge.cfg, {
        workdir = '/dev/null',
        advertise_uri = 'localhost:33001',
        roles = {},
    }
)

-- advertise_uri --------------------------------------------------------------
-------------------------------------------------------------------------------
test:diag('Test malformed opts.advertise_uri')

check_error('Invalid port in advertise_uri "localhost:invalid"',
    cartridge.cfg, {
        workdir = './dev',
        advertise_uri = 'localhost:invalid',
        roles = {},
    }
)

check_error('Invalid advertise_uri ":1111"',
    cartridge.cfg, {
        workdir = './dev',
        advertise_uri = ':1111',
        roles = {},
    }
)

local _sock = socket('AF_INET', 'SOCK_DGRAM', 'udp')
local ok = _sock:bind('0.0.0.0', 33001)
check_error('Socket bind error: Address already in use',
    cartridge.cfg, {
        workdir = './dev',
        advertise_uri = 'localhost:33001',
        roles = {},
    }
)
_sock:close()
_sock = nil

check_error('Can not ping myself: ping was not sent',
    cartridge.cfg, {
        workdir = './dev',
        advertise_uri = 'invalid-host:33001',
        roles = {},
    }
)
membership.leave()

-- monkeypatch membership to simplify subsequent tests ------------------------
-------------------------------------------------------------------------------

local fn_true = function()
    return true
end
membership.init = fn_true
membership.probe_uri = fn_true
membership.broadcast = fn_true
require('membership.members').myself = function()
    return {
        uri = 'unused:0',
        payload = {},
    }
end

-- roles ----------------------------------------------------------------------
-------------------------------------------------------------------------------
test:diag('Test malformed opts.roles')

check_error([[module 'unknown%-role' not found]],
    cartridge.cfg, {
        workdir = './dev',
        advertise_uri = 'unused:0',
        roles = {
            'cartridge.roles.vshard-storage',
            'cartridge.roles.vshard-router',
            'unknown-role',
        },
    }
)

-- auth_backend ---------------------------------------------------------------
-------------------------------------------------------------------------------
test:diag('Test malformed opts.auth_backend_name')

check_error([[module 'unknown%-auth' not found]],
    cartridge.cfg, {
        workdir = './dev',
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
        workdir = './dev',
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
        workdir = './dev',
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
        workdir = './dev',
        advertise_uri = 'unused:0',
        auth_backend_name = 'auth-invalid-method',
        roles = {},
    }
)

-- ok -------------------------------------------------------------------------
-------------------------------------------------------------------------------
test:diag('Test successful cartridge.cfg')

local opts = {
        workdir = '/tmp',
        advertise_uri = 'unused:0',
    roles = {
        'cartridge.roles.vshard-storage',
        'cartridge.roles.vshard-router',
    },
}
test:ok(
    cartridge.cfg(opts)
)

check_error('Cluster is already initialized',
    cartridge.cfg, opts
)

os.exit(test:check() and 0 or 1)
