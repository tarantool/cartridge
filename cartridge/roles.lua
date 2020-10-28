--- Role management (internal module).
--
-- The module consolidates all the role management functions:
-- `register_role`, some getters, `validate_config` and `apply_config`.
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
local service_registry = require('cartridge.service-registry')

local RegisterRoleError = errors.new_class('RegisterRoleError')
local ValidateConfigError = errors.new_class('ValidateConfigError')
local ApplyConfigError = errors.new_class('ApplyConfigError')

vars:new('by_number', {})
vars:new('by_package', {})
vars:new('by_role_name', {})

local function register_role(ctx, module_name)
    checks({
        by_number = 'table',
        by_package = 'table',
        by_role_name = 'table',
    }, 'string')

    if ctx.by_package[module_name] then
        -- Already loaded
        return ctx.by_package[module_name]
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

    if ctx.by_role_name[role.role_name] ~= nil then
        return nil, RegisterRoleError:new(
            'Role %q name clash between %s and %s',
            role.role_name, module_name,
            ctx.by_role_name[role.role_name].module_name
        )
    end

    ctx.by_package[module_name] = role
    ctx.by_role_name[role.role_name] = role

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

    table.insert(ctx.by_number, role)
    return role
end
utils.assert_upvalues(register_role, {
    'RegisterRoleError',
    'register_role',
    'checks',
    'utils'
})

local function cfg(roles)
    checks('table')
    local ctx = {
        by_number = {},
        by_package = {},
        by_role_name = {},
    }

    local ok, err = register_role(ctx, 'cartridge.roles.coordinator')
    if not ok then
        return nil, err
    end
    for _, role in ipairs(roles or {}) do
        local ok, err = register_role(ctx, role)
        if not ok then
            return nil, err
        end
    end

    vars.by_number = ctx.by_number
    vars.by_package = ctx.by_package
    vars.by_role_name = ctx.by_role_name
    return true
end

local function get_role(role_name)
    checks('string')
    return vars.by_role_name[role_name]
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

    for _, role in ipairs(vars.by_number) do
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

    for _, role in ipairs(vars.by_number) do
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

    for _, role in ipairs(vars.by_number) do
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
            local role = vars.by_role_name[role_name]
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
    local role = vars.by_role_name[role_name]
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

    for _, role in ipairs(vars.by_number) do
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
    for _, role in ipairs(vars.by_number) do
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


return {
    cfg = cfg,
    get_role = get_role,
    get_all_roles = get_all_roles,
    get_known_roles = get_known_roles,
    get_enabled_roles = get_enabled_roles,
    get_role_dependencies = get_role_dependencies,

    validate_config = validate_config,
    apply_config = apply_config,
}
