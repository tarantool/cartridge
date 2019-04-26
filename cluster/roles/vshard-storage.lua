#!/usr/bin/env tarantool

local log = require('log')
local vshard = require('vshard')
local checks = require('checks')

local vars = require('cluster.vars').new('cluster.roles.vshard-storage')
local utils = require('cluster.utils')
local vshard_utils = require('cluster.vshard-utils')

vars:new('vshard_cfg')

local function apply_config(conf)
    checks('table')

    local vshard_cfg = {
        sharding = vshard_utils.get_sharding_config(),
        bucket_count = conf.vshard.bucket_count,
        listen = box.cfg.listen,
    }

    if utils.deepcmp(vshard_cfg, vars.vshard_cfg) then
        -- No reconfiguration required, skip it
        return
    end

    log.info('Reconfiguring vshard.storage...')
    vshard.storage.cfg(vshard_cfg, box.info.uuid)
    vars.vshard_cfg = vshard_cfg
end

local function init()
    rawset(_G, 'vshard', vshard)
end

local function stop()
    rawset(_G, 'vshard', nil)
end

return {
    role_name = 'vshard-storage',
    validate_config = vshard_utils.validate_config,
    apply_config = apply_config,
    init = init,
    stop = stop,
}
