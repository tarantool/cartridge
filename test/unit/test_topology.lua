#!/usr/bin/env tarantool

local members = {
    ['localhost:3301'] = {
        uri = 'localhost:3301',
        status = 'alive',
        payload = {uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001'},
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
    myself = function(_)
        return members['localhost:3301']
    end,
}

package.loaded['cartridge.pool'] = {
    connect = function()
        return require('net.box').self
    end,
}

_G.vshard = {
    storage = {
        buckets_count = function() end,
    }
}

local tap = require('tap')
local yaml = require('yaml')
local roles = require('cartridge.roles')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')
local ClusterwideConfig = require('cartridge.clusterwide-config')
assert(roles.register_role('cartridge.roles.vshard-storage'))
assert(roles.register_role('cartridge.roles.vshard-router'))
local test = tap.test('topology.config')

local function test_all(test, conf)
test:plan(54)

local vshard_group
if conf.vshard then
    vshard_group = "\n    vshard_group: default\n"
else
    vshard_group = "\n    vshard_group: first\n"
end

local function check_config(result, raw_new, raw_old)
    local topology_new = raw_new and yaml.decode(raw_new) or {}
    local topology_old = raw_old and yaml.decode(raw_old) or {}

    local cfg_new = table.deepcopy(conf)
    local cfg_old = table.deepcopy(conf)
    cfg_new.topology = topology_new
    cfg_old.topology = topology_old

    local ok, err = topology.validate(topology_new, topology_old)
    if ok then
        local vars = require('cartridge.vars').new('cartridge.confapplier')
        vars.cwcfg = ClusterwideConfig.new(cfg_old):lock()
        ok, err = confapplier.validate_config(
            ClusterwideConfig.new(cfg_new):lock()
        )
    end

    test:is(ok or err.err, result, result)
end

-- check_schema
test:diag('validate_schema()')

test:diag('   top-level keys')

check_config('topology_new.auth must be boolean, got string',
[[---
auth:
...]])

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
  '.master must be either string or table, got nil',
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

check_config('topology_new.replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  '.weight must be a number, got string',
[[---
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"vshard-router": true}
    weight: over9000
...]])

check_config('topology_new.replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  '.alias must be a string, got boolean',
[[---
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {}
    alias: false
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

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000001]'..
  '.uri "localhost:3301" collision with another server',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
  aaaaaaaa-aaaa-4000-b000-000000000002:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {}
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
  [[ leader "aaaaaaaa-aaaa-4000-b000-000000000002" doesn't exist]],
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
  [[ leader "aaaaaaaa-aaaa-4000-b000-000000000002" can't be expelled]],
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
  [[ leader "aaaaaaaa-aaaa-4000-b000-000000000001" belongs to another replicaset]],
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
  '.weight must be non-negative, got -1',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"vshard-storage": true}
    weight: -1
...]])

local e
if conf.vshard then
    e = 'At least one vshard-storage (default) must have weight > 0'
else
    e = 'At least one vshard-storage (first) must have weight > 0'
end
check_config(e,
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"vshard-storage": true}
    weight: 0 ]] ..
    vshard_group .. [[
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
    roles: {}
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
    roles: {}
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
    roles: {}
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
    roles: {}
...]])

check_config('Current instance "localhost:3301" is not listed in config',
[[---
servers: {}
...]])

check_config('Current instance "localhost:3301" can not be disabled',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    disabled: true
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {}
...]])

check_config('Current instance "localhost:3301" can not be expelled',
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001: expelled
...]])

test:diag('validate_upgrade()')

check_config('servers[aaaaaaaa-aaaa-4000-b000-000000000002]'..
  ' can not be removed from config',

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
  aaaaaaaa-aaaa-4000-b000-000000000002: expelled
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {}
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
    roles: {}
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

local conf_old_with_weight = [[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
  bbbbbbbb-bbbb-4000-b000-000000000001:
    uri: localhost:3331
    replicaset_uuid: bbbbbbbb-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"vshard-storage": true}
    weight: 1 ]] ..
    vshard_group .. [[
  bbbbbbbb-0000-4000-b000-000000000001:
    master: bbbbbbbb-bbbb-4000-b000-000000000001
    roles: {"vshard-storage": true}
    weight: %s ]] ..
    vshard_group .. [[
...]]

local conf_new_expelled = [[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
  bbbbbbbb-bbbb-4000-b000-000000000001: expelled
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"vshard-storage": true}
    weight: 1 ]] ..
    vshard_group .. [[
...]]

local conf_new_disabled = [[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
  bbbbbbbb-bbbb-4000-b000-000000000001:
    uri: localhost:3331
    replicaset_uuid: bbbbbbbb-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"vshard-storage": true}
    weight: 1 ]] ..
    vshard_group .. [[
  bbbbbbbb-0000-4000-b000-000000000001:
    master: bbbbbbbb-bbbb-4000-b000-000000000001
    roles: {} ]] ..
    vshard_group .. [[
...]]


check_config('replicasets[bbbbbbbb-0000-4000-b000-000000000001]'..
  " is a vshard-storage which can't be removed",
  conf_new_expelled,
  conf_old_with_weight:format(1)
)

check_config('replicasets[bbbbbbbb-0000-4000-b000-000000000001]'..
  " is a vshard-storage which can't be removed",
  conf_new_disabled,
  conf_old_with_weight:format(1)
)

function _G.vshard.storage.buckets_count()
    return 1
end

check_config('replicasets[bbbbbbbb-0000-4000-b000-000000000001]'..
  " rebalancing isn't finished yet",
  conf_new_expelled,
  conf_old_with_weight:format(0)
)

check_config('replicasets[bbbbbbbb-0000-4000-b000-000000000001]'..
  " rebalancing isn't finished yet",
  conf_new_disabled,
  conf_old_with_weight:format(0)
)

function _G.vshard.storage.buckets_count()
    return 0
end

check_config(true,
  conf_new_expelled,
  conf_old_with_weight:format(0)
)

check_config(true,
  conf_new_disabled,
  conf_old_with_weight:format(0)
)

check_config(true,
  conf_new_disabled,
  conf_old_with_weight:format("null")
)

check_config('replicasets[aaaaaaaa-0000-4000-b000-000000000001]'..
  ' can not enable unknown role "unknown"',

[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"unknown": true}
...]],

[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {}
...]])


test:diag('valid configs')

check_config(true,
[[---
auth: false
failover: false
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
auth: false
failover: false
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
    disabled: false
    uri: localhost:3301
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {}
    alias: aliasmaster
...]])

check_config(true,
[[---
auth: true
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

-- unknown role is alowed if it was enabled in previous version
check_config(true,
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    uri: localhost:3301
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"unknown": true}
...]],

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

check_config(true,
[[---
servers:
  aaaaaaaa-aaaa-4000-b000-000000000001:
    replicaset_uuid: aaaaaaaa-0000-4000-b000-000000000001
    uri: localhost:3301
replicasets:
  aaaaaaaa-0000-4000-b000-000000000001:
    master: aaaaaaaa-aaaa-4000-b000-000000000001
    roles: {"vshard-storage": true}
    weight: 2 ]] ..
    vshard_group .. [[
...]])
end

test:plan(2)

test:test('single group', test_all, {
    vshard = {
        bootstrapped = true,
        bucket_count = 1337,
    }
})

test:test('multi-group', test_all, {
    vshard_groups = {
        first = {
            bootstrapped = true,
            bucket_count = 1337,
        },
        second = {
            bootstrapped = true,
            bucket_count = 1337,
        },
    }
})

os.exit(test:check() and 0 or 1)
