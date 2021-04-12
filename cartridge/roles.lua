--- Role management (internal module).
--
-- The module consolidates all the role management functions:
-- `cfg`, some getters, `validate_config` and `apply_config`.
--
-- The module is almost stateless, it's only state is a collection of
-- registered roles.
--
-- (**Added** in v1.2.0-20)
--
-- @module cartridge.roles
-- @local

local log = require('log')
local checks = require('checks')
local errors = require('errors')

local vars = require('cartridge.vars').new('cartridge.roles')
local utils = require('cartridge.utils')
local hotreload = require('cartridge.hotreload')
local service_registry = require('cartridge.service-registry')

local RegisterRoleError = errors.new_class('RegisterRoleError')
local ValidateConfigError = errors.new_class('ValidateConfigError')
local ApplyConfigError = errors.new_class('ApplyConfigError')
local ReloadError = errors.new_class('HotReloadError')

vars:new('module_names')
vars:new('roles_by_number', {})
vars:new('roles_by_role_name', {})
vars:new('roles_by_module_name', {})
vars:new('implicit_roles')

-- Don't put it as default var value to allow overriding
-- after hot-reload (hypothetically)
vars.implicit_roles = {
    'cartridge.roles.ddl-manager',
    'cartridge.roles.coordinator',
}

-- Register Lua module as a Cartridge Role.
-- Role registration implies requiring the module and all its
-- dependencies. Role names must be unique, and there must be no
-- circular dependencies.
local function register_role(ctx, module_name)
    checks({
        roles_by_number = 'table',
        roles_by_role_name = 'table',
        roles_by_module_name = 'table',
    }, 'string')

    if ctx.roles_by_module_name[module_name] then
        -- Already loaded
        return ctx.roles_by_module_name[module_name]
    end

    local M, err = RegisterRoleError:pcall(require, module_name)
    if err ~= nil then
        return nil, err
    elseif type(M) ~= 'table' then
        return nil, RegisterRoleError:new(
            'Module %q must return a table, got %s', module_name, type(M)
        )
    end

    local role = {
        M = M,
        deps = {},
        role_name = M.role_name or module_name,
        module_name = module_name,
    }

    if type(role.role_name) ~= 'string' then
        return nil, RegisterRoleError:new(
            'Module %q role_name must be a string, got %s',
            module_name, type(role.role_name)
        )
    end

    local dependencies = M.dependencies or {}
    if type(dependencies) ~= 'table' then
        return nil, RegisterRoleError:new(
            'Module %q dependencies must be a table, got %s',
            module_name, type(dependencies)
        )
    end

    if ctx.roles_by_role_name[role.role_name] ~= nil then
        return nil, RegisterRoleError:new(
            'Role %q name clash between %s and %s',
            role.role_name, module_name,
            ctx.roles_by_role_name[role.role_name].module_name
        )
    end

    ctx.roles_by_module_name[module_name] = role
    ctx.roles_by_role_name[role.role_name] = role

    for _, dep in ipairs(dependencies) do
        local dep_role, err = register_role(ctx, dep)
        if not dep_role then
            return nil, err
        end

        if not utils.table_find(role.deps, dep_role) then
            table.insert(role.deps, dep_role)
        end

        -- Inherit subdependencies
        for _, subdep in ipairs(dep_role.deps) do
            if not utils.table_find(role.deps, subdep) then
                table.insert(role.deps, subdep)
            end
        end
    end

    if utils.table_find(role.deps, role) then
        return nil, RegisterRoleError:new(
            'Module %q circular dependency prohibited', module_name
        )
    end

    table.insert(ctx.roles_by_number, role)
    return role
end
utils.assert_upvalues(register_role, {
    'RegisterRoleError',
    'register_role',
    'checks',
    'utils'
})

--- Load modules and register them as Cartridge Roles.
--
-- This function is internal, it's called as a part of `cartridge.cfg`.
--
-- @function cfg
-- @local
-- @tparam {string,...} module_names
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function cfg(module_names)
    checks('table')
    local ctx = {
        roles_by_number = {},
        roles_by_role_name = {},
        roles_by_module_name = {},
    }

    vars.module_names = table.copy(module_names)

    for _, role in ipairs(vars.implicit_roles) do
        local ok, err = register_role(ctx, role)
        if not ok then
            return nil, err
        end
    end

    for _, role in ipairs(module_names or {}) do
        local ok, err = register_role(ctx, role)
        if not ok then
            return nil, err
        end
    end

    vars.roles_by_number = ctx.roles_by_number
    vars.roles_by_role_name = ctx.roles_by_role_name
    vars.roles_by_module_name = ctx.roles_by_module_name
    return true
end

local function get_role(role_name)
    checks('string')
    local role = vars.roles_by_role_name[role_name]
    return role and role.M
end

--- List all registered roles.
--
-- Hidden and permanent roles are listed too.
--
-- @function get_all_roles
-- @local
-- @treturn {string,..}
local function get_all_roles()
    local ret = {}

    for _, role in ipairs(vars.roles_by_number) do
        table.insert(ret, role.role_name)
    end

    return ret
end

--- List registered roles names.
--
-- Hidden roles are not listed as well as permanent ones.
--
-- @function get_known_roles
-- @local
-- @treturn {string,..}
local function get_known_roles()
    local ret = {}

    for _, role in ipairs(vars.roles_by_number) do
        if not role.M.permanent
        and not role.M.hidden
        then
            table.insert(ret, role.role_name)
        end
    end

    return ret
end

--- Roles to be enabled on the server.
-- This function returns all roles that will be enabled
-- including their dependencies (bot hidden and not)
-- and permanent roles.
--
-- @function get_enabled_roles
-- @local
-- @tparam {string,...}|{[string]=boolean,...} roles
-- @treturn {[string]=boolean,...}
local function get_enabled_roles(roles)
    checks('?table')

    if roles == nil then
        return {}
    end

    local ret = {}

    for _, role in ipairs(vars.roles_by_number) do
        if role.M.permanent then
            ret[role.role_name] = true
        end
    end

    for k, v in pairs(roles) do
        local role_name, enabled
        if type(k) == 'number' and type(v) == 'string' then
            role_name, enabled = v, true
        else
            role_name, enabled = k, v
        end

        if enabled then
            ret[role_name] = true
            local role = vars.roles_by_role_name[role_name]
            if role ~= nil then
                for _, dep_role in ipairs(role.deps) do
                    ret[dep_role.role_name] = true
                end
            end
        end
    end

    return ret
end

--- List role dependencies.
-- Including sub-dependencies.
--
-- @function get_role_dependencies
-- @local
-- @tparam string role_name
-- @treturn {string,..}
local function get_role_dependencies(role_name)
    checks('?string')
    local ret = {}
    local role = vars.roles_by_role_name[role_name]
    for _, dep_role in ipairs(role.deps) do
        if not (dep_role.M.permanent or dep_role.M.hidden) then
            table.insert(ret, dep_role.role_name)
        end
    end

    return ret
end

--- Validate configuration by all roles.
-- @function validate_config
-- @local
-- @tparam table conf_new
-- @tparam table conf_old
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function validate_config(conf_new, conf_old)
    checks('table', 'table')
    if conf_new.__type == 'ClusterwideConfig' then
        local err = "Bad argument #1 to validate_config" ..
            " (table expected, got ClusterwideConfig)"
        error(err, 2)
    end
    if conf_old.__type == 'ClusterwideConfig' then
        local err = "Bad argument #2 to validate_config" ..
            " (table expected, got ClusterwideConfig)"
        error(err, 2)
    end

    for _, role in ipairs(vars.roles_by_number) do
        if type(role.M.validate_config) == 'function' then
            local ok, err = ValidateConfigError:pcall(
                role.M.validate_config, conf_new, conf_old
            )
            if not ok then
                err = err or ValidateConfigError:new(
                    'Role %q method validate_config() returned %s',
                    role.role_name, ok
                )
                return nil, err
            end
        end
    end

    return true
end

--- Apply the role configuration.
-- @function apply_config
-- @local
-- @tparam table conf
-- @tparam table opts
-- @tparam boolean is_master
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function apply_config(conf, opts)
    checks('table', {
        is_master = 'boolean',
    })
    if conf.__type == 'ClusterwideConfig' then
        local err = "Bad argument #1 to apply_config" ..
            " (table expected, got ClusterwideConfig)"
        error(err, 2)
    end

    local my_replicaset = conf.topology.replicasets[box.info.cluster.uuid]

    local err
    local enabled_roles = get_enabled_roles(my_replicaset.roles)
    for _, role in ipairs(vars.roles_by_number) do
        if enabled_roles[role.role_name] then
            -- Start the role
            if (service_registry.get(role.role_name) == nil)
            and (type(role.M.init) == 'function')
            then
                local _, _err = ApplyConfigError:pcall(
                    role.M.init, opts
                )
                if _err ~= nil then
                    if err == nil then
                        err = _err
                    end
                    log.error('%s', _err)
                    goto continue
                end
            end

            service_registry.set(role.role_name, role.M)

            if type(role.M.apply_config) == 'function' then
                local _, _err = ApplyConfigError:pcall(
                    role.M.apply_config, conf, opts
                )
                if _err ~= nil then
                    if err == nil then
                        err = _err
                    end
                    log.error('%s', _err)
                end
            end
        else
            -- Stop the role
            if (service_registry.get(role.role_name) ~= nil)
            and (type(role.M.stop) == 'function')
            then
                local _, _err = ApplyConfigError:pcall(
                    role.M.stop, opts
                )
                if _err ~= nil then
                    if err == nil then
                        err = _err
                    end
                    log.error('%s', _err)
                end
            end

            service_registry.set(role.role_name, nil)
        end

        ::continue::
    end
    log.info('Roles configuration finished')

    if err ~= nil then
        return nil, err
    end
    return true
end

--- Perform hot-reload of cartridge roles code.
--
-- This is an experimental feature, it's only allowed if the application
-- enables it explicitly: `cartridge.cfg({roles_reload_allowed =
-- true})`.
--
-- Reloading starts by stopping all roles and restoring the initial
-- state. It's supposed that a role cleans up the global state when
-- stopped, but even if it doesn't, cartridge kills all fibers and
-- removes global variables and HTTP routes.
--
-- All Lua modules that were loaded during `cartridge.cfg` are unloaded,
-- including supplementary modules required by a role. Modules, loaded
-- before `cartridge.cfg` aren't affected.
--
-- Instance performs roles reload in a dedicated state `ReloadingRoles`.
-- If reload fails, the instance enters the `ReloadError` state, which
-- can later be retried. Otherwise, if reload succeeds, instance
-- proceeds to the `ConfiguringRoles` state and initializes them as
-- usual with `validate_config()`, `init()`, and `apply_config()`
-- callbacks.
--
-- @function reload
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function reload()
    if not hotreload.state_saved() then
        return nil, ReloadError:new(
            'This application forbids reloading roles'
        )
    end

    local confapplier = require('cartridge.confapplier')
    local state = confapplier.get_state()
    if state ~= 'RolesConfigured'
    and state ~= 'ReloadError'
    and state ~= 'OperationError'
    then
        return nil, ReloadError:new('Inappropriate state %q', state)
    end

    local failover = require('cartridge.failover')
    local opts = {is_master = failover.is_leader()}

    log.warn('Reloading roles ...')
    confapplier.set_state('ReloadingRoles')

    for _, role in ipairs(vars.roles_by_number) do
        if (service_registry.get(role.role_name) ~= nil)
        and (type(role.M.stop) == 'function')
        then
            local _, err = ReloadError:pcall(role.M.stop, opts)
            if err ~= nil then
                log.error('%s', err)
            end
        end

        service_registry.set(role.role_name, nil)
    end

    hotreload.load_state()

    -- Collect the garbage from unloaded modules.
    -- Why call it twice? See PiL 3rd edition, §17.6 Finalizers.
    -- Especially for the term "resurrection". 🧟‍ Grr... argh!
    collectgarbage()
    collectgarbage()

    local ok, err = cfg(vars.module_names)
    if ok == nil then
        confapplier.set_state('ReloadError', err)
        return nil, err
    end

    local clusterwide_config = confapplier.get_active_config()
    local ok, err = confapplier.validate_config(clusterwide_config)
    if ok == nil then
        confapplier.set_state('ReloadError', err)
        return nil, err
    end

    log.warn('Roles reloaded successfully')
    confapplier.set_state('BoxConfigured', err)

    return confapplier.apply_config(clusterwide_config)
end

return {
    cfg = cfg,
    get_role = get_role,
    get_all_roles = get_all_roles,
    get_known_roles = get_known_roles,
    get_enabled_roles = get_enabled_roles,
    get_role_dependencies = get_role_dependencies,

    validate_config = validate_config,
    apply_config = apply_config,
    reload = reload,
}
