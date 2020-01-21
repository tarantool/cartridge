#!/usr/bin/env tarantool

local log = require('log')
local checks = require('checks')
local errors = require('errors')

local vars = require('cartridge.vars').new('cartridge.roles.extensions')

local EvalError = errors.new_class('EvalError')

vars:new('loaded', {
    -- [module_name] = loadstring(module_name),
})

local function get(module_name)
    checks('string')
    return vars.loaded[module_name]
end

local function validate_config()
    -- TODO
    return true
end

local function apply_config(conf)
    checks('table')

    vars.loaded = {}

    for section, content in pairs(conf) do
        local mod_name = section:match('^extensions/(.+)%.lua$')
        if not mod_name then
            goto continue
        end

        local mod_fn, err = loadstring(content, section)
        if mod_fn == nil then
            return nil, EvalError:new('%s: %s', section, err)
        end

        local mod, err = EvalError:pcall(mod_fn)
        if mod == nil then
            return nil, err
        end

        vars.loaded[mod_name] = mod

        ::continue::
    end

    local extensions_cfg = conf['extensions/config'] or {}
    local functions = extensions_cfg.functions
    if functions == nil then
        functions = {}
    end

    for _, fconf in pairs(functions) do
        local handler = vars.loaded[fconf.module][fconf.handler]

        for _, event in ipairs(fconf.events) do
            if event.binary then
                rawset(_G, event.binary.path, handler)
            end
        end
    end
end

return {
    role_name = 'extensions',
    validate_config = validate_config,
    apply_config = apply_config,

    get = get,
}
