local membership = require('membership')
local checks = require('checks')
local log = require('log')
local fun = require('fun')

local topology = require('cartridge.topology')
local pool = require('cartridge.pool')
local argparse = require('cartridge.argparse')
local utils = require('cartridge.utils')

local vars = require('cartridge.vars').new('cartridge.failover')
local errors = require('errors')

local PromoteLeaderError = errors.new_class('PromoteLeaderError')
local UnsupportedError = errors.new_class('UnsupportedError')

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
            topology_cfg, replicaset_uuid, nil, {only_enabled = true}
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
            and (member.payload.raft_term or 0) >= latest_term
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
        -- if there is no leader, we won't change the table
        if leader.uuid ~= nil then
            vars.leader_uuid = leader.uuid
        end
        membership.set_payload('leader_uuid', vars.leader_uuid)
    end
    vars.cache.is_leader = vars.leader_uuid == vars.instance_uuid
    membership.set_payload('raft_term', election.term)
end

_G.__cartridge_on_election_trigger = on_election_trigger

local function check_version()
    if box.ctl.on_election == nil then
        return nil, UnsupportedError:new(
            "Your Tarantool version doesn't support raft failover mode, need Tarantool 2.10 or higher"
        )
    end
    return true
end

local function cfg()
    log.warn('Raft failover is in beta-version')
    local box_opts = argparse.get_box_opts()

    local topology_cfg = package.loaded['cartridge.confapplier'].get_readonly('topology')
    if topology_cfg ~= nil and topology_cfg.servers[box.info.uuid].electable == false then
        box_opts.election_mode = 'voter'
        log.info("This instance is unelectable and became voter")
    end

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
        -- If set to `soft`, fencing is on (default behaviour).
        -- If set to `strict`, fencing is on, and timeout for dead connection
        -- on leader is set to 2 * replication timeout, this increases the
        -- chances, there will be only one leader at a time.
        -- If set to `off`, fencing is off and the leader doesn't resign when
        -- it loses the quorum. If enabled on the current leader when it doesn't
        -- have a quorum of alive connections, the leader will resign its leadership.
        election_fencing_mode = box_opts.election_fencing_mode,
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

    local box_info = box.info
    if box_info.synchro ~= nil
    and box_info.synchro.queue ~= nil
    and box_info.synchro.queue.owner ~= 0
    and box_info.synchro.queue.owner == box_info.id then
        local err = pcall(box.ctl.demote)
        if err ~= nil then
            log.error('Failed to demote: %s', err)
        end
        return err
    end
end

local function promote(replicaset_leaders)
    local topology_cfg = package.loaded['cartridge.confapplier'].get_readonly('topology')

    if topology_cfg == nil then
        return nil, PromoteLeaderError:new('Unable to get topology')
    end

    local servers_list = fun.filter(topology.not_disabled,
                                    topology_cfg.servers):filter(topology.electable):tomap()
    local replicasets = topology_cfg.replicasets

    local uri_list, err = utils.appoint_leaders_check(replicaset_leaders, servers_list, replicasets)
    if uri_list == nil then
        return nil, err
    end

    local _, err = pool.map_call('box.ctl.promote', nil, {uri_list = uri_list})
    if err ~= nil then
        return nil, PromoteLeaderError:new('Leader promotion failed')
    end

    return true
end

return {
    cfg = cfg,
    check_version = check_version,
    disable = disable,
    get_appointments = get_appointments,
    promote = promote,
}
