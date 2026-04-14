--- Runtime helpers for manual election mode migration.
--
-- @module cartridge.failover.manual_election_mode
-- @local

local log = require('log')
local checks = require('checks')
local errors = require('errors')

local vars = require('cartridge.vars').new('cartridge.failover')
local pool = require('cartridge.pool')
local topology = require('cartridge.topology')

local FailoverError = errors.new_class('FailoverError')

function _G.__cartridge_failover_probe_manual_election_mode()
    return {
        election_mode = box.cfg.election_mode,
        election_fencing_mode = box.cfg.election_fencing_mode,
    }
end

function _G.__cartridge_failover_switch_to_manual_election_mode()
    local prev_election_mode = box.cfg.election_mode
    local prev_election_fencing_mode = box.cfg.election_fencing_mode

    if prev_election_mode == 'manual'
    and prev_election_fencing_mode == 'off' then
        return {
            changed = false,
            prev_election_mode = prev_election_mode,
            prev_election_fencing_mode = prev_election_fencing_mode,
        }
    end

    if prev_election_mode ~= 'off'
    and prev_election_mode ~= 'manual' then
        return nil, FailoverError:new(
            'Expected election_mode="off" or "manual", got %q',
            tostring(prev_election_mode)
        )
    end

    local ok, err = pcall(box.cfg, {
        election_mode = 'manual',
        election_fencing_mode = 'off',
    })

    if ok ~= true then
        return nil, FailoverError:new(
            'Unable to switch election mode to "manual": %s',
            err or 'unknown'
        )
    end

    return {
        changed = true,
        prev_election_mode = prev_election_mode,
        prev_election_fencing_mode = prev_election_fencing_mode,
    }
end

function _G.__cartridge_failover_rollback_manual_election_mode(
    prev_election_mode,
    prev_election_fencing_mode
)
    checks('?string', '?string')

    local ok, err = pcall(box.cfg, {
        election_mode = prev_election_mode,
        election_fencing_mode = prev_election_fencing_mode,
    })
    if ok ~= true then
        return nil, FailoverError:new(
            'Unable to rollback election mode to %q: %s',
            tostring(prev_election_mode),
            err or 'unknown'
        )
    end

    return true
end

function _G.__cartridge_failover_switch_to_off_election_mode(target_fencing_mode)
    checks('?string')

    if target_fencing_mode == nil then
        target_fencing_mode = 'soft'
    end

    local prev_election_mode = box.cfg.election_mode
    local prev_election_fencing_mode = box.cfg.election_fencing_mode

    if prev_election_mode ~= 'off'
    and prev_election_mode ~= 'manual' then
        return nil, FailoverError:new(
            'Expected election_mode="off" or "manual", got %q',
            tostring(prev_election_mode)
        )
    end

    if prev_election_mode == 'off'
    and prev_election_fencing_mode == target_fencing_mode then
        return {
            changed = false,
            prev_election_mode = prev_election_mode,
            prev_election_fencing_mode = prev_election_fencing_mode,
        }
    end

    local ok, err = pcall(box.cfg, {
        election_mode = 'off',
        election_fencing_mode = target_fencing_mode,
    })
    if ok ~= true then
        return nil, FailoverError:new(
            'Unable to switch election mode to "off": %s',
            err or 'unknown'
        )
    end

    return {
        changed = true,
        prev_election_mode = prev_election_mode,
        prev_election_fencing_mode = prev_election_fencing_mode,
    }
end

local function get_all_replicaset_servers(topology_cfg)
    local leaders_order = topology.get_leaders_order(
        topology_cfg,
        vars.replicaset_uuid,
        nil,
        {
            only_enabled = false,
            only_electable = false,
        }
    )

    local servers_to_switch = {}
    for _, instance_uuid in ipairs(leaders_order) do
        local server = topology_cfg.servers[instance_uuid]
        if topology.disabled(instance_uuid, server) then
            return nil, FailoverError:new(
                'Replicaset %q contains disabled instance %q',
                vars.replicaset_uuid,
                instance_uuid
            )
        end

        local ok, err = topology.member_is_healthy(server.uri, instance_uuid)
        if ok == nil then
            return nil, FailoverError:new(
                'Replicaset %q contains unhealthy instance %q: %s',
                vars.replicaset_uuid,
                instance_uuid,
                err
            )
        end

        table.insert(servers_to_switch, {
            uuid = instance_uuid,
            uri = server.uri,
        })
    end

    if #servers_to_switch == 0 then
        return nil, FailoverError:new(
            'No enabled instances found in replicaset %q',
            tostring(vars.replicaset_uuid)
        )
    end

    return servers_to_switch
end

local function get_enabled_replicaset_servers(topology_cfg)
    local leaders_order = topology.get_leaders_order(
        topology_cfg,
        vars.replicaset_uuid,
        nil,
        {
            only_enabled = true,
            only_electable = false,
        }
    )

    local servers_to_switch = {}
    for _, instance_uuid in ipairs(leaders_order) do
        local server = topology_cfg.servers[instance_uuid]
        table.insert(servers_to_switch, {
            uuid = instance_uuid,
            uri = server.uri,
        })
    end

    if #servers_to_switch == 0 then
        return nil, FailoverError:new(
            'No enabled instances found in replicaset %q',
            tostring(vars.replicaset_uuid)
        )
    end

    return servers_to_switch
end

local function switch_to_manual_election_mode()
    if box.ctl.promote == nil then
        return nil, FailoverError:new('box.ctl.promote() is unavailable')
    end

    local clusterwide_config = vars.clusterwide_config
    if clusterwide_config == nil then
        return nil, FailoverError:new('Failover is not configured yet')
    end

    local topology_cfg = clusterwide_config:get_readonly('topology')
    if topology_cfg == nil then
        return nil, FailoverError:new('Topology config is unavailable')
    end

    local failover_cfg = topology.get_failover_params(topology_cfg)
    if failover_cfg.mode ~= 'stateful' then
        return nil, FailoverError:new(
            'switch_to_manual_election_mode() is supported only for stateful failover, got %q',
            tostring(failover_cfg.mode)
        )
    end

    if vars.enable_synchro_mode ~= true then
        return nil, FailoverError:new('Synchro mode must be enabled')
    end

    if vars.cache.is_leader ~= true then
        return nil, FailoverError:new(
            'switch_to_manual_election_mode() must be called on the appointed leader'
        )
    end

    if box.info.ro then
        return nil, FailoverError:new('Local instance must be RW')
    end

    if vars.failover_suppressed == true then
        return nil, FailoverError:new('Failover is suppressed')
    end

    if box.cfg.election_mode ~= 'off' then
        return nil, FailoverError:new(
            'Local election_mode must be "off", got %q',
            tostring(box.cfg.election_mode)
        )
    end

    local replicaset = topology_cfg.replicasets[vars.replicaset_uuid]
    if replicaset == nil then
        return nil, FailoverError:new(
            'Replicaset %q is absent from topology config',
            tostring(vars.replicaset_uuid)
        )
    end

    if replicaset.all_rw then
        return nil, FailoverError:new(
            'switch_to_manual_election_mode() is not supported with ALL_RW replicasets'
        )
    end

    local servers_to_switch, err = get_all_replicaset_servers(topology_cfg)
    if servers_to_switch == nil then
        return nil, err
    end

    local local_state = {
        election_mode = box.cfg.election_mode,
        election_fencing_mode = box.cfg.election_fencing_mode,
    }
    local peer_states = {}
    for _, server in ipairs(servers_to_switch) do
        if server.uuid ~= vars.instance_uuid then
            local conn, connect_err = pool.connect(server.uri, {wait_connected = false})
            if conn == nil then
                return nil, FailoverError:new(
                    'Unable to connect to instance %q: %s',
                    server.uuid,
                    connect_err or 'unknown'
                )
            end

            local res, probe_err = errors.netbox_call(
                conn,
                '__cartridge_failover_probe_manual_election_mode',
                {},
                {timeout = vars.options.NETBOX_CALL_TIMEOUT}
            )

            if res == nil then
                return nil, FailoverError:new(
                    'Unable to probe election state on instance %q: %s',
                    server.uuid,
                    probe_err or 'unknown'
                )
            end

            peer_states[server.uuid] = res
            if res.election_mode ~= 'off' and res.election_mode ~= 'manual' then
                return nil, FailoverError:new(
                    'Instance %q has unsupported election_mode=%q',
                    server.uuid,
                    tostring(res.election_mode)
                )
            end
        end
    end

    local changed_servers = {}

    local function rollback(original_err)
        if #changed_servers == 0 then
            return nil, FailoverError:new('%s', original_err)
        end

        log.warn('%s. Rolling back %d instance(s)', original_err, #changed_servers)
        local rollback_errors = {}
        for index = #changed_servers, 1, -1 do
            local server = changed_servers[index]
            if server.uuid == vars.instance_uuid then
                local ok, rollback_err = pcall(box.cfg, {
                    election_mode = server.prev_election_mode,
                    election_fencing_mode = server.prev_election_fencing_mode,
                })
                if ok ~= true then
                    table.insert(rollback_errors, string.format(
                        'local instance %q: %s',
                        server.uuid,
                        rollback_err or 'unknown'
                    ))
                elseif box.cfg.election_mode ~= server.prev_election_mode
                or box.cfg.election_fencing_mode ~= server.prev_election_fencing_mode then
                    table.insert(rollback_errors, string.format(
                        'local instance %q: expected election_mode=%q and election_fencing_mode=%q, got %q and %q',
                        server.uuid,
                        tostring(server.prev_election_mode),
                        tostring(server.prev_election_fencing_mode),
                        tostring(box.cfg.election_mode),
                        tostring(box.cfg.election_fencing_mode)
                    ))
                end
            else
                local conn, connect_err = pool.connect(server.uri, {wait_connected = false})
                if conn == nil then
                    table.insert(rollback_errors, string.format(
                        'instance %q: %s',
                        server.uuid,
                        connect_err or 'unknown'
                    ))
                    goto continue
                end

                local res, rollback_err = errors.netbox_call(
                    conn,
                    '__cartridge_failover_rollback_manual_election_mode',
                    {
                        server.prev_election_mode,
                        server.prev_election_fencing_mode,
                    },
                    {timeout = vars.options.NETBOX_CALL_TIMEOUT}
                )

                if res == nil then
                    table.insert(rollback_errors, string.format(
                        'instance %q: %s',
                        server.uuid,
                        rollback_err or 'unknown'
                    ))
                end
            end

            ::continue::
        end

        if #rollback_errors > 0 then
            return nil, FailoverError:new(
                '%s. Rollback failed: %s',
                original_err,
                table.concat(rollback_errors, '; ')
            )
        end

        return nil, FailoverError:new('%s', original_err)
    end

    log.info(
        'Switching replicaset %q to election_mode="manual"',
        vars.replicaset_uuid
    )

    for _, server in ipairs(servers_to_switch) do
        if server.uuid ~= vars.instance_uuid then
            local state = peer_states[server.uuid]
            if state.election_mode == 'manual'
            and state.election_fencing_mode == 'off' then
                log.info(
                    'Skipping instance %q: election_mode is already "manual"',
                    server.uuid
                )
            else
                local conn, connect_err = pool.connect(server.uri, {wait_connected = false})
                if conn == nil then
                    return rollback(string.format(
                        'Unable to connect to instance %q: %s',
                        server.uuid,
                        connect_err or 'unknown'
                    ))
                end

                local res, switch_err = errors.netbox_call(
                    conn,
                    '__cartridge_failover_switch_to_manual_election_mode',
                    {},
                    {timeout = vars.options.NETBOX_CALL_TIMEOUT}
                )

                if res ~= nil and res.changed then
                    table.insert(changed_servers, {
                        uuid = server.uuid,
                        uri = server.uri,
                        prev_election_mode = res.prev_election_mode,
                        prev_election_fencing_mode = res.prev_election_fencing_mode,
                    })
                end

                if res == nil then
                    return rollback(string.format(
                        'Unable to switch instance %q to election_mode="manual": %s',
                        server.uuid,
                        switch_err or 'unknown'
                    ))
                end
            end
        end
    end

    if vars.cache.is_leader ~= true then
        return rollback(
            'Local instance lost leadership before switching itself'
        )
    end

    if box.info.ro then
        return rollback(
            'Local instance became read-only before switching itself'
        )
    end

    local ok, err = pcall(box.cfg, {
        election_mode = 'manual',
        election_fencing_mode = 'off',
    })
    if ok ~= true then
        return rollback(string.format(
            'Unable to switch local instance %q to election_mode="manual": %s',
            vars.instance_uuid,
            err or 'unknown'
        ))
    end

    table.insert(changed_servers, {
        uuid = vars.instance_uuid,
        prev_election_mode = local_state.election_mode,
        prev_election_fencing_mode = local_state.election_fencing_mode,
    })

    if box.cfg.election_mode ~= 'manual'
    or box.cfg.election_fencing_mode ~= 'off' then
        return rollback(string.format(
            'Unable to verify local election mode switch, got %q and %q',
            tostring(box.cfg.election_mode),
            tostring(box.cfg.election_fencing_mode)
        ))
    end

    log.info('Attempting box.ctl.promote() from manual election mode migration helper')
    local promoted, promote_err = pcall(box.ctl.promote)
    if promoted ~= true then
        return rollback(string.format(
            'box.ctl.promote() failed: %s',
            promote_err or 'unknown'
        ))
    end

    log.info(
        'Replicaset %q was switched to election_mode="manual"',
        vars.replicaset_uuid
    )
    return true
end

local function switch_to_off_election_mode(opts)
    checks('?table')
    opts = opts or {}

    local target_fencing_mode = opts.election_fencing_mode or 'soft'

    local clusterwide_config = vars.clusterwide_config
    if clusterwide_config == nil then
        return nil, FailoverError:new('Failover is not configured yet')
    end

    local topology_cfg = clusterwide_config:get_readonly('topology')
    if topology_cfg == nil then
        return nil, FailoverError:new('Topology config is unavailable')
    end

    local failover_cfg = topology.get_failover_params(topology_cfg)
    if failover_cfg.mode ~= 'stateful' then
        return nil, FailoverError:new(
            'switch_to_off_election_mode() is supported only for stateful failover, got %q',
            tostring(failover_cfg.mode)
        )
    end

    if vars.cache.is_leader ~= true then
        return nil, FailoverError:new(
            'switch_to_off_election_mode() must be called on the appointed leader'
        )
    end

    local replicaset = topology_cfg.replicasets[vars.replicaset_uuid]
    if replicaset == nil then
        return nil, FailoverError:new(
            'Replicaset %q is absent from topology config',
            tostring(vars.replicaset_uuid)
        )
    end

    local servers_to_switch, err = get_enabled_replicaset_servers(topology_cfg)
    if servers_to_switch == nil then
        return nil, err
    end

    local local_election_mode = box.cfg.election_mode
    if local_election_mode ~= 'off' and local_election_mode ~= 'manual' then
        return nil, FailoverError:new(
            'Local instance %q has unsupported election_mode=%q',
            vars.instance_uuid,
            tostring(local_election_mode)
        )
    end

    local peer_states = {}
    for _, server in ipairs(servers_to_switch) do
        if server.uuid ~= vars.instance_uuid then
            local conn, connect_err = pool.connect(server.uri, {wait_connected = false})
            if conn == nil then
                return nil, FailoverError:new(
                    'Unable to connect to instance %q: %s',
                    server.uuid,
                    connect_err or 'unknown'
                )
            end

            local res, probe_err = errors.netbox_call(
                conn,
                '__cartridge_failover_probe_manual_election_mode',
                {},
                {timeout = vars.options.NETBOX_CALL_TIMEOUT}
            )

            if res == nil then
                return nil, FailoverError:new(
                    'Unable to probe election state on instance %q: %s',
                    server.uuid,
                    probe_err or 'unknown'
                )
            end

            peer_states[server.uuid] = res
            if res.election_mode ~= 'off' and res.election_mode ~= 'manual' then
                return nil, FailoverError:new(
                    'Instance %q has unsupported election_mode=%q',
                    server.uuid,
                    tostring(res.election_mode)
                )
            end
        end
    end

    log.info(
        'Switching replicaset %q to election_mode="off" and election_fencing_mode=%q',
        vars.replicaset_uuid,
        target_fencing_mode
    )

    for _, server in ipairs(servers_to_switch) do
        if server.uuid ~= vars.instance_uuid then
            local state = peer_states[server.uuid]
            if state.election_mode == 'off'
            and state.election_fencing_mode == target_fencing_mode then
                log.info(
                    'Skipping instance %q: election mode is already "off"',
                    server.uuid
                )
            else
                local conn, connect_err = pool.connect(server.uri, {wait_connected = false})
                if conn == nil then
                    return nil, FailoverError:new(
                        'Unable to connect to instance %q: %s',
                        server.uuid,
                        connect_err or 'unknown'
                    )
                end

                local res, switch_err = errors.netbox_call(
                    conn,
                    '__cartridge_failover_switch_to_off_election_mode',
                    {target_fencing_mode},
                    {timeout = vars.options.NETBOX_CALL_TIMEOUT}
                )

                if res == nil then
                    return nil, FailoverError:new(
                        'Unable to switch instance %q to election_mode="off": %s',
                        server.uuid,
                        switch_err or 'unknown'
                    )
                end
            end
        end
    end

    if vars.cache.is_leader ~= true then
        return nil, FailoverError:new(
            'Local instance lost leadership before switching itself'
        )
    end

    local res, switch_err = _G.__cartridge_failover_switch_to_off_election_mode(target_fencing_mode)
    if res == nil then
        return nil, FailoverError:new(
            'Unable to switch local instance %q to election_mode="off": %s',
            vars.instance_uuid,
            switch_err or 'unknown'
        )
    end

    log.info(
        'Replicaset %q was switched to election_mode="off"',
        vars.replicaset_uuid
    )
    return true
end

return {
    switch_to_manual_election_mode = switch_to_manual_election_mode,
    switch_to_off_election_mode = switch_to_off_election_mode,
}
