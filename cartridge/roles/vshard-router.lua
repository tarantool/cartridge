local log = require('log')

local vshard = require('vshard')

local checks = require('checks')
local errors = require('errors')

local vars = require('cartridge.vars').new('cartridge.roles.vshard-router')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local twophase = require('cartridge.twophase')
local hotreload = require('cartridge.hotreload')
local confapplier = require('cartridge.confapplier')
local vshard_utils = require('cartridge.vshard-utils')

hotreload.whitelist_globals({
    "__module_vshard_lua_gc",
    "__module_vshard_router",
    "__module_vshard_storage",
    "__module_vshard_util",
    "future_storage_call_result",
    "gc_bucket_f",
})

local e_bootstrap_vshard = errors.new_class('Bootstrapping vshard failed')
local e_create_router = errors.new_class('Error creating vshard-router')

vars:new('vshard_cfg', {
    -- [router_name] = vshard_cfg,
})

vars:new('routers', {
    -- [router_name] = vshard.router.new(),
})

vars:new('issues', {})
vars:new('enable_alerting', false)

-- Human readable router name for logging
-- Isn't exposed in public API
local function router_name(group_name)
    checks('string')
    if group_name == nil then
        return 'vshard-router/default'
    else
        return ('vshard-router/%s'):format(group_name)
    end
end

local function get(group_name)
    checks('?string')
    if group_name == nil then
        group_name = 'default'
    end
    local router_name = router_name(group_name)
    return vars.routers[router_name]
end

local current_connections = 0
local conn_limit = math.huge

vars:new('on_connect')
vars:new('on_disconnect')
local function on_connect()
    if box.session.type() == 'binary' then
        if current_connections >= conn_limit then
            error("Too many connections")
        end
        current_connections = current_connections + 1
    end
end
local function on_disconnect()
    if box.session.type() == 'binary' then
        -- check on_disconnect called for dropped connection or not
        current_connections = current_connections - 1
    end
end

local function init(_)
    local opts, _ = require('cartridge.argparse').get_opts({
        connections_limit = 'number',
        add_vshard_router_alerts_to_issues = 'boolean',
    })
    if opts.add_vshard_router_alerts_to_issues ~= nil then
        vars.enable_alerting = opts.add_vshard_router_alerts_to_issues
    end
    local limit = opts.connections_limit
    if limit == nil then
        return
    end
    conn_limit = limit
    vars.on_connect = on_connect
    vars.on_disconnect = on_disconnect
    box.session.on_connect(vars.on_connect)
    box.session.on_disconnect(vars.on_disconnect)
end

local function apply_config(conf)
    checks('table')

    local vshard_groups
    if conf.vshard_groups == nil then
        vshard_groups = {default = conf.vshard}
    else
        vshard_groups = conf.vshard_groups
    end

    for group_name, _ in pairs(vshard_groups) do
        local vshard_cfg = vshard_utils.get_vshard_config(group_name, conf)
        vshard_cfg.collect_lua_garbage = nil
        local router_name = router_name(group_name)

        -- luacheck: ignore 542
        if utils.deepcmp(vshard_cfg, vars.vshard_cfg[router_name]) then
            -- Don't reconfigure router unless config changed
        else
            log.info('Reconfiguring %s ...', router_name)

            local router = vars.routers[router_name]

            if router ~= nil then
                router:cfg(vshard_cfg)
            elseif group_name == 'default' then
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
            router:discovery_set('on')
        end
    end
end

local function stop()
    local confapplier = require('cartridge.confapplier')
    local advertise_uri = confapplier.get_advertise_uri()
    local instance_uuid = confapplier.get_instance_uuid()
    local replicaset_uuid = confapplier.get_replicaset_uuid()

    for router_name, router in pairs(vars.routers) do
        router:cfg({
            bucket_count = router.total_bucket_count,
            sharding = {[replicaset_uuid] = {
                replicas = {[instance_uuid] = {
                    uri = pool.format_uri(advertise_uri),
                    name = advertise_uri,
                    master = false,
                }},
            }}
        }, instance_uuid)

        vars.vshard_cfg[router_name] = nil

        if router.failover_fiber ~= nil
        and router.failover_fiber:status() ~= 'dead'
        then
            router.failover_fiber:cancel()
            router.failover_fiber = nil
        end

        router:discovery_set('off')
    end
    box.session.on_connect(nil, vars.on_connect)
    box.session.on_disconnect(nil, vars.on_disconnect)
end

local function bootstrap_group(group_name, vsgroup)
    checks('string', 'table')

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
        local ready = errors.netbox_eval(
            pool.connect(uri, {wait_connected = false, fetch_schema = false}),
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
    vshard_cfg.collect_lua_garbage = nil

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

    vars.issues = {}

    -- In the case of partial bootstrapping, when one or several vshard groups
    -- are missing, we'll get the error 'Sharding config is empty'.
    -- But if we try bootstrapping the cluster without vshard groups again,
    -- we'll get the error 'Already bootstrapped'
    -- because the config hasn't changed.
    -- So we skip the 'Already bootstrapped' error
    -- if we get 'Sharding config is empty'.
    local skip_already_bootstrapped = false

    if patch.vshard_groups == nil then
        local ok, _err = bootstrap_group('default', patch.vshard)
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
            elseif _err.err == 'Sharding config is empty' then
                table.insert(vars.issues, {
                    level = 'warning',
                    topic = 'vshard',
                    message = ([[Group "%s" wasn't bootstrapped: %s. ]] ..
                        [[There may be no instances in this group.]]):format(name, _err.err),
                })
                log.error(_err)
                skip_already_bootstrapped = true
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

    if skip_already_bootstrapped ~= true and utils.deepcmp(conf, patch) then
        -- Everyting is already bootstrapped
        return nil, e_bootstrap_vshard:new("already bootstrapped")
    end

    local ok, err = twophase.patch_clusterwide(patch)
    if not ok then
        return nil, err
    end

    return true
end

local function get_issues()
    local issues = table.deepcopy(vars.issues)
    if vshard.router.info == nil or not vars.enable_alerting then
        return issues
    end
    for _, alert in ipairs(vshard.router.info().alerts) do
        if alert[2] ~= nil then
            table.insert(issues, {
                level = 'warning',
                topic = 'vshard',
                message = alert[2],
            })
        end
    end
    return issues
end

return {
    role_name = 'vshard-router',
    implies_router = true,

    init = init,
    validate_config = vshard_utils.validate_config,
    apply_config = apply_config,
    stop = stop,
    get_issues = get_issues,

    get = get,
    bootstrap = bootstrap,
    get_alerts = function()
        return vshard and vshard.router and vshard.router.info and vshard.router.info().alerts or {}
    end,
}
