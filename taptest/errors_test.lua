#!/usr/bin/env tarantool

local log = require('log')
local tap = require('tap')
local socket = require('socket')
local cluster = require('cluster')

local test = tap.test('cluster.cfg')

test:plan(8)

local function check_error(expected_error, fn, ...)
    local ok, err = fn(...)
    test:diag('%s', err)
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
        workdir = '.',
        advertise_uri = 'localhost',
    }
)

local _sock = socket('AF_INET', 'SOCK_DGRAM', 'udp')
local ok = _sock:bind('0.0.0.0', 3301)
check_error('Socket bind error',
    cluster.cfg, {
        workdir = '.',
        advertise_uri = 'localhost:3301',
    }
)
_sock:close()
_sock = nil

check_error('Can not ping myself: ping was not sent',
    cluster.cfg, {
        workdir = '.',
        advertise_uri = 'invalid-host:3301',
    }
)

check_error([[module 'unknown' not found]],
    cluster.cfg, {
        workdir = '.',
        advertise_uri = 'localhost:9',
        roles = {'unknown'},
    }
)

package.preload['mymodule'] = function()
    error('My module can not be loaded')
end
check_error('My module can not be loaded',
    cluster.cfg, {
        workdir = '.',
        advertise_uri = 'localhost:9',
        roles = {'mymodule'},
    }
)

test:ok(
    cluster.cfg({
        workdir = '/tmp',
        advertise_uri = 'localhost:33001',
    })
)

check_error('Cluster is already initialized',
    cluster.cfg, {
        workdir = '/tmp',
        advertise_uri = 'localhost:33001',
        roles = {'mymodule'},
    }
)

os.exit(test:check() and 0 or 1)
