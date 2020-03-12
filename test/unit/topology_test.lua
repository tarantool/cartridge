#!/usr/bin/env tarantool

local fio = require('fio')
local yaml = require('yaml')
local roles = require('cartridge.roles')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')
local ClusterwideConfig = require('cartridge.clusterwide-config')
local membership = require('membership')
local pool = require('cartridge.pool')

local t = require('luatest')
local g = t.group()

local members = {
    ['localhost:3301'] = {
        uri = 'localhost:3301',
        status = 'alive',
        payload = { uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001' },
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

local conf
local vshard_group

local function check_config(result, raw_new, raw_old)
    local topology_new = raw_new and yaml.decode(raw_new) or {}
    local topology_old = raw_old and yaml.decode(raw_old) or {}

    local cfg_new = table.deepcopy(conf)
    local cfg_old = table.deepcopy(conf)
    cfg_new['topology.yml'] = yaml.encode(topology_new)
    cfg_old['topology.yml'] = yaml.encode(topology_old)

    local ok, err = topology.validate(topology_new, topology_old)
    if ok then
        local vars = require('cartridge.vars').new('cartridge.confapplier')
        vars.clusterwide_config = ClusterwideConfig.new(cfg_old):lock()
        ok, err = confapplier.validate_config(
            ClusterwideConfig.new(cfg_new):lock()
        )
    end

    t.assert_equals(ok or err.err, result, 'Unexpected result')
end

function g.teardown()
    membership.get_member = g.membership_backup.get_member
    membership.subscribe = g.membership_backup.subscribe
    membership.myself = g.membership_backup.myself

    pool.connect = g.pool_backup.connect
end

function g.mock_package()
    g.membership_backup.get_member = membership.get_member
    g.membership_backup.subscribe = membership.subscribe
    g.membership_backup.myself = membership.myself

    g.pool_backup.connect = pool.connect

    package.loaded['membership'].get_member = function(uri)
        return members[uri]
    end

    package.loaded['membership'].myself = function(_)
        return members['localhost:3301']
    end

    package.loaded['membership'].subscribe = function()
        return require('fiber').cond()
    end

    package.loaded['cartridge.pool'].connect = function()
        return require('net.box').self
    end
end

function g.before_all()
    assert(roles.register_role('cartridge.roles.vshard-storage'))
    assert(roles.register_role('cartridge.roles.vshard-router'))

    _G.vshard = {
        storage = {
            buckets_count = function() end,
        }
    }

    g.membership_backup = {}
    g.pool_backup = {}

    g.tempdir = fio.tempdir()
end

function g.after_all()
    fio.rmtree(g.tempdir)
end

local function test_all()
    if conf['vshard.yml'] then
        vshard_group = "\n    vshard_group: default\n"
    else
        vshard_group = "\n    vshard_group: first\n"
    end

    -- scheme
    check_config('topology_new.auth must be boolean, got string',
[[---
auth:
...]])

    check_config('topology_new.failover must be a table, got string',
[[---
failover:
...]])

    check_config('topology_new.failover.mode must be string, got nil',
[[---
failover: {}
...]])

    check_config('topology_new.failover.mode must be string, got number',
[[---
failover:
  mode: 7
...]])

    check_config('topology_new.failover.mode "one" is unknown',
[[---
failover:
  mode: one
...]])

    check_config('topology_new.failover missing coordinator_uri for mode "stateful"',
[[---
failover:
  mode: stateful
  coordinator_uri: null
...]])

    check_config('topology_new.failover.coordinator_uri must be a string, got boolean',
[[---
failover:
  mode: disabled
  coordinator_uri: false
...]])

    check_config('topology_new.failover.coordinator_uri invalid URI ":-0"',
[[---
failover:
  mode: stateful
  coordinator_uri: ":-0"
...]])

    check_config('topology_new.failover.coordinator_uri invalid URI "localhost" (missing port)',
[[---
failover:
  mode: stateful
  coordinator_uri: "localhost"
...]])

    check_config('topology_new.failover has unknown parameter "enabled"',
[[---
failover:
  mode: eventual
  enabled: true
...]])

    check_config('topology_new.failover has unknown parameter "unknown"',
[[---
failover:
  mode: eventual
  unknown: yes
...]])

    check_config('topology_new has unknown parameter "unknown"',
[[---
unknown:
...]])

    -- servers keys
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

    -- servers
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

    -- replicasets keys
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

    -- replicasets
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

    -- consistency
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

    check_config('replicasets[aaaaaaaa-0000-4000-b000-000000000001]' ..
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

    check_config('replicasets[bbbbbbbb-0000-4000-b000-000000000001]' ..
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

    check_config('replicasets[aaaaaaaa-0000-4000-b000-000000000001]' ..
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
    if conf['vshard.yml'] then
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

    -- availability
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

    -- upgrade
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

    _G.vshard.storage.buckets_count = function()
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

    _G.vshard.storage.buckets_count = function()
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

    -- allvalid configs
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
failover:
  mode: eventual
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
failover:
  mode: stateful
  coordinator_uri: kingdom.com:4401
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

function g.test_single_group()
    g.mock_package()
    conf = {
        ['vshard.yml'] = yaml.encode({
            bootstrapped = true,
            bucket_count = 1337,
        })
    }
    test_all()
end

function g.test_multi_group()
    g.mock_package()
    conf = {
        ['vshard_groups.yml'] = yaml.encode({
            first = {
                bootstrapped = true,
                bucket_count = 1337,
            },
            second = {
                bootstrapped = true,
                bucket_count = 1337,
            },
        })
    }
    test_all()
end
