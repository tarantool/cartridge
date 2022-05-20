local membership = require('membership')
local checks = require('checks')
local log = require('log')
local fun = require('fun')

local topology = require('cartridge.topology')
local pool = require('cartridge.pool')
local argparse = require('cartridge.argparse')

local vars = require('cartridge.vars').new('cartridge.failover')
local errors = require('errors')

local PromoteLeaderError = errors.new_class('PromoteLeaderError')
local AppointmentError = errors.new_class('AppointmentError')

vars:new('leader_uuid')
vars:new('raft_trigger')

--- Generate appointments according to raft status.
-- Used in 'raft' failover mode.
-- @function get_appointments
local function get_appointments(topology_cfg)
    checks('table')
    local replicasets = assert(topology_cfg.replicasets)

    local appointments = {}

    local box_info = box.info()
    for replicaset_uuid, _ in pairs(replicasets) do
        local leaders = topology.get_leaders_order(
            topology_cfg, replicaset_uuid
        )
        if replicaset_uuid == vars.replicaset_uuid then
            local my_leader_id = box_info.election.leader
            local my_leader = box_info.replication[my_leader_id]
            if my_leader ~= nil then
                appointments[replicaset_uuid] = my_leader.uuid
                goto next_rs
            end
        end

        local latest_leader
        local latest_term = 0
        for _, instance_uuid in ipairs(leaders) do
            local server = topology_cfg.servers[instance_uuid]
            local member = membership.get_member(server.uri)

            if member ~= nil
            and member.payload.leader_uuid ~= nil
            and member.payload.raft_term or 0 >= latest_term
            then
                latest_leader = member.payload.leader_uuid
                latest_term = member.payload.raft_term or 0
            end
        end
        appointments[replicaset_uuid] = latest_leader
        ::next_rs::
    end

    appointments[vars.replicaset_uuid] = vars.leader_uuid
    return appointments
end

local function on_election_trigger()
    local box_info = box.info()
    local election = box_info.election

    local leader = box_info.replication[election.leader] or {}

    if vars.leader_uuid ~= leader.uuid then
        vars.cache.is_leader = vars.leader_uuid == vars.instance_uuid
        vars.leader_uuid = leader.uuid
        membership.set_payload('leader_uuid', vars.leader_uuid)
    end
    membership.set_payload('raft_term', election.term)
end

local function cfg()
    assert(box.ctl.on_election, "Your Tarantool version doesn't support raft failover mode")
    log.warn('Raft failover is in beta-version')
    local box_opts = argparse.get_box_opts()

    box.cfg{
        -- The instance is set to candidate, so it may become the leader
        -- as well as vote for other instances.
        --
        -- Alternative: set one of instances to `voter` so that it
        -- never becomes a leader but still votes for one of its peers and helps
        -- it reach election quorum.
        election_mode = box_opts.election_mode or 'candidate',
        -- Quorum for both synchronous transactions and
        -- leader election votes.
        replication_synchro_quorum = box_opts.replication_synchro_quorum or 'N/2 + 1',
        -- Synchronous replication timeout. The transaction will be
        -- rolled back if no quorum is achieved during timeout.
        replication_synchro_timeout = box_opts.replication_synchro_timeout,
        -- Timeout between elections. Needed to restart elections when no leader
        -- emerges soon enough. Equals 4 * replication_timeout
        election_timeout = box_opts.election_timeout,
    }

    if vars.raft_trigger == nil then
        vars.raft_trigger = box.ctl.on_election(on_election_trigger)
    end

    membership.set_payload('raft_term', box.info.election.term)

    return true
end

-- disable raft if it was enabled
local function disable()
    if vars.raft_trigger ~= nil then
        box.ctl.on_election(nil, vars.raft_trigger)
        vars.raft_trigger = nil
    end
    box.cfg{ election_mode = 'off' }
    vars.leader_uuid = nil
end

return {
    cfg = cfg,
    disable = disable,
    get_appointments = get_appointments,
}
