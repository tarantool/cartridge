local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local fio = require('fio')

g.before_each(function()
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

g.before_test('test_raft_leaders_calculation', function()
    g.server:exec(function()
        require('cartridge.failover.raft')
        local vars = require('cartridge.vars').new('cartridge.failover')
        vars:new('instance_uuid', 'a') -- I'm "a"
        vars:new('leader_uuid', 'b') -- my leader is "b"
        vars:new('cache', {
            active_leaders = {--[[ [replicaset_uuid] = leader_uuid ]]},
            is_vclockkeeper = false,
            is_leader = false,
            is_rw = false,
        })

        rawset(_G, 'old_box', box)
        _G.box = {
            info = function()
                return {
                    election = {
                        leader = 1, -- but I'll become leader after trigger call
                    },
                    replication = {
                        [1] = {uuid = 'a'},
                        [2] = {uuid = 'b'},
                    }
                }
            end,
        }
        require('membership').set_payload = function() end
    end)
end)

g.test_raft_leaders_calculation = function()
    local ok, err = pcall(g.server.exec, g.server, function()
        _G.__cartridge_on_election_trigger()
        local vars = require('cartridge.vars').new('cartridge.failover')
        assert(vars.cache.is_leader)
        assert(vars.leader_uuid == 'a')
    end)
    t.assert(ok, err)
end

g.after_test('test_raft_leaders_calculation', function()
    g.server:exec(function()
        rawset(_G, 'box', _G.old_box)
    end)
end)
