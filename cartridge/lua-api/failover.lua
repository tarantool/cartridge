--- Administration functions (failover related).
--
-- @module cartridge.lua-api.failover

local checks = require('checks')
local errors = require('errors')

local twophase = require('cartridge.twophase')
local confapplier = require('cartridge.confapplier')

local FailoverSetParamsError = errors.new_class('FailoverSetParamsError')

--- Get failover configuration.
--
-- (**Added** in v2.0.1-78)
-- @function get_params
-- @treturn FailoverParams
local function get_params()
    local topology_cfg = confapplier.get_readonly('topology')
    local failover_cfg = topology_cfg and topology_cfg.failover

    --- Failover parameters.
    --
    -- (**Added** in v2.0.1-78)
    -- @table FailoverParams
    -- @tfield boolean enabled Wether automatic failover is enabled
    -- @tfield nil|string coordinator_uri URI of external coordinator
    if failover_cfg == nil then
        return {enabled = false}
    elseif type(failover_cfg) == 'boolean' then
        return {enabled = failover_cfg}
    else
        return failover_cfg
    end
end

--- Configure automatic failover.
--
-- (**Added** in v2.0.1-78)
-- @function set_params
-- @treturn[1] boolean `true` if config applied successfully
-- @treturn[2] nil
-- @treturn[2] table Error description
local function set_params(opts)
    checks({
        enabled = '?boolean',
        coordinator_uri = '?string'
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
        topology_cfg.failover = {enabled = false}
    elseif type(topology_cfg.failover) == 'boolean' then
        topology_cfg.failover = {enabled = topology_cfg.failover}
    end

    if opts.enabled ~= nil then
        topology_cfg.failover.enabled = opts.enabled
    end

    if opts.coordinator_uri ~= nil then
        topology_cfg.failover.coordinator_uri = opts.coordinator_uri
    end

    local ok, err = twophase.patch_clusterwide({topology = topology_cfg})
    if not ok then
        return nil, err
    end

    return true
end

return {
    get_params = get_params,
    set_params = set_params,
}
