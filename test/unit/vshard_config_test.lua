#!/usr/bin/env tarantool

local fio = require('fio')
local log = require('log')
local yaml = require('yaml')
local vshard_utils = require('cartridge.vshard-utils')

local helpers = require('test.helper')

local t = require('luatest')
local g = t.group()

g.before_each(function ()
    g.server = t.Server:new({
        command = helpers.entrypoint('srv_empty'),
        workdir = fio.tempdir(),
        net_box_port = 13301,
        net_box_credentials = {user = 'admin', password = ''},
    })

    g.server:start()
    helpers.retrying({}, t.Server.connect_net_box, g.server)
end)

g.after_each(function()
    g.server:stop()
    fio.rmtree(g.server.workdir)
end)

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

local M = {}
local function test_remotely(fn_name, fn)
    M[fn_name] = function()

package.loaded['membership'] = {
    get_member = function(uri)
        return members[uri]
    end,
    myself = function()
        return members['localhost:3301']
    end,
    subscribe = function()
        return require('fiber').cond()
    end,
}

package.loaded['cartridge.pool'] = {
    connect = function()
        return require('net.box').self
    end,
}

        return fn()
    end
    g[fn_name] = function()
        g.server:eval([[
            local test = require('test.unit.vshard_config_test')
            test[...]()
        ]], {fn_name})
    end
end

local function check_config(result, raw_new, raw_old)
    local conf_new = raw_new and yaml.decode(raw_new) or {}
    local conf_old = raw_old and yaml.decode(raw_old) or {}

    local ok, err = vshard_utils.validate_config(conf_new, conf_old)
    t.assert_equals(ok or err.err, result, result)
end

test_remotely('test_all', function()

-- check_schema
log.info('validate_vshard_group()')

log.info('top-level keys')
check_config('section vshard_groups must be a table',
[[---
vshard_groups:
...]])

check_config('section vshard_groups must have string keys',
[[---
vshard_groups:
  - default
...]])

check_config('section vshard_groups["global"] must be a table',
[[---
vshard_groups:
  global: false
...]])

check_config('vshard_groups["global"].bucket_count must be a number',
[[---
vshard_groups:
  global: {}
...]])

check_config('vshard_groups["global"].bucket_count must be positive',
[[---
vshard_groups:
  global:
    bucket_count: 0
...]])

check_config([[vshard_groups["global"].bucket_count can't be changed]],
[[---
topology: {}
vshard_groups:
  global:
    bucket_count: 100
    bootstrapped: false
...]],
[[---
topology: {}
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
...]])

check_config('vshard_groups["global"].rebalancer_max_receiving must be a number',
[[---
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
    rebalancer_max_receiving: value
...]])

check_config('vshard_groups["global"].rebalancer_max_receiving must be positive',
[[---
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
    rebalancer_max_receiving: 0
...]])

check_config('vshard_groups["global"].rebalancer_max_sending must be positive',
[[---
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
    rebalancer_max_sending: 0
...]])

check_config('vshard_groups["global"].connection_fetch_schema must be a boolean',
[[---
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
    connection_fetch_schema: "no"
...]])

check_config('vshard_groups["global"].collect_lua_garbage must be a boolean',
[[---
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
    collect_lua_garbage: value
...]])

check_config('vshard_groups["global"].sync_timeout must be a number',
[[---
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
    sync_timeout: value
...]])

check_config('vshard_groups["global"].sync_timeout must be non-negative',
[[---
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
    sync_timeout: -1
...]])

check_config('vshard_groups["global"].collect_bucket_garbage_interval must be a number',
[[---
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
    collect_bucket_garbage_interval: value
...]])

check_config('vshard_groups["global"].collect_bucket_garbage_interval must be positive',
[[---
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
    collect_bucket_garbage_interval: 0
...]])

check_config('vshard_groups["global"].rebalancer_disbalance_threshold must be a number',
[[---
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
    rebalancer_disbalance_threshold: value
...]])

check_config('vshard_groups["global"].rebalancer_disbalance_threshold must be non-negative',
[[---
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
    rebalancer_disbalance_threshold: -1
...]])

check_config('vshard_groups["global"].sched_ref_quota must be non-negative',
[[---
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
    sched_ref_quota: -1
...]])

check_config('vshard_groups["global"].sched_move_quota must be non-negative',
[[---
vshard_groups:
  global:
    bucket_count: 200
    bootstrapped: false
    sched_move_quota: -1
...]])

check_config('vshard_groups["global"].bootstrapped must be true or false',
[[---
vshard_groups:
  global:
    bucket_count: 1
    bootstrapped: nope
...]])

log.info('group assignment')
check_config("replicasets[aaaaaaaa-0000-4000-b000-000000000001]" ..
    [[ can't be added to vshard_group "some", cluster doesn't have any]],
[[---
topology:
  replicasets:
    aaaaaaaa-0000-4000-b000-000000000001:
      master: aaaaaaaa-aaaa-4000-b000-000000000001
      vshard_group: some
      roles: {}
vshard:
  bucket_count: 1
  bootstrapped: false
...]])

check_config("replicasets[aaaaaaaa-0000-4000-b000-000000000001]" ..
    " is a vshard-storage and must be assigned to a particular group",
[[---
topology:
  replicasets:
    aaaaaaaa-0000-4000-b000-000000000001:
      master: aaaaaaaa-aaaa-4000-b000-000000000001
      roles: {"vshard-storage": true}
vshard_groups:
  global:
    bucket_count: 1
    bootstrapped: false
...]])

check_config("replicasets[aaaaaaaa-0000-4000-b000-000000000001]" ..
    [[.vshard_group "unknown" doesn't exist]],
[[---
topology:
  replicasets:
    aaaaaaaa-0000-4000-b000-000000000001:
      master: aaaaaaaa-aaaa-4000-b000-000000000001
      vshard_group: unknown
      roles: {"vshard-storage": true}
vshard_groups:
  global:
    bucket_count: 1
    bootstrapped: false
...]])

check_config("replicasets[aaaaaaaa-0000-4000-b000-000000000001]" ..
    [[.vshard_group can't be modified]],
[[---
topology:
  replicasets:
    aaaaaaaa-0000-4000-b000-000000000001:
      master: aaaaaaaa-aaaa-4000-b000-000000000001
      vshard_group: one
      roles: {}
vshard_groups:
  one:
    bucket_count: 1
    bootstrapped: false
  two:
    bucket_count: 1
    bootstrapped: false
...]],
[[---
topology:
  replicasets:
    aaaaaaaa-0000-4000-b000-000000000001:
      master: aaaaaaaa-aaaa-4000-b000-000000000001
      vshard_group: two
      roles: {}
vshard_groups:
  one:
    bucket_count: 1
    bootstrapped: false
  two:
    bucket_count: 1
    bootstrapped: false
...]])

end)

return M
