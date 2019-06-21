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

local e_bootstrap_vshard = errors.new_class('Bootstrapping vshard failed')
local e_create_router = errors.new_class('Error creating vshard-router')

vars:new('vshard_cfg', {
    -- [router_name] = vshard_cfg,
})

vars:new('routers', {
    -- [router_name] = vshard.router.new(),
})

-- Human readable router name for logging
-- Isn't exposed in public API
local function router_name(group_name)
    checks('?string')
    if group_name == nil then
        return 'vshard-router/default'
    else
        return ('vshard-router/%s'):format(group_name)
    end
end

local function get(group_name)
    checks('?string')
    local router_name = router_name(group_name)
    return vars.routers[router_name]
end

local function apply_config(conf)
    checks('table')

    local vshard_groups
    if conf.vshard_groups == nil then
        vshard_groups = {
            [box.NULL] = conf.vshard
        }
    else
        vshard_groups = conf.vshard_groups
    end

    for group_name, _ in pairs(vshard_groups) do
        local vshard_cfg = vshard_utils.get_vshard_config(group_name, conf)
        local router_name = router_name(group_name)

        -- luacheck: ignore 542
        if utils.deepcmp(vshard_cfg, vars.vshard_cfg[router_name]) then
            -- Don't reconfigure router unless config changed
        else
            log.info('Reconfiguring %s ...', router_name)

            local router = vars.routers[router_name]

            if router ~= nil then
                router:cfg(vshard_cfg)
            elseif group_name == nil then
                vshard.router.cfg(vshard_cfg)
                router = vshard.router.static
            else
                local err
                router, err = vshard.router.new(group_name, vshard_cfg)
                if router == nil then
                    return nil, e_create_router:new(
                        '%s (%s, %s)',
                        err.message, err.type, err.name
                    )
                end
            end

            vars.routers[router_name] = router
            vars.vshard_cfg[router_name] = vshard_cfg
        end
    end
end

local function bootstrap_group(group_name, vsgroup)
    checks('?string', 'table')

    if vsgroup.bootstrapped then
        return true
    end

    local router_name = router_name(group_name)
    local router = get(group_name)
    if router == nil then
        return nil, e_bootstrap_vshard:new("%s isn't initialized", router_name)
    end

    local info = router:info()

    for _, replicaset in pairs(info.replicasets or {}) do
        local uri = replicaset.master.uri
        local conn, _ = pool.connect(uri)

        if conn == nil then
            return nil, e_bootstrap_vshard:new(
                '%q in %s not ready yet',
                uri, router_name
            )
        end

        local ready = errors.netbox_eval(
            conn,
            'return box.space._bucket ~= nil',
            {}, {timeout = 1}
        )
        if not ready then
            return nil, e_bootstrap_vshard:new(
                '%q in %s not ready yet',
                uri, router_name
            )
        end
    end

    local conf = confapplier.get_readonly()
    local vshard_cfg = vshard_utils.get_vshard_config(group_name, conf)

    if next(vshard_cfg.sharding) == nil then
        return nil, e_bootstrap_vshard:new('Sharding config is empty')
    end

    log.info('Bootstrapping %s ...', router_name)

    local ok, err = get(group_name):bootstrap({timeout=10})
    if not ok and err.code ~= vshard.error.code.NON_EMPTY then
        return nil, e_bootstrap_vshard:new(
            '%s (%s, %s)',
            err.message, err.type, err.name
        )
    end

    return true
end

local function bootstrap()
    local conf = {
        vshard = confapplier.get_deepcopy('vshard'),
        vshard_groups = confapplier.get_deepcopy('vshard_groups'),
    }
    local patch = table.deepcopy(conf)

    if patch.vshard_groups == nil and patch.vshard == nil then
        return nil, e_bootstrap_vshard:new("vshard isn't configured")
    end

    local err = nil

    if patch.vshard_groups == nil then
        local ok, _err = bootstrap_group(nil, patch.vshard)
        if ok then
            patch.vshard.bootstrapped = true
        else
            err = _err
        end
    else
        for name, vsgroup in pairs(patch.vshard_groups) do
            local ok, _err = bootstrap_group(name, vsgroup)
            if ok then
                vsgroup.bootstrapped = true
            else
                err = _err
            end
        end
    end

    -- Some routers may be bootstrapped while others return errors
    -- It's not a problem since bootstrap_group() can be called
    -- multiple times on the same router without any problem
    if err ~= nil then
        return nil, err
    end

    if utils.deepcmp(conf, patch) then
        -- Everyting is already bootstrapped
        return nil, e_bootstrap_vshard:new("already bootstrapped")
    end

    local ok, err = confapplier.patch_clusterwide(patch)
    if not ok then
        return nil, err
    end

    return true
end

local function can_bootstrap_group(group_name, vsgroup)
    if vsgroup.bootstrapped then
        return false
    end

    local conf = confapplier.get_readonly()
    local vshard_cfg = vshard_utils.get_vshard_config(group_name, conf)
    if next(vshard_cfg.sharding) == nil then
        return false
    end

    return true
end

local function can_bootstrap()
    local conf = {
        vshard = confapplier.get_readonly('vshard'),
        vshard_groups = confapplier.get_readonly('vshard_groups'),
    }

    if conf.vshard == nil and conf.vshard_groups == nil then
        return false
    end

    if conf.vshard_groups == nil then
        if can_bootstrap_group(nil, conf.vshard) then
            return true
        end
    else
        for name, vsgroup in pairs(conf.vshard_groups) do
            if can_bootstrap_group(name, vsgroup) then
                return true
            end
        end
    end

    return false
end

local function get_bucket_count()
    local conf = {
        vshard = confapplier.get_readonly('vshard'),
        vshard_groups = confapplier.get_readonly('vshard_groups'),
    }

    if conf.vshard == nil and conf.vshard_groups == nil then
        return 0
    end

    if conf.vshard_groups == nil then
        return conf.vshard.bucket_count
    else
        -- This function is used in frontend only,
        -- returned value is useless for any other purpose.
        -- It is to be refactored later.
        local sum = 0
        for _, vsgroup in pairs(conf.vshard_groups) do
            sum = sum + vsgroup.bucket_count
        end
        return sum
    end
end

local function get_known_groups()
    local vshard_groups = confapplier.get_readonly('vshard_groups')
    if vshard_groups == nil then
        return {'default'}
    else
        local ret = {}
        for name, _ in pairs(vshard_groups) do
            table.insert(ret, name)
        end
        table.sort(ret)
        return ret
    end
end

return {
    role_name = 'vshard-router',
    validate_config = vshard_utils.validate_config,
    apply_config = apply_config,

    get = get,
    bootstrap = bootstrap,
    can_bootstrap = can_bootstrap,
    get_bucket_count = get_bucket_count,
    get_known_groups = get_known_groups,
}
