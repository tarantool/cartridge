#!/usr/bin/env tarantool

local log = require('log')

local members = {
    ['localhost:3301'] = {
        uri = 'localhost:3301',
        status = 'alive',
        payload = {},
    },
    ['localhost:3302'] = {
        uri = 'localhost:3302',
        status = 'dead',
        payload = {},
    },
    ['localhost:3303'] = {
        uri = 'localhost:3303',
        status = 'alive',
        payload = { uuid = 'alien' },
    },
    ['localhost:3304'] = {
        uri = 'localhost:3304',
        status = 'alive',
        payload = { ['error'] = 'err' },
    },
}
package.loaded['membership'] = {
    get_member = function(uri)
        return members[uri]
    end,
}

local tap = require('tap')
local yaml = require('yaml')
local topology = require('cluster.topology')
local test = tap.test('topology.config')

test:plan(18)

local function check_config(result, raw_new, raw_old)
    local cfg_new = raw_new and yaml.decode(raw_new).servers or {}
    local cfg_old = raw_old and yaml.decode(raw_old).servers or {}

    local ok, err = topology.validate(cfg_new, cfg_old)
    test:is(ok or err.err, result, result)
end

check_config('servers must have string keys',
[[servers:
  - srv1
]])

check_config('servers key "srv2" is not a valid UUID',
[[servers:
  srv2:
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000001] must be either a table or the string "expelled"',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000002].uri must be a string, got nil',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000002: {}
]])

check_config(true,
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000003:
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000003
    uri: localhost:3301
    roles: {}
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000004].roles[1] unknown role "unknown"',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000004:
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000004
    uri: localhost:3301
    roles: ['unknown']
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000005].replicaset_uuid is not a valid UUID',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000005:
    uri: localhost:3301
    roles: ['vshard-router']
    replicaset_uuid: aaaaaaaa-0000-4000
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000006] has unknown parameter "unknown"',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000006:
    uri: localhost:3301
    roles: ['vshard-router']
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000006
    unknown: true
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000007] can not be removed from config',
[[servers: {}]],
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000007: expelled
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000008] is already expelled',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000008:
    uri: localhost:3301
    roles: ['vshard-storage']
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000000
]],
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000008: expelled
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000009].replicaset_uuid can not be changed',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000009:
    uri: localhost:3301
    roles: ['vshard-storage']
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000000
]],
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000009:
    uri: localhost:3301
    roles: ['vshard-storage']
    replicaset_uuid: aaaaaaaa-1111-4000-b000-111111111111
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000010].uri "localhost:3311" is not in membership',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000010:
    uri: localhost:3311
    roles: ['vshard-storage']
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000000
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000011].uri "localhost:3302" is unreachable with status "dead"',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000011:
    uri: localhost:3302
    roles: ['vshard-storage']
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000000
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000012].uri "localhost:3303" bootstrapped with different uuid "alien"',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000012:
    uri: localhost:3303
    roles: ['vshard-storage']
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000000
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000013].uri "localhost:3304" has error: err',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000013:
    uri: localhost:3304
    roles: ['vshard-storage']
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000000
]])

check_config('servers[aaaaaaaa-bbbb-4000-b000-000000000014].roles differ from '
  .. 'servers[aaaaaaaa-aaaa-4000-b000-000000000014].roles within same replicaset',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000014:
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000000
    uri: localhost:3301
    roles: ['vshard-storage']
  aaaaaaaa-bbbb-4000-b000-000000000014:
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000000
    uri: localhost:3301
    roles: ['vshard-router']
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000015].roles has duplicate roles "vshard-storage"',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000015:
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000000
    uri: localhost:3301
    roles: ['vshard-storage', 'vshard-storage']
]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000016] is the last storage in replicaset and can not be expelled',
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000016: expelled
]],
[[servers:
  aaaaaaaa-aaaa-4000-b000-000000000016:
    uri: localhost:3301
    roles: ['vshard-storage']
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000000
]])

os.exit(test:check() and 0 or 1)
