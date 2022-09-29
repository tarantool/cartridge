local fio = require('fio')

local helpers = require('test.helper')
local t = require('luatest')
local g = t.group()

g.before_all(function()
    g.server = helpers.Server:new({
        alias = 'master',
        cluster_cookie = 'oreo',
        command = helpers.entrypoint('srv_empty'),
        workdir = fio.tempdir(),
        advertise_port = 13301,
        http_port = 8082,
        net_box_credentials = {user = 'admin', password = ''},
    })
    g.server:start()

    g.server:exec(function()
        rawset(_G, 'apply_mocks', function(topology_draft)
            local yaml = require('yaml')
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
            require('membership').set_payload = function() end
            local conf_vars = require('cartridge.vars').new('cartridge.confapplier')
            conf_vars.replicaset_uuid = 'A'
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
        end)
    end)
end)

g.after_all(function()
    g.server:stop()
    fio.rmtree(g.server.workdir)
end)

local draft = {}
g.before_each(function()
    draft = {
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
end)

local function get_candidates(role, opts)
    return g.server:eval([[
        local rpc = require('cartridge.rpc')
        return rpc.get_candidates(...)
    ]], {role, opts})
end

local function apply_topology(topology_draft)
    g.server:call('_G.apply_mocks', {topology_draft})
end

g.test_all_alive = function()
    apply_topology(draft)

    local candidates = get_candidates('invalid-role')
    t.assert_items_equals(candidates, {})

    local candidates = get_candidates('target-role')
    t.assert_items_equals(candidates, {'a1', 'a2'})

    local candidates = get_candidates('target-role', {leader_only = true})
    t.assert_items_equals(candidates, {'a1'})
end

g.test_failover = function()
    draft[1][1].status = 'dead'
    apply_topology(draft)

    local candidates = get_candidates('target-role', {healthy_only = false})
    t.assert_items_equals(candidates, {'a1', 'a2'})

    local candidates = get_candidates('target-role')
    t.assert_items_equals(candidates, {'a2'})

    local candidates = get_candidates('target-role', {leader_only = true, healthy_only = false})
    t.assert_items_equals(candidates, {'a1'})

    local candidates = get_candidates('target-role', {leader_only = true})
    t.assert_items_equals(candidates, {})

    draft.failover = true
    apply_topology(draft)

    local candidates = get_candidates('target-role', {healthy_only = false})
    t.assert_items_equals(candidates, {'a1', 'a2'})

    local candidates = get_candidates('target-role')
    t.assert_items_equals(candidates, {'a2'})

    local candidates = get_candidates('target-role', {leader_only = true, healthy_only = false})
    t.assert_items_equals(candidates, {'a2'})

    local candidates = get_candidates('target-role', {leader_only = true})
    t.assert_items_equals(candidates, {'a2'})

    draft.failover = false
    draft[1][1].status = 'alive'
    draft[2].role = 'target-role'
    apply_topology(draft)

    local candidates = get_candidates('target-role')
    t.assert_items_equals(candidates, {'a1', 'a2', 'b1', 'b2'})

    local candidates = get_candidates('target-role', {leader_only = true})
    t.assert_items_equals(candidates, {'a1', 'b1'})
end

g.test_error = function()
    draft[2].role = 'target-role'
    draft[2][1].state = 'BootError'
    apply_topology(draft)

    local candidates = get_candidates('target-role', {healthy_only = false})
    t.assert_items_equals(candidates, {'a1', 'a2', 'b1', 'b2'})

    local candidates = get_candidates('target-role')
    t.assert_items_equals(candidates, {'a1', 'a2', 'b2'})

    local candidates = get_candidates('target-role', {leader_only = true, healthy_only = false})
    t.assert_items_equals(candidates, {'a1', 'b1'})

    local candidates = get_candidates('target-role', {leader_only = true})
    t.assert_items_equals(candidates, {'a1'})
end

g.test_disabled = function()
    draft[2].role = 'target-role'
    draft[2][1].state = 'BootError'
    draft[1][1].disabled = true
    apply_topology(draft)

    local candidates = get_candidates('target-role', {healthy_only = false})
    t.assert_items_equals(candidates, {'a2', 'b1', 'b2'})

    local candidates = get_candidates('target-role')
    t.assert_items_equals(candidates, {'a2', 'b2'})

    local candidates = get_candidates('target-role', {leader_only = true, healthy_only = false})
    t.assert_items_equals(candidates, {'b1'})

    local candidates = get_candidates('target-role', {leader_only = true})
    t.assert_items_equals(candidates, {})
end
