#!/usr/bin/env tarantool

local log = require('log')
local checks = require('checks')
local errors = require('errors')

local vars = require('cartridge.vars').new('cartridge.roles.extensions')

local RequireExtensionError = errors.new_class('RequireExtensionError')
local ExtensionConfigError = errors.new_class('ExtensionConfigError')

vars:new('loaded', {})
vars:new('exports', {})

local function process_config(conf)
    checks('table')
    local ret = {
        loaded = {},
        exports = {},
    }

    local not_loaded = {}
    local _ENV = table.copy(_G)

    _ENV.require = function(mod_name)
        if type(mod_name) ~= 'string' then
            error(string.format(
                "bad argument #1 to 'require' (string expected, got %s)",
                type(mod_name)
            ), 2)
        elseif not mod_name:startswith('extensions.') then
            -- don't interfere modules outside extensions folder
            return require(mod_name)
        end

        if ret.loaded[mod_name] == not_loaded then
            error(string.format(
                "loop or previous error loading module '%s'",
                mod_name
            ), 2)
        elseif ret.loaded[mod_name] ~= nil then
            return ret.loaded[mod_name]
        end

        local section = string.gsub(mod_name, '%.', '/') .. '.lua'
        local content = conf[section]
        if type(content) ~= 'string' then
            error(string.format(
                "module '%s' not found:\n\tno section '%s' in config",
                mod_name, section
            ), 2)
        end

        local mod_fn, err = loadstring(content, '@' .. section)
        if mod_fn == nil then
            error(err, 2)
        end

        ret.loaded[mod_name] = not_loaded
        setfenv(mod_fn, _ENV)

        local mod = mod_fn()
        if type(mod) == 'nil' then
            mod = true
        end

        ret.loaded[mod_name] = mod
        return mod
    end

    for section, _ in pairs(conf) do
        local name = section:match('^(extensions/.+)%.lua$')
        if name ~= nil then
            local _, err = RequireExtensionError:pcall(
                _ENV.require, string.gsub(name, '/', '.')
            )

            if err ~= nil then
                return nil, err
            end
        end
    end

    local extensions_cfg = conf['extensions/config'] or {}
    local functions = extensions_cfg.functions
    if type(functions) == 'nil' then
        functions = {}
    elseif type(functions) ~= 'table' then
        return nil, ExtensionConfigError:new(
            "Invalid extensions config: bad field" ..
            " functions (table expected, got %s)",
            type(functions)
        )
    end

    for fname, fconf in pairs(functions) do
        if type(fname) ~= 'string' then
            return nil, ExtensionConfigError:new(
                "Invalid extensions config: bad field" ..
                " functions (table keys must be strings, got %s)",
                type(fname)
            )
        elseif type(fconf) ~= 'table' then
            return nil, ExtensionConfigError:new(
                "Invalid extensions config: bad field" ..
                " functions[%q] (table expected, got %s)",
                fname, type(fconf)
            )
        end

        if type(fconf.module) ~= 'string' then
            return nil, ExtensionConfigError:new(
                "Invalid extensions config: bad field" ..
                " functions[%q].module (string expected, got %s)",
                fname, type(fconf.module)
            )
        elseif type(fconf.handler) ~= 'string' then
            return nil, ExtensionConfigError:new(
                "Invalid extensions config: bad field" ..
                " functions[%q].handler (string expected, got %s)",
                fname, type(fconf.handler)
            )
        elseif type(fconf.events) ~= 'table' then
            return nil, ExtensionConfigError:new(
                "Invalid extensions config: bad field" ..
                " functions[%q].events (table expected, got %s)",
                fname, type(fconf.events)
            )
        end

        local mod = ret.loaded[fconf.module]
        if mod == nil and vars.loaded[fconf.module] == nil then
            mod = package.loaded[fconf.module]
        end
        if mod == nil then
            return nil, ExtensionConfigError:new(
                "Invalid extensions config: " ..
                "no module '%s'" ..
                " to handle function '%s'",
                fconf.module, fname
            )
        end

        local fn = type(mod) == 'table' and mod[fconf.handler]
        if type(fn) ~= 'function' then
            return nil, ExtensionConfigError:new(
                "Invalid extensions config: " ..
                "no function '%s' in module '%s'" ..
                " to handle '%s'",
                fconf.handler, fconf.module, fname
            )
        end

        for _, event in ipairs(fconf.events) do
            if event.binary == nil then
                -- do nothing
            elseif ret.exports[event.binary.path] ~= nil then
                return nil, ExtensionConfigError:new(
                    "Invalid extensions config: " ..
                    "collision of binary event '%s'" ..
                    " to handle function '%s'",
                    event.binary.path, fname
                )
            elseif rawget(_G, event.binary.path) ~= nil
            and vars.exports[event.binary.path] == nil then
                return nil, ExtensionConfigError:new(
                    "Invalid extensions config: " ..
                    "can't override global '%s'" ..
                    " to handle function '%s'",
                    event.binary.path, fname
                )
            else
                ret.exports[event.binary.path] = fn
            end
        end
    end

    return ret
end

local function validate_config(conf_new, _)
    local c, err = process_config(conf_new)
    if c == nil then
        return nil, err
    end

    return true
end

local function apply_config(conf)
    checks('table')

    local c, err = process_config(conf)
    if c == nil then
        return nil, err
    end

    -- cleanup previous
    for mod_name, _ in pairs(vars.loaded) do
        package.loaded[mod_name] = nil
    end
    for fun_name, _ in pairs(vars.exports) do
        rawset(_G, fun_name, nil)
    end

    -- load new extensions
    for mod_name, mod in pairs(c.loaded) do
        package.loaded[mod_name] = mod
    end
    for fun_name, fun in pairs(c.exports) do
        rawset(_G, fun_name, fun)
    end

    vars.loaded = c.loaded
    vars.exports = c.exports
end

return {
    role_name = 'extensions',
    validate_config = validate_config,
    apply_config = apply_config,
}
