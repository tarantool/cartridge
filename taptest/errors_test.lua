#!/usr/bin/env tarantool

local log = require('log')
local tap = require('tap')
local socket = require('socket')
local cluster = require('cluster')

local test = tap.test('cluster.init')

test:plan(9)

local function check_error(expected_error, fn, ...)
    local ok, err = pcall(fn, ...)
    test:like(err, expected_error, expected_error)
end

check_error('Can not create workdir "/dev/null"',
    cluster.init, {
        workdir = '/dev/null',
        advertise_uri = 'localhost:3301',
    }
)

check_error('Missing port in advertise_uri "localhost"',
    cluster.init, {
        workdir = '.',
        advertise_uri = 'localhost',
    }
)

local _sock = socket('AF_INET', 'SOCK_DGRAM', 'udp')
local ok = _sock:bind('0.0.0.0', 3301)
check_error('Socket bind error',
    cluster.init, {
        workdir = '.',
        advertise_uri = 'localhost:3301',
    }
)
_sock:close()
_sock = nil

check_error('Can not ping myself: ping was not sent',
    cluster.init, {
        workdir = '.',
        advertise_uri = 'invalid-host:3301',
    }
)

check_error([[module 'unknown' not found]],
    cluster.register_role,
    'unknown'
)

package.preload['mymodule'] = function()
    error('My module can not be loaded')
end
check_error('My module can not be loaded',
    cluster.register_role,
    'mymodule'
)

test:ok(pcall(
    cluster.init, {
        workdir = '/tmp',
        advertise_uri = 'localhost:33001',
    }
))

check_error('Cluster is already initialized',
    cluster.init
)

check_error('Cluster is already initialized',
    cluster.register_role
)

os.exit(test:check() and 0 or 1)
