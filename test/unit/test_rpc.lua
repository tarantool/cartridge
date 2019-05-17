#!/usr/bin/env tarantool

local tap = require('tap')
local rpc = require('cluster.rpc')
local checks = require('checks')
local topology = require('cluster.topology')

local test = tap.test('cluster.rpc_candidates')
test:plan(13)

-------------------------------------------------------------------------------

local function apply_mocks(topology_draft)
    local members = {}
    local topology_cfg = {
        failover = topology_draft.failover,
        replicasets = {},
        servers = {},
    }

    for _, rpl in ipairs(topology_draft) do
        topology_cfg.replicasets[rpl.uuid] = {
            master = rpl[rpl.leader].uuid,
            roles = {
                [rpl.role] = true,
            }
        }

        for _, srv in ipairs(rpl) do
            local uri = srv.uuid
            topology_cfg.servers[srv.uuid] = {
                uri = uri,
                disabled = srv.disabled or false,
                replicaset_uuid = rpl.uuid,
            }

            if srv.status == nil then
                members[uri] = nil
            else
                members[uri] = {
                    uri = uri,
                    status = srv.status,
                    payload = {
                        uuid = srv.uuid,
                        error = srv.error,
                    }
                }
            end
        end
    end

    topology.set(topology_cfg)
    package.loaded['membership'].get_member = function(uri)
        return members[uri]
    end
end

local function values(array)
    if array == nil then
        return nil
    end

    local ret = {}
    for _, v in ipairs(array) do
        ret[v] = true
    end
    return ret
end

local function test_candidates(test_name, replicasets, opts, expected)
    checks('string', 'table', 'table', 'nil|table')
    apply_mocks(replicasets)

    test:is_deeply(
        values(rpc.get_candidates(unpack(opts))),
        values(expected),
        test_name
    )
end

-------------------------------------------------------------------------------

local draft = {
    [1] = {
        uuid = 'A',
        role = 'target-role',
        leader = 1,
        [1] = {
            uuid = 'a1',
            status = 'alive',
        },
        [2] = {
            uuid = 'a2',
            status = 'alive',
        },
    },
    [2] = {
        uuid = 'B',
        leader = 1,
        role = 'some-other-role',
        [1] = {
            uuid = 'b1',
            status = 'alive',
        },
        [2] = {
            uuid = 'b2',
            status = 'alive',
        },
    }
}

-------------------------------------------------------------------------------
test:diag('all alive')

test_candidates('invalid-role',
    draft, {'invalid-role'},
    nil
)

test_candidates('-leader',
    draft, {'target-role'},
    {'a1', 'a2'}
)

test_candidates('+leader',
    draft, {'target-role', {leader_only = true}},
    {'a1'}
)

-------------------------------------------------------------------------------
draft[1][1].status = 'dead'
test:diag('a1 leader died')

test_candidates('-leader',
    draft, {'target-role'},
    {'a2'}
)
test_candidates('+leader',
    draft, {'target-role', {leader_only = true}},
    nil
)

-------------------------------------------------------------------------------
draft.failover = true
test:diag('failover enabled')

test_candidates('-leader',
    draft, {'target-role'},
    {'a2'}
)

test_candidates('+leader',
    draft, {'target-role', {leader_only = true}},
    {'a2'}
)

-------------------------------------------------------------------------------
draft.failover = false
test:diag('failover disabled')
draft[1][1].status = 'alive'
test:diag('a1 leader died')
draft[2].role = 'target-role'
test:diag('B target-role enabled')

test_candidates('-leader',
    draft, {'target-role'},
    {'a1', 'a2', 'b1', 'b2'}
)

test_candidates('+leader',
    draft, {'target-role', {leader_only = true}},
    {'a1', 'b1'}
)

-------------------------------------------------------------------------------
draft[2][1].error = 'e'
test:diag('b1 has an error')

test_candidates('-leader',
    draft, {'target-role'},
    {'a1', 'a2', 'b2'}
)

test_candidates('+leader',
    draft, {'target-role', {leader_only = true}},
    {'a1'}
)

-------------------------------------------------------------------------------
draft[1][1].disabled = true
test:diag('a1 disabled')

test_candidates('-leader',
    draft, {'target-role'},
    {'a2', 'b2'}
)

test_candidates('+leader',
    draft, {'target-role', {leader_only = true}},
    nil
)

os.exit(test:check() and 0 or 1)
