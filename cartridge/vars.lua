-- luacheck: globals box

local checks = require('checks')

if rawget(_G, "_cluster_vars_defaults") == nil then
    _G._cluster_vars_defaults = {}
end

if rawget(_G, "_cluster_vars_values") == nil then
    _G._cluster_vars_values = {}
end

local function new_var(self, name, default_value)
    checks("vars", "string", "?")

    local defaults = _G._cluster_vars_defaults

    if defaults[self.module_name] == nil then
        defaults[self.module_name] = {}
    end

    defaults[self.module_name][name] = default_value
end

local function set_var(self, name, value)
    checks("vars", "string", "?")

    local vars = _G._cluster_vars_values

    local module_vars = vars[self.module_name]
    if module_vars == nil then
        vars[self.module_name] = {}
        module_vars = vars[self.module_name]
    end

    module_vars[name] = value
end

local function get_var(self, name)
    checks("vars", "string")

    local vars = _G._cluster_vars_values

    if vars[self.module_name] ~= nil then
        local res = vars[self.module_name][name]
        if res ~= nil then
            return res
        end
    else
        vars[self.module_name] = {}
    end

    local defaults = _G._cluster_vars_defaults

    if defaults[self.module_name] == nil then
        defaults[self.module_name] = {}
    end

    local default_value = defaults[self.module_name][name]

    if type(default_value) == 'table' then
        vars[self.module_name][name] = table.deepcopy(default_value)
    else
        vars[self.module_name][name] = default_value
    end

    return vars[self.module_name][name]
end


local function new(module_name)
    checks("string")

    return setmetatable({
        module_name = module_name,
        new = new_var,
    }, {
        __type = 'vars',
        __newindex = set_var,
        __index = get_var,
    })
end

local function list()
end

return {
    new = new,
    list = list,
}
