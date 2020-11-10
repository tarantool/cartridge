local log = require('log')
local fiber = require('fiber')
local checks = require('checks')

local vars = require('cartridge.vars').new('cartridge.hotreload')
local service_registry = require('cartridge.service-registry')

vars:new('packages', nil)
vars:new('globals', nil)
vars:new('routes', nil)
vars:new('fibers', {})

local function snap_fibers()
    local ret = {}

    for _, f in pairs(fiber.info()) do
        ret[f.name] = true
    end

    return ret
end

local function diff(t1, t2)
    local ret = {}
    for k, _ in pairs(t2) do
        if not t1[k] then
            table.insert(ret, k)
        end
    end

    table.sort(ret)
    return ret
end

local function save_state()
    if vars.packages == nil then
        vars.packages = table.copy(package.loaded)
        for k, _ in pairs(vars.packages) do
            vars.packages[k] = true
        end
    end

    if vars.globals == nil then
        vars.globals = setmetatable(table.copy(_G), nil)
        for k, _ in pairs(vars.globals) do
            vars.globals[k] = true
        end
    end

    if vars.routes == nil then
        local httpd = service_registry.get('httpd')
        vars.routes = #httpd.routes
    end
end

local function load_state()
    for k, _ in pairs(package.loaded) do
        if not vars.packages[k] then
            -- log.info('Unloading package %q', k)
            package.loaded[k] = nil
        end
    end

    for k, _ in pairs(_G) do
        if not vars.globals[k] then
            log.info('Unsetting global %q', k)
            _G[k] = nil
        end
    end

    local fiber_info = fiber.info()
    for _, f in pairs(fiber_info) do
        if f.fid == fiber.id() then
            -- don't kill self
            goto continue
        end

        if f.fid == 101
        or f.name == 'on_shutdown'
        or f.name:startswith('console/')
        or f.name:startswith('applier/')
        or f.name:startswith('applierw/')
        then
            -- Ignore system fibers
            log.info('Preserving system fiber %q (%d)', f.name, f.fid)
            goto continue
        end

        if vars.fibers[f.name] then
            log.info('Preserving whitelisted fiber %q (%d)', f.name, f.fid)
        else
            log.info('Killing fiber %q (%d)', f.name, f.fid)
            fiber.kill(f.fid)
        end

        ::continue::
    end

    local httpd = service_registry.get('httpd')
    if httpd ~= nil then
        for n = #httpd.routes, vars.routes + 1, -1 do
            local r = httpd.routes[n]
            log.info('Removing HTTP route %q (%s)', r.path, r.method)
            if httpd.iroutes[r.name] ~= nil then
                httpd.iroutes[r.name] = nil
            end
            httpd.routes[n] = nil
        end
    end
end

local function whitelist_globals(tbl)
    checks('table')
    for _, v in ipairs(tbl) do
        log.debug('Avoid hot-reloading global %q', v)
        vars.globals[v] = true
    end
end

local function whitelist_fibers(tbl)
    checks('table')
    for _, v in ipairs(tbl) do
        if v == 'lua'
        or v:endswith('(net.box)')
        then
            log.debug('Refusing to whitelist fiber %q', v)
        else
            log.debug('Avoid hot-reloading fiber %q', v)
            vars.fibers[v] = true
        end
    end
end

return {
    save_state = save_state,
    load_state = load_state,

    snap_fibers = snap_fibers,
    diff = diff,

    whitelist_fibers = whitelist_fibers,
    whitelist_globals = whitelist_globals,
}
