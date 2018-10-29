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
    ['localhost:3331'] = {
        uri = 'localhost:3331',
        status = 'alive',
        payload = {},
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

test:plan(37)

local function check_config(result, raw_new, raw_old)
    local cfg_new = raw_new and yaml.decode(raw_new) or {}
    local cfg_old = raw_old and yaml.decode(raw_old) or {}

    local ok, err = topology.validate(cfg_new, cfg_old)
    test:is(ok or err.err, result, result)
end

-- check_schema
test:diag('validate_schema()')

test:diag('   top-level keys')

check_config('topology_new.failover must be boolean, got string',
[[---
failover:
...]])

check_config('topology_new has unknown parameter "unknown"',
[[---
unknown:
...]])

test:diag('   servers keys')

check_config('topology_new.servers must be a table, got string',
[[---
servers:
...]])

check_config('topology_new.servers must have string keys',
[[---
servers:
  - srv1
...]])

check_config('topology_new.servers key "srv2" is not a valid UUID',
[[---
servers:
  srv2:
...]])

test:diag('   servers')

check_config('topology_new.servers[aaaaaaaa-aaaa-4000-b000-000000000001]'..
  ' must be either a table or the string "expelled"',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001: foo
...]])

check_config('topology_new.servers[aaaaaaaa-aaaa-4000-b000-000000000001].uri'..
  ' must be a string, got nil',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
...]])

check_config('topology_new.servers[aaaaaaaa-aaaa-4000-b000-000000000001].replicaset_uuid'..
  ' must be a string, got nil',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
...]])
check_config('topology_new.servers[aaaaaaaa-aaaa-4000-b000-000000000001].replicaset_uuid'..
  ' "set1" is not a valid UUID',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: set1
...]])

check_config('topology_new.servers[aaaaaaaa-aaaa-4000-b000-000000000001].disabled'..
  ' must be true or false',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    disabled: nope
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
...]])

check_config('topology_new.servers[aaaaaaaa-aaaa-4000-b000-000000000001]'..
  ' has unknown parameter "unknown"',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
    unknown: true
...]])

test:diag('   replicasets keys')

check_config('topology_new.replicasets must be a table, got string',
[[---
replicasets:
...]])

check_config('topology_new.replicasets must have string keys',
[[---
replicasets:
  - set1
...]])

check_config('topology_new.replicasets key "set2" is not a valid UUID',
[[---
replicasets:
  set2:
...]])

test:diag('   replicasets')

check_config('topology_new.replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  ' must be a table',
[[---
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001: foo
...]])

check_config('topology_new.replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  '.master must be a string, got nil',
[[---
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    roles: {"vshard-router": true}
...]])

check_config('topology_new.replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  '.roles must be a table, got nil',
[[---
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
...]])

check_config('topology_new.replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  '.roles must have string keys',
[[---
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: ["vshard-router"]
...]])

check_config('topology_new.replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  '.roles["vshard-router"] must be true or false',
[[---
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"vshard-router": 2}
...]])

check_config('topology_new.replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  ' has unknown parameter "unknown"',
[[---
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"vshard-router": true}
    unknown: true
...]])

test:diag('validate_consistency()')

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000001]'..
  '.replicaset_uuid is not configured in replicasets table',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
...]])

check_config('replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  ' has no servers',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001: expelled
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {}
...]])

check_config('replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  '.master does not exist',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000002
    roles: {}
...]])

check_config('replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  '.master is expelled',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
  aaaaaaaa-aaaa-4000-b000-000000000002: expelled
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000002
    roles: {}
...]])

check_config('replicasets[bbbbbbbb-0000-4000-b000-000000000001]'..
  '.master belongs to another replicaset',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
  bbbbbbbb-bbbb-4000-b000-000000000001:
    uri: localhost:3302
    replicaset_uuid: bbbbbbbb-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {}
  bbbbbbbb-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {}
...]])

check_config('replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  ' unknown role "unknown"',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"unknown": true}
...]])


test:diag('validate_availability()')

check_config('Server "localhost:3311" is not in membership',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000010:
    uri: localhost:3311
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000010
replicasets:
  aaaaaaaa-0000-4000-b000-000000000010:
    master: aaaaaaaa-aaaa-4000-b000-000000000010
    roles: {"vshard-storage": true}
...]])

check_config('Server "localhost:3302" is unreachable with status "dead"',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000010:
    uri: localhost:3302
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000010
replicasets:
  aaaaaaaa-0000-4000-b000-000000000010:
    master: aaaaaaaa-aaaa-4000-b000-000000000010
    roles: {"vshard-storage": true}
...]])

check_config('Server "localhost:3303" bootstrapped with different uuid "alien"',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000010:
    uri: localhost:3303
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000010
replicasets:
  aaaaaaaa-0000-4000-b000-000000000010:
    master: aaaaaaaa-aaaa-4000-b000-000000000010
    roles: {"vshard-storage": true}
...]])

check_config('Server "localhost:3304" has error: err',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000010:
    uri: localhost:3304
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000010
replicasets:
  aaaaaaaa-0000-4000-b000-000000000010:
    master: aaaaaaaa-aaaa-4000-b000-000000000010
    roles: {"vshard-storage": true}
...]])


test:diag('validate_upgrade()')

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000001]'..
  ' can not be removed from config',

[[---
servers: {}
...]],

[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001: expelled
...]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000001] has been expelled earlier',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"vshard-storage": true}
...]],

[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001: expelled
...]])

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000001]'..
  '.replicaset_uuid can not be changed',

[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: bbbbbbbb-0000-4000-b000-000000000001
replicasets:
  bbbbbbbb-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {}
...]],

[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
...]])

check_config('replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  ' is a vshard-storage and can not be expelled',

[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001: expelled
...]],

[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"vshard-storage": true}
...]])

check_config('replicasets[aaaaaaaa-0000-4000-b000-000000000001].roles'..
  ' vshard-storage can not be disabled',

[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {}
...]],

[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"vshard-storage": true}
...]])


test:diag('valid configs')

check_config(true,
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
    disabled: false
    uri: localhost:3301
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {}
...]])

check_config(true,
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
    uri: localhost:3301
  aaaaaaaa-aaaa-4000-b000-000000000002:
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
    uri: localhost:3331
  bbbbbbbb-bbbb-4000-b000-000000000001: expelled
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {}
...]])

os.exit(test:check() and 0 or 1)
