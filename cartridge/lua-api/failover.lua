--- Administration functions (failover related).
--
-- @module cartridge.lua-api.failover

local checks = require('checks')
local errors = require('errors')

local twophase = require('cartridge.twophase')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')

local FailoverSetParamsError = errors.new_class('FailoverSetParamsError')

--- Get failover configuration.
--
-- (**Added** in v2.0.2-??)
-- @function get_params
-- @treturn FailoverParams
local function get_params()
    --- Failover parameters.
    --
    -- (**Added** in v2.0.2-??)
    -- @table FailoverParams
    -- @tfield string mode
    --   Supported modes are "disabled", "eventual" and "stateful"
    -- @tfield nil|string state_provider
    --   Only "tarantool" is supported now
    -- @tfield nil|table tarantool_params
    --   `{uri = 'string', password = 'string'}`
    return topology.get_failover_params(
        confapplier.get_readonly('topology')
    )
end

--- Configure automatic failover.
--
-- (**Added** in v2.0.2-??)
-- @function set_params
-- @tparam table opts
-- @tparam ?string opts.mode
-- @tparam ?string opts.state_provider
-- @tparam ?table opts.tarantool_params
-- @treturn[1] boolean `true` if config applied successfully
-- @treturn[2] nil
-- @treturn[2] table Error description
local function set_params(opts)
    checks({
        mode = '?string',
        state_provider = '?string',
        tarantool_params = '?table',
    })

    local topology_cfg = confapplier.get_deepcopy('topology')
    if topology_cfg == nil then
        return nil, FailoverSetParamsError:new("Cluster isn't bootstrapped yet")
    end

    if opts == nil then
        return true
    end

    -- backward compatibility with older clusterwide config
    if topology_cfg.failover == nil then
        topology_cfg.failover = {mode = 'disabled'}
    elseif type(topology_cfg.failover) == 'boolean' then
        topology_cfg.failover = {
            mode = topology_cfg.failover and 'eventual' or 'disabled',
        }
    end

    if opts.mode ~= nil then
        topology_cfg.failover.mode = opts.mode
    end

    if opts.state_provider ~= nil then
        topology_cfg.failover.state_provider = opts.state_provider
    end
    if opts.tarantool_params ~= nil then
        topology_cfg.failover.tarantool_params = opts.tarantool_params
    end

    local ok, err = twophase.patch_clusterwide({topology = topology_cfg})
    if not ok then
        return nil, err
    end

    return true
end

--- Get current failover state.
--
-- (**Deprecated** since v2.0.2-??)
-- @function get_failover_enabled
local function get_failover_enabled()
    return get_params().mode ~= 'disabled'
end

--- Enable or disable automatic failover.
--
-- (**Deprecated** since v2.0.2-??)
-- @function set_failover_enabled
-- @tparam boolean enabled
-- @treturn[1] boolean New failover state
-- @treturn[2] nil
-- @treturn[2] table Error description
local function set_failover_enabled(enabled)
    checks('boolean')
    local ok, err = set_params({
        mode = enabled and 'eventual' or 'disabled'
    })
    if ok == nil then
        return nil, err
    end

    return get_failover_enabled()
end

return {
    get_params = get_params,
    set_params = set_params,
    get_failover_enabled = get_failover_enabled, -- deprecated
    set_failover_enabled = set_failover_enabled, -- deprecated
}
