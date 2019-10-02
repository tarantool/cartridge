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
    myself = function()
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
local vshard_utils = require('cartridge.vshard-utils')
local test = tap.test('vshard.config')

test:plan(21)

local function check_config(result, raw_new, raw_old)
    local conf_new = raw_new and yaml.decode(raw_new) or {}
    local conf_old = raw_old and yaml.decode(raw_old) or {}

    local ok, err = vshard_utils.validate_config(conf_new, conf_old)
    test:is(ok or err.err, result, result)
end

-- check_schema
test:diag('validate_vshard_group()')

test:diag('   top-level keys')

check_config('section vshard_groups must be a table',
[[---
vshard_groups.yml:
...]])

check_config('section vshard_groups must have string keys',
[[---
vshard_groups.yml:
  - default
...]])

check_config('section vshard_groups["global"] must be a table',
[[---
vshard_groups.yml:
  global: false
...]])

check_config('vshard_groups["global"].bucket_count must be a number',
[[---
vshard_groups.yml:
  global: {}
...]])

check_config('vshard_groups["global"].bucket_count must be positive',
[[---
vshard_groups.yml:
  global:
    bucket_count: 0
...]])

check_config([[vshard_groups["global"].bucket_count can't be changed]],
[[---
topology.yml: {}
vshard_groups.yml:
  global:
    bucket_count: 100
    bootstrapped: false
...]],
[[---
topology.yml: {}
vshard_groups.yml:
  global:
    bucket_count: 200
    bootstrapped: false
...]])

check_config('vshard_groups["global"].rebalancer_max_receiving must be a number',
[[---
vshard_groups.yml:
  global:
    bucket_count: 200
    bootstrapped: false
    rebalancer_max_receiving: value
...]])

check_config('vshard_groups["global"].rebalancer_max_receiving must be positive',
[[---
vshard_groups.yml:
  global:
    bucket_count: 200
    bootstrapped: false
    rebalancer_max_receiving: 0
...]])

check_config('vshard_groups["global"].collect_lua_garbage must be a boolean',
[[---
vshard_groups.yml:
  global:
    bucket_count: 200
    bootstrapped: false
    collect_lua_garbage: value
...]])

check_config('vshard_groups["global"].sync_timeout must be a number',
[[---
vshard_groups.yml:
  global:
    bucket_count: 200
    bootstrapped: false
    sync_timeout: value
...]])

check_config('vshard_groups["global"].sync_timeout must be non-negative',
[[---
vshard_groups.yml:
  global:
    bucket_count: 200
    bootstrapped: false
    sync_timeout: -1
...]])

check_config('vshard_groups["global"].collect_bucket_garbage_interval must be a number',
[[---
vshard_groups.yml:
  global:
    bucket_count: 200
    bootstrapped: false
    collect_bucket_garbage_interval: value
...]])

check_config('vshard_groups["global"].collect_bucket_garbage_interval must be positive',
[[---
vshard_groups.yml:
  global:
    bucket_count: 200
    bootstrapped: false
    collect_bucket_garbage_interval: 0
...]])

check_config('vshard_groups["global"].rebalancer_disbalance_threshold must be a number',
[[---
vshard_groups.yml:
  global:
    bucket_count: 200
    bootstrapped: false
    rebalancer_disbalance_threshold: value
...]])

check_config('vshard_groups["global"].rebalancer_disbalance_threshold must be non-negative',
[[---
vshard_groups.yml:
  global:
    bucket_count: 200
    bootstrapped: false
    rebalancer_disbalance_threshold: -1
...]])

check_config('vshard_groups["global"].bootstrapped must be true or false',
[[---
vshard_groups.yml:
  global:
    bucket_count: 1
    bootstrapped: nope
...]])

check_config('section vshard_groups["global"] has unknown parameter "unknown"',
[[---
vshard_groups.yml:
  global:
    bucket_count: 1
    bootstrapped: false
    unknown:
...]])

test:diag('   group assignment')

check_config("replicasets[aaaaaaaa-0000-4000-b000-000000000001]" ..
    [[ can't be added to vshard_group "some", cluster doesn't have any]],
[[---
topology.yml:
  replicasets:
    aaaaaaaa-0000-4000-b000-000000000001:
      master: aaaaaaaa-aaaa-4000-b000-000000000001
      vshard_group: some
      roles: {}
vshard.yml:
  bucket_count: 1
  bootstrapped: false
...]])

check_config("replicasets[aaaaaaaa-0000-4000-b000-000000000001]" ..
    " is a vshard-storage and must be assigned to a particular group",
[[---
topology.yml:
  replicasets:
    aaaaaaaa-0000-4000-b000-000000000001:
      master: aaaaaaaa-aaaa-4000-b000-000000000001
      roles: {"vshard-storage": true}
vshard_groups.yml:
  global:
    bucket_count: 1
    bootstrapped: false
...]])

check_config("replicasets[aaaaaaaa-0000-4000-b000-000000000001]" ..
    [[.vshard_group "unknown" doesn't exist]],
[[---
topology.yml:
  replicasets:
    aaaaaaaa-0000-4000-b000-000000000001:
      master: aaaaaaaa-aaaa-4000-b000-000000000001
      vshard_group: unknown
      roles: {"vshard-storage": true}
vshard_groups.yml:
  global:
    bucket_count: 1
    bootstrapped: false
...]])

check_config("replicasets[aaaaaaaa-0000-4000-b000-000000000001]" ..
    [[.vshard_group can't be modified]],
[[---
topology.yml:
  replicasets:
    aaaaaaaa-0000-4000-b000-000000000001:
      master: aaaaaaaa-aaaa-4000-b000-000000000001
      vshard_group: one
      roles: {}
vshard_groups.yml:
  one:
    bucket_count: 1
    bootstrapped: false
  two:
    bucket_count: 1
    bootstrapped: false
...]],
[[---
topology.yml:
  replicasets:
    aaaaaaaa-0000-4000-b000-000000000001:
      master: aaaaaaaa-aaaa-4000-b000-000000000001
      vshard_group: two
      roles: {}
vshard_groups.yml:
  one:
    bucket_count: 1
    bootstrapped: false
  two:
    bucket_count: 1
    bootstrapped: false
...]])

os.exit(test:check() and 0 or 1)
