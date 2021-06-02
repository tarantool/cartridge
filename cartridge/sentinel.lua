local fiber = require('fiber')
local log = require('log')
local vars = require('cartridge.vars').new('cartridge.sentinel')

vars:new('sentinel_fiber')

vars:new('evloop_treshold', 0.005)
vars:new('sleep_delta_treshold', 0.01)
vars:new('sleep_duration', 0.05)

local function sentinel_routine()
    fiber.self():name('sentinel')

    local now
    local checkpoint = fiber.clock()

    while true do
        fiber.sleep(vars.sleep_duration)
        now = fiber.clock()

        local sleep_limit = checkpoint + vars.sleep_duration
        local sleep_delta = now - sleep_limit

        if sleep_delta > vars.sleep_delta_treshold then
            log.warn('Too long sleep: %.5f (expected %.5f)', now - checkpoint, vars.sleep_duration)
        end

        -- mesure single event loop duration
        checkpoint = fiber.clock()
        fiber.sleep(0)
        now = fiber.clock()

        local evloop_duration = now - checkpoint
        if evloop_duration > vars.evloop_treshold then
            log.warn('Too long event loop: %.5f', evloop_duration)
        end

        checkpoint = fiber.clock()
    end
end

local function start_sentinel()
    if vars.sentinel_fiber == nil then
        vars.sentinel_fiber = fiber.create(sentinel_routine, {})
    end
end

local function stop_sentinel()
    if vars.sentinel_fiber ~= nil then
        pcall(function() vars.sentinel_fiber:kill() end)
        vars.sentinel_fiber = nil
    end
end

return {
    start = start_sentinel,
    stop = stop_sentinel,
}
