local checks = require('checks')
local errors = require('errors')

local e_funcall = errors.new_class("Funcall failed")

local function call(function_name, ...)
    checks('string')

    local mod_name, fun_name = string.match(function_name, '^(.+)%.(.-)$')

    if (mod_name == nil) or (fun_name == nil) then
        return nil, e_funcall:new(
            'funcall.call() expects function_name' ..
            ' to contain module name. Got: %q', function_name
        )
    end

    local mod = package.loaded[mod_name]
    if mod == nil then
        return nil, e_funcall:new(
            'Can not find module %q', mod_name
        )
    end

    local fun = mod[fun_name]
    if fun == nil then
        return nil, e_funcall:new(
            'No function %q in module %q', fun_name, mod_name
        )
    end

    return fun(...)
end

return {
    call = call,
}
