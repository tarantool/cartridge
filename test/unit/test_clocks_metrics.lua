#!/usr/bin/env tarantool

-- some constants to test
local MIN_CLOCK_DELTA = -50
local MAX_CLOCK_DELTA = 1000

local members = {
    ['localhost:3301'] = {
        uri = 'localhost:3301',
        status = 'alive',
        payload = {uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001'},
        timestamp = 12345678,
    },
    ['localhost:3302'] = {
        uri = 'localhost:3302',
        status = 'alive',
        payload = {uuid = 'aaaaaaaa-aaaa-4000-b000-000000000002'},
        timestamp = 12345678,
        clock_delta = nil,
    },
    ['localhost:3303'] = {
        uri = 'localhost:3303',
        status = 'alive',
        payload = {uuid = 'aaaaaaaa-aaaa-4000-b000-000000000003'},
        timestamp = 12345678,
        clock_delta = 0,
    },
    ['localhost:3304'] = {
        uri = 'localhost:3304',
        status = 'alive',
        payload = {uuid = 'aaaaaaaa-aaaa-4000-b000-000000000004'},
        timestamp = 12345678,
        clock_delta = MIN_CLOCK_DELTA,
    },
    ['localhost:3305'] = {
        uri = 'localhost:3305',
        status = 'alive',
        payload = {uuid = 'aaaaaaaa-aaaa-4000-b000-000000000005'},
        timestamp = 12345678,
        clock_delta = MAX_CLOCK_DELTA,
    },
}

local topology_cfg = {
    replicasets = {
        ['bbbbbbbb-bbbb-4000-b000-000000000001'] = {
            master = 'aaaaaaaa-aaaa-4000-b000-000000000001',
            roles = { 'vshard_storage' }
        }
    },
    servers = {
        ['aaaaaaaa-aaaa-4000-b000-000000000001'] = {
            uri = 'localhost:3301',
            replicaset_uuid = 'bbbbbbbb-bbbb-4000-b000-000000000001'
        },
        ['aaaaaaaa-aaaa-4000-b000-000000000002'] = {
            uri = 'localhost:3302',
            replicaset_uuid = 'bbbbbbbb-bbbb-4000-b000-000000000001'
        },
        ['aaaaaaaa-aaaa-4000-b000-000000000003'] = {
            uri = 'localhost:3303',
            replicaset_uuid = 'bbbbbbbb-bbbb-4000-b000-000000000001'
        },
        ['aaaaaaaa-aaaa-4000-b000-000000000004'] = {
            uri = 'localhost:3304',
            replicaset_uuid = 'bbbbbbbb-bbbb-4000-b000-000000000001'
        },
        ['aaaaaaaa-aaaa-4000-b000-000000000005'] = {
            uri = 'localhost:3305',
            replicaset_uuid = 'bbbbbbbb-bbbb-4000-b000-000000000001'
        },
    },
}

package.loaded['membership'] = {
    get_member = function(uri)
        return members[uri]
    end,
    myself = function(_)
        return members['localhost:3301']
    end,
    members = function()
        return members
    end,
}

package.loaded['cartridge.confapplier'] = {
    get_readonly = function()
        return topology_cfg
    end,
    get_known_roles = function()
        return { 'vshard-storage' }
    end,
    get_enabled_roles = function()
      return { 'vshard-storage' }
    end,
}

local tap = require('tap')
local test = tap.test('clocks.metrics')
local admin = require('cartridge.admin')

test:plan(7)

local servers = admin.get_servers()

for _, server in ipairs(servers) do
    test:ok(server.clocks ~= nil, 'Information present for every server')
end

local clock_delta = servers[1].clocks
test:is(clock_delta.min_delta, MIN_CLOCK_DELTA, 'Check calculated min value')
test:is(clock_delta.max_delta, MAX_CLOCK_DELTA, 'Check calculated max value')

os.exit(test:check() and 0 or 1)
