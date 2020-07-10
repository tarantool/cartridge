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
local topology = require('cartridge.topology')
local service_registry = require('cartridge.service-registry')

local RegisterRoleError = errors.new_class('RegisterRoleError')
local ValidateConfigError = errors.new_class('ValidateConfigError')
local ApplyConfigError = errors.new_class('ApplyConfigError')

vars:new('known_roles', {
    -- [i] = mod,
    -- [role_name] = mod,
})
vars:new('roles_dependencies', {
    -- [role_name] = {role_name_1, role_name_2}
})
vars:new('roles_dependants', {
    -- [role_name] = {role_name_1, role_name_2}
})


local function register_role(module_name)
    checks('string')
    local function e(...)
        vars.known_roles = {}
        vars.roles_dependencies = {}
        vars.roles_dependants = {}
        return RegisterRoleError:new(2, ...)
    end
    local mod = package.loaded[module_name]
    if type(mod) == 'table' and vars.known_roles[mod.role_name] then
        -- Already loaded
        return mod
    end

    local mod, err = RegisterRoleError:pcall(require, module_name)
    if not mod then
        return nil, e(err)
    elseif type(mod) ~= 'table' then
        return nil, e('Module %q must return a table', module_name)
    end

    if mod.role_name == nil then
        mod.role_name = module_name
    end

    if type(mod.role_name) ~= 'string' then
        return nil, e('Module %q role_name must be a string', module_name)
    end

    if vars.known_roles[mod.role_name] ~= nil then
        return nil, e('Role %q name clash', mod.role_name)
    end

    local dependencies = mod.dependencies or {}
    if type(dependencies) ~= 'table' then
        return nil, e('Module %q dependencies must be a table', module_name)
    end

    vars.roles_dependencies[mod.role_name] = {}
    vars.roles_dependants[mod.role_name] = {}
    vars.known_roles[mod.role_name] = mod

    local function deps_append(tbl, deps)
        for _, dep in pairs(deps) do
            if not utils.table_find(tbl, dep) then
                table.insert(tbl, dep)
            end
        end
    end

    for _, dep_name in ipairs(dependencies) do
        local dep_mod, err = register_role(dep_name)
        if not dep_mod then
            return nil, err
        end

        deps_append(
            vars.roles_dependencies[mod.role_name],
            {dep_mod.role_name}
        )
        deps_append(
            vars.roles_dependencies[mod.role_name],
            vars.roles_dependencies[dep_mod.role_name]
        )

        deps_append(
            vars.roles_dependants[dep_mod.role_name],
            {mod.role_name}
        )
    end

    if utils.table_find(vars.roles_dependencies[mod.role_name], mod.role_name) then
        return nil, e('Module %q circular dependency not allowed', module_name)
    end
    topology.add_known_role(mod.role_name)
    vars.known_roles[#vars.known_roles+1] = mod

    return mod
end

local function get_role(role_name)
    checks('string')
    return vars.known_roles[role_name]
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

    for _, mod in ipairs(vars.known_roles) do
        table.insert(ret, mod.role_name)
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

    for _, mod in ipairs(vars.known_roles) do
        if not (mod.permanent or mod.hidden) then
            table.insert(ret, mod.role_name)
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

    for _, mod in ipairs(vars.known_roles) do
        if mod.permanent then
            ret[mod.role_name] = true
        end
    end

    for k, v in pairs(roles) do
        local role_name, enabled
        if type(k) == 'number' and type(v) == 'string' then
            role_name, enabled = v, true
        else
            role_name, enabled = k, v
        end

        repeat -- until true
            if not enabled then
                break
            end

            ret[role_name] = true

            local deps = vars.roles_dependencies[role_name]
            if deps == nil then
                break
            end

            for _, dep_name in ipairs(deps) do
                ret[dep_name] = true
            end
        until true
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

    for _, dep_name in ipairs(vars.roles_dependencies[role_name]) do
        local mod = vars.known_roles[dep_name]
        if not (mod.permanent or mod.hidden) then
            table.insert(ret, mod.role_name)
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

    for _, mod in ipairs(vars.known_roles) do
        if type(mod.validate_config) == 'function' then
            local ok, err = ValidateConfigError:pcall(
                mod.validate_config, conf_new, conf_old
            )
            if not ok then
                err = err or ValidateConfigError:new(
                    'Role %q method validate_config() returned %s',
                    mod.role_name, ok
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
    for _, mod in ipairs(vars.known_roles) do
        local role_name = mod.role_name
        if enabled_roles[role_name] then
            -- Start the role
            if (service_registry.get(role_name) == nil)
            and (type(mod.init) == 'function')
            then
                local _, _err = ApplyConfigError:pcall(
                    mod.init, opts
                )
                if _err ~= nil then
                    if err == nil then
                        err = _err
                    else
                        log.error('%s', _err)
                    end
                    goto continue
                end
            end

            service_registry.set(role_name, mod)

            if type(mod.apply_config) == 'function' then
                local _, _err = ApplyConfigError:pcall(
                    mod.apply_config, conf, opts
                )
                if _err ~= nil then
                    if err == nil then
                        err = _err
                    else
                        log.error('%s', _err)
                    end
                end
            end
        else
            -- Stop the role
            if (service_registry.get(role_name) ~= nil)
            and (type(mod.stop) == 'function')
            then
                local _, _err = ApplyConfigError:pcall(
                    mod.stop, opts
                )
                if _err ~= nil then
                    if err == nil then
                        err = _err
                    else
                        log.error('%s', _err)
                    end
                end
            end

            service_registry.set(role_name, nil)
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
    register_role = register_role,
    get_role = get_role,
    get_all_roles = get_all_roles,
    get_known_roles = get_known_roles,
    get_enabled_roles = get_enabled_roles,
    get_role_dependencies = get_role_dependencies,

    validate_config = validate_config,
    apply_config = apply_config,
}
