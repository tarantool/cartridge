local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local fio = require('fio')

g.before_all(function()
    g.server = t.Server:new({
        command = helpers.entrypoint('srv_empty'),
        workdir = fio.tempdir(),
        net_box_port = 13300,
        net_box_credentials = {user = 'admin', password = ''},
    })

    g.server:start()
    helpers.retrying({}, t.Server.connect_net_box, g.server)
end)

g.after_all(function()
    g.server:stop()
    fio.rmtree(g.server.workdir)
end)

----------------------------
-- We work on a single instance and pretend that:
-- "a" - current instance
-- "b" - another instance
-- * current known leader is @current_leader
-- * next leader we receive from raft is @next_leader
-- We expect the next state transition:
-- if @next_leader != nil then expected_leader = @next_leader
-- else expected_leader = @current_leader
----------------------------
local test_cases = {
    ----------------------------
    -- instance is not a leader
    ----------------------------
    leader_changed_to_current = {
        current_leader = 'b',
        next_leader = 'a',
        expected_leader = 'a',
    },
    leader_stays_the_same = {
        current_leader = 'b',
        next_leader = 'b',
        expected_leader = 'b',
    },
    empty_leader_no_changes_replica = {
        current_leader = 'b',
        next_leader = box.NULL,
        expected_leader = 'b',
    },
    ----------------------------
    -- no current leader
    ----------------------------
    new_leader_no_changes = {
        current_leader = box.NULL,
        next_leader = 'a',
        expected_leader = 'a',
    },
    no_leader_no_changes = {
        current_leader = box.NULL,
        next_leader = box.NULL,
        expected_leader = box.NULL,
    },
    ----------------------------
    -- instance is a leader
    ----------------------------
    leader_changed_to_replica = {
        current_leader = 'a',
        next_leader = 'b',
        expected_leader = 'b',
    },
    leader_stays_the_same_current = {
        current_leader = 'a',
        next_leader = 'a',
        expected_leader = 'a',
    },
    empty_leader_no_changes_master = {
        current_leader = 'a',
        next_leader = box.NULL,
        expected_leader = 'a',
    },
}

for test_name, test_data in pairs(test_cases) do
    g.before_test('test_raft_' .. test_name, function()
        g.server:exec(function(test_data)
            require('cartridge.failover.raft')
            local vars = require('cartridge.vars').new('cartridge.failover')
            vars.instance_uuid = 'a' -- I'm "a"
            vars.leader_uuid = test_data.current_leader -- my leader

            vars:new('cache', {
                is_leader = false,
            })
            local leader_map = {
                a = 1,
                b = 2,
                [box.NULL] = 0,
            }
            rawset(_G, 'old_box', box)
            _G.box = {
                info = function()
                    return {
                        election = {
                            leader = leader_map[test_data.next_leader],
                        },
                        replication = {
                            [1] = {uuid = 'a'},
                            [2] = {uuid = 'b'},
                        }
                    }
                end,
                error = _G.old_box.error,
            }
            require('membership').set_payload = function() end

        end, {test_data})
    end)

    g['test_raft_' .. test_name] = function()
        local ok, err = pcall(g.server.exec, g.server, function(test_data)
            local vars = require('cartridge.vars').new('cartridge.failover')

            _G.__cartridge_on_election_trigger()
            assert(vars.cache.is_leader == (test_data.expected_leader == 'a'), {
                vars.cache.is_leader,
                vars.leader_uuid,
                test_data.expected_leader,
            })
            assert(vars.leader_uuid == test_data.expected_leader)
        end, {test_data})
        t.assert(ok, err)
    end

    g.after_test('test_raft_' .. test_name, function()
        g.server:exec(function()
            rawset(_G, 'box', _G.old_box)
        end)
    end)
end
