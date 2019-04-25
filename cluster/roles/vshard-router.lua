#!/usr/bin/env tarantool

local log = require('log')
local vshard = require('vshard')
local checks = require('checks')
local errors = require('errors')

local vars = require('cluster.vars').new('cluster.roles.vshard-router')
local pool = require('cluster.pool')
local utils = require('cluster.utils')
local confapplier = require('cluster.confapplier')
local vshard_utils = require('cluster.vshard-utils')
local vshard_storage = require('cluster.roles.vshard-storage')

local e_bootstrap_vshard = errors.new_class('Bootstrapping vshard failed')

vars:new('vshard_cfg')

local function apply_config(conf)
    checks('table')

    local vshard_cfg = {
        sharding = vshard_utils.get_sharding_config(),
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
    local vshard_cfg = confapplier.get_readonly('vshard')
    if vshard_cfg and vshard_cfg.bootstrapped then
        return nil, e_bootstrap_vshard:new('Already bootstrapped')
    end

    local info = vshard.router.info()
    for _, replicaset in pairs(info.replicasets or {}) do
        local uri = replicaset.master.uri
        local conn, _ = pool.connect(uri)

        if conn == nil then
            return nil, e_bootstrap_vshard:new('%q not ready yet', uri)
        end

        local ready = errors.netbox_eval(
            conn,
            'return box.space._bucket ~= nil',
            {}, {timeout = 1}
        )
        if not ready then
            return nil, e_bootstrap_vshard:new('%q not ready yet', uri)
        end
    end

    local sharding_config = vshard_utils.get_sharding_config()

    if next(sharding_config) == nil then
        return nil, e_bootstrap_vshard:new('Sharding config is empty')
    end

    log.info('Bootstrapping vshard.router...')

    local ok, err = vshard.router.bootstrap({timeout=10})
    if not ok and err.code ~= vshard.error.code.NON_EMPTY then
        return nil, e_bootstrap_vshard:new(
            '%s (%s, %s)',
            err.message, err.type, err.name
        )
    end

    local vshard_cfg = confapplier.get_deepcopy('vshard')
    vshard_cfg.bootstrapped = true
    local ok, err = confapplier.patch_clusterwide({vshard = vshard_cfg})
    if not ok then
        return nil, err
    end

    return true
end

local function can_bootstrap()
    local vshard_cfg = confapplier.get_readonly('vshard')

    if vshard_cfg == nil then
        return false
    elseif vshard_cfg.bootstrapped then
        return false
    end

    local sharding_config = vshard_utils.get_sharding_config()
    if next(sharding_config) == nil then
        return false
    end

    return true
end

local function get_bucket_count()
    local vshard_cfg = confapplier.get_readonly('vshard')
    return vshard_cfg and vshard_cfg.bucket_count or 0
end

return {
    role_name = 'vshard-router',
    validate_config = vshard_storage.validate_config,
    apply_config = apply_config,

    bootstrap = bootstrap,
    can_bootstrap = can_bootstrap,
    get_bucket_count = get_bucket_count,
}
