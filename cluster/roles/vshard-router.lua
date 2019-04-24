#!/usr/bin/env tarantool

local log = require('log')
local vshard = require('vshard')
local checks = require('checks')

local vars = require('cluster.vars').new('cluster.roles.vshard-router')
local utils = require('cluster.utils')
local admin = require('cluster.admin')
local topology = require('cluster.topology')
local vshard_storage = require('cluster.roles.vshard-storage')

vars:new('vshard_cfg')

local function apply_config(conf)
    checks('table')

    local vshard_cfg = {
        sharding = topology.get_vshard_sharding_config(),
        bucket_count = conf.vshard.bucket_count,
    }

    if utils.deepcmp(vshard_cfg, vars.vshard_cfg) then
        -- No reconfiguration required, skip it
        return
    end

    log.info('Reconfiguring vshard.router...')
    vshard.router.cfg(vshard_cfg)
    vars.vshard_cfg = vshard_cfg
end

local function bootstrap()
    -- To be called with RPC
    return admin.bootstrap_vshard()
end

return {
    role_name = 'vshard-router',
    validate_config = vshard_storage.validate_config,
    apply_config = apply_config,

    bootstrap = bootstrap,
}
