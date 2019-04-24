#!/usr/bin/env tarantool

local log = require('log')
local tap = require('tap')
local socket = require('socket')
local cluster = require('cluster')

local test = tap.test('cluster.cfg')

test:plan(12)

local function check_error(expected_error, fn, ...)
    local ok, err = fn(...)
    for _, l in pairs(string.split(tostring(err), '\n')) do
        test:diag('%s', l)
    end
    test:like(err.err, expected_error, expected_error)
end

check_error('Can not create workdir "/dev/null"',
    cluster.cfg, {
        workdir = '/dev/null',
        advertise_uri = 'localhost:3301',
    }
)

check_error('Missing port in advertise_uri "localhost"',
    cluster.cfg, {
        workdir = './dev',
        advertise_uri = 'localhost',
    }
)

local _sock = socket('AF_INET', 'SOCK_DGRAM', 'udp')
local ok = _sock:bind('0.0.0.0', 3301)
check_error('Socket bind error',
    cluster.cfg, {
        workdir = './dev',
        advertise_uri = 'localhost:3301',
    }
)
_sock:close()
_sock = nil

check_error('Can not ping myself: ping was not sent',
    cluster.cfg, {
        workdir = './dev',
        advertise_uri = 'invalid-host:33004',
    }
)

check_error([[module 'unknown%-role' not found]],
    cluster.cfg, {
        workdir = './dev',
        advertise_uri = 'localhost:33003',
        roles = {
            'cluster.roles.vshard-storage',
            'cluster.roles.vshard-router',
            'unknown-role',
        },
    }
)

check_error([[module 'unknown%-auth' not found]],
    cluster.cfg, {
        workdir = './dev',
        advertise_uri = 'localhost:33005',
        auth_backend_name = 'unknown-auth',
    }
)

package.preload['myrole'] = function()
    error('My role can not be loaded')
end
check_error('My role can not be loaded',
    cluster.cfg, {
        workdir = './dev',
        advertise_uri = 'localhost:33002',
        roles = {
            'cluster.roles.vshard-storage',
            'cluster.roles.vshard-router',
            'myrole',
        },
    }
)

package.preload['myauth'] = function()
    error('My auth can not be loaded')
end
check_error('My auth can not be loaded',
    cluster.cfg, {
        workdir = './dev',
        advertise_uri = 'localhost:33006',
        auth_backend_name = 'myauth',
    }
)

package.preload['auth-unknown-method'] = function()
    return {
        unknown_method = function() end,
    }
end
check_error('unexpected argument callbacks.unknown_method to set_callbacks',
    cluster.cfg, {
        workdir = './dev',
        advertise_uri = 'localhost:33007',
        auth_backend_name = 'auth-unknown-method',
    }
)

package.preload['auth-invalid-method'] = function()
    return {
        check_password = 'not-a-function',
    }
end
check_error('bad argument callbacks.check_password to set_callbacks',
    cluster.cfg, {
        workdir = './dev',
        advertise_uri = 'localhost:33008',
        auth_backend_name = 'auth-invalid-method',
    }
)

local opts = {
    workdir = '/tmp',
    advertise_uri = 'localhost:33001',
    roles = {
        'cluster.roles.vshard-storage',
        'cluster.roles.vshard-router',
    },
}
test:ok(
    cluster.cfg(opts)
)

check_error('Cluster is already initialized',
    cluster.cfg, opts
)

os.exit(test:check() and 0 or 1)
