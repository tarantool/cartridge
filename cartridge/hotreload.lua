local vars = require('cartridge.vars').new('cartridge.hotreload')
local service_registry = require('cartridge.service-registry')

local function save_state()
    --- Killing fibers isn't appropriate:
    -- vshard doesn't endorse fibers death
    -- fiber may be processing a request (http/iproto)
    --
    -- vars.fibers = fiber.info()
    -- for k, _ in pairs(vars.fibers) do
    --     vars.fibers[k] = true
    -- end

    --- Cleaning globals isn't good
    -- vshard and other modules persist there their internals.
    --
    -- vars.globals = setmetatable(table.copy(_G), nil)
    -- for k, _ in pairs(vars.globals) do
    --     vars.globals[k] = true
    -- end

    vars.packages = table.copy(package.loaded)
    for k, _ in pairs(vars.packages) do
        vars.packages[k] = true
    end

    local httpd = service_registry.get('httpd')
    vars.routes = #httpd.routes
end

local function load_state()
    for k, _ in pairs(package.loaded) do
        if not vars.packages[k] then
            package.loaded[k] = nil
        end
    end

    local httpd = service_registry.get('httpd')
    for n = #httpd.routes, vars.routes + 1, -1 do
        local r = httpd.routes[n]
        if httpd.iroutes[r.name] ~= nil then
            httpd.iroutes[r.name] = nil
        end
        httpd.routes[n] = nil
    end
end

return {
    save_state = save_state,
    load_state = load_state,
}
