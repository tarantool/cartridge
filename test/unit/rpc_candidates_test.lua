#!/usr/bin/env tarantool

local fio = require('fio')
local log = require('log')
local rpc = require('cartridge.rpc')
local checks = require('checks')
local yaml = require('yaml')

local helpers = require('cartridge.test-helpers')
local t = require('luatest')
local g = t.group()

function g.setup()
    local root = fio.dirname(fio.abspath(package.search('cartridge')))
    local server_command = fio.pathjoin(root, 'test', 'unit', 'srv_empty.lua')

    g.server = t.Server:new({
        command = server_command,
        workdir = fio.tempdir(),
        net_box_port = 13301,
        http_port = 8082,
        net_box_credentials = {user = 'admin', password = ''},
    })

    g.server:start()
    helpers.retrying({}, t.Server.connect_net_box, g.server)
end

function g.teardown()
    g.server:stop()
    fio.rmtree(g.server.workdir)
end

local M = {}
local function test_remotely(fn_name, fn)
    M[fn_name] = fn
    g[fn_name] = function()
        g.server.net_box:eval([[
            local test = require('test.unit.rpc_candidates_test')
            test[...]()
        ]], {fn_name})
    end
end

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
                        state = srv.state,
                    }
                }
            end
        end
    end

    local vars = require('cartridge.vars').new('cartridge.confapplier')
    local ClusterwideConfig = require('cartridge.clusterwide-config')
    vars.clusterwide_config = ClusterwideConfig.new({
        ['topology.yml'] = yaml.encode(topology_cfg)
    }):lock()
    local failover = require('cartridge.failover')
    _G.box = {
        cfg = function() end,
        error = box.error,
        info = {
            cluster = {uuid = 'A'},
            uuid = 'a1',
        },
    }
    failover.cfg(vars.clusterwide_config)

    package.loaded['membership'].get_member = function(uri)
        return members[uri]
    end
end

local function values(array)
    if array == nil then
        return nil
    end

    local ret = {}
    for _, v in pairs(array) do
        ret[v] = true
    end
    return ret
end

local function test_candidates(test_name, replicasets, opts, expected)
    checks('string', 'table', 'table', 'nil|table')
    apply_mocks(replicasets)

    t.assert_equals(
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
            state = 'RolesConfigured',
        },
        [2] = {
            uuid = 'a2',
            status = 'alive',
            state = 'RolesConfigured',
        },
    },
    [2] = {
        uuid = 'B',
        leader = 1,
        role = 'some-other-role',
        [1] = {
            uuid = 'b1',
            status = 'alive',
            state = 'RolesConfigured',
        },
        [2] = {
            uuid = 'b2',
            status = 'alive',
            state = 'RolesConfigured',
        },
    }
}

test_remotely('test_all', function()
-------------------------------------------------------------------------------
log.info('all alive')

test_candidates('invalid-role',
    draft, {'invalid-role'},
    {}
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
log.info('a1 leader died')

test_candidates('-leader -healthy',
    draft, {'target-role', {healthy_only = false}},
    {'a1', 'a2'}
)

test_candidates('-leader +healthy',
    draft, {'target-role'},
    {'a2'}
)

test_candidates('+leader -healthy',
    draft, {'target-role', {leader_only = true, healthy_only = false}},
    {'a1'}
)

test_candidates('+leader +healthy',
    draft, {'target-role', {leader_only = true}},
    {}
)

-------------------------------------------------------------------------------
draft.failover = true
log.info('failover enabled')

test_candidates('-leader -healthy',
    draft, {'target-role', {healthy_only = false}},
    {'a1', 'a2'}
)

test_candidates('-leader +healthy',
    draft, {'target-role'},
    {'a2'}
)

test_candidates('+leader -healthy',
    draft, {'target-role', {leader_only = true, healthy_only = false}},
    {'a2'}
)

test_candidates('+leader +healthy',
    draft, {'target-role', {leader_only = true}},
    {'a2'}
)

-------------------------------------------------------------------------------
draft.failover = false
log.info('failover disabled')
draft[1][1].status = 'alive'
log.info('a1 leader restored')
draft[2].role = 'target-role'
log.info('B target-role enabled')

test_candidates('-leader',
    draft, {'target-role'},
    {'a1', 'a2', 'b1', 'b2'}
)

test_candidates('+leader',
    draft, {'target-role', {leader_only = true}},
    {'a1', 'b1'}
)

-------------------------------------------------------------------------------
draft[2][1].state = 'BootError'
log.info('b1 has an error')

test_candidates('-leader -healthy',
    draft, {'target-role', {healthy_only = false}},
    {'a1', 'a2', 'b2', 'b1'}
)

test_candidates('-leader +healthy',
    draft, {'target-role'},
    {'a1', 'a2', 'b2'}
)

test_candidates('+leader -healthy',
    draft, {'target-role', {leader_only = true, healthy_only = false}},
    {'a1', 'b1'}
)

test_candidates('+leader +healthy',
    draft, {'target-role', {leader_only = true}},
    {'a1'}
)

-------------------------------------------------------------------------------
draft[1][1].disabled = true
log.info('a1 disabled')

test_candidates('-leader -healthy',
    draft, {'target-role', {healthy_only = false}},
    {'a2', 'b2', 'b1'}
)

test_candidates('-leader +healthy',
    draft, {'target-role'},
    {'a2', 'b2'}
)

test_candidates('+leader -healthy',
    draft, {'target-role', {leader_only = true, healthy_only = false}},
    {'b1'}
)

test_candidates('+leader +healthy',
    draft, {'target-role', {leader_only = true}},
    {}
)

end)

return M
