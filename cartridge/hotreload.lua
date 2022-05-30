local log = require('log')
local fiber = require('fiber')

local vars = require('cartridge.vars').new('cartridge.hotreload')
local service_registry = require('cartridge.service-registry')

vars:new('packages', nil)
vars:new('globals', nil)
vars:new('fibers', nil)
vars:new('routes_count', nil)

--- Snapshot names of all running fibers.
--
-- @function snap_fibers
-- @treturn {string=true,...} Set of fiber names
local function snap_fibers()
    if not vars.fibers then
        return {}
    end

    local ret = {}

    local fiber_info = fiber.info({backtrace = false})
    for _, f in pairs(fiber_info) do
        ret[f.name] = true
    end

    return ret
end

--- Get difference between two snapshots.
-- @function diff
-- @tparam {string=true,...} snap1
-- @tparam {string=true,...} snap2
-- @treturn {string,...} Keys from snap2 that are not in snap1, sorted
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

--- Avoid removing globals with given names.
--
-- @function whitelist_globals
-- @tparam {string,...} names
local function whitelist_globals(tbl)
    if not vars.globals then
        return
    end

    for _, v in ipairs(tbl) do
        log.debug('Avoid removing global %q on hot-reload', v)
        vars.globals[v] = true
    end
end

--- Avoid cancelling fibers with given names.
--
-- Names 'lua', 'main' and '* (net.box)' are ignored and can't be
-- whitelisted.
--
-- @function whitelist_fibers
-- @tparam {string,...} names
local function whitelist_fibers(tbl)
    if not vars.fibers then
        return
    end

    for _, v in ipairs(tbl) do
        if v == 'lua'
        or v == 'main'
        or v:endswith('(net.box)')
        then
            log.debug("Fiber %q can't be whitelisted", v)
        else
            log.debug('Avoid cancelling fiber %q on hot-reload', v)
            vars.fibers[v] = true
        end
    end
end

--- Check that state was saved.
--
-- @function state_saved
-- @treturn boolean true / false
local function state_saved()
    return vars.packages
        and vars.globals
        and vars.fibers
        and vars.routes_count
end

--- Save initial state.
--
-- This includes `package.loaded`, `_G`, fibers, http routes.
--
-- @function save_state
local function save_state()
    vars.packages = table.copy(package.loaded)
    for k, _ in pairs(vars.packages) do
        vars.packages[k] = true
    end

    vars.globals = setmetatable(table.copy(_G), nil)
    for k, _ in pairs(vars.globals) do
        vars.globals[k] = true
    end

    vars.fibers = {}
    whitelist_fibers(diff(vars.fibers, snap_fibers()))

    local httpd = service_registry.get('httpd')
    if httpd ~= nil then
        vars.routes_count = table.maxn(httpd.routes)
    else
        vars.routes_count = 0
    end

    assert(state_saved())
end

--- Restore initial state.
--
-- Unload packages, cancel fibers, remove globals and http routes.
--
-- @function load_state
local function load_state()
    assert(state_saved(), "Hot-reload state wasn't saved")

    for k, _ in pairs(package.loaded) do
        if not vars.packages[k] then
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
        or f.name == 'checkpoint'
        or f.name == 'raft_worker'
        or f.name:startswith('vinyl.')
        or f.name:startswith('vshard.')
        or f.name:startswith('console/')
        or f.name:startswith('applier/')
        or f.name:startswith('applierw/')
        or f.name:startswith('watchdog_')
        or f.name:startswith('box.watchable')
        then
            -- Ignore system fibers
            log.debug('Preserving system fiber %q (%d)', f.name, f.fid)
            goto continue
        end

        if vars.fibers[f.name] then
            log.debug('Preserving whitelisted fiber %q (%d)', f.name, f.fid)
        else
            log.info('Killing fiber %q (%d)', f.name, f.fid)
            fiber.kill(f.fid)
        end

        ::continue::
    end

    local httpd = service_registry.get('httpd')
    if httpd ~= nil then
        for n = table.maxn(httpd.routes), vars.routes_count + 1, -1 do
            local r = httpd.routes[n]
            if r == nil then
                goto continue
            end

            log.info('Removing HTTP route %q (%s)', r.path, r.method)
            if httpd.iroutes[r.name] ~= nil then
                httpd.iroutes[r.name] = nil
            end
            httpd.routes[n] = nil

            ::continue::
        end
    end
end

return {
    diff = diff,
    snap_fibers = snap_fibers,
    whitelist_fibers = whitelist_fibers,
    whitelist_globals = whitelist_globals,

    save_state = save_state,
    load_state = load_state,
    state_saved = state_saved,
}
