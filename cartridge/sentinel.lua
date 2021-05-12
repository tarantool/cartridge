local fiber = require('fiber')
local log = require('log')
local vars = require('cartridge.vars').new('cartridge.sentinel')

vars:new('sentinel_fiber')
vars:new('alpha', 0.5)
vars:new('warning_period', 0)
vars:new('checkpoint')
vars:new('min_duration', 0.005)

vars:new('fibers_info', {})

local function sentinel_routine()
    fiber.self():name('sentinel')
    local ema_duration = fiber.clock() - vars.checkpoint
    local emvar_duration = 0

    while true do
        local now = fiber.clock()
        local duration = now - vars.checkpoint
        local treshold = ema_duration + 3 * math.sqrt(emvar_duration)
        local delta = duration - ema_duration

        if duration < vars.min_duration then
            goto yield
        end

        if ema_duration == 0 then
            ema_duration = now - vars.checkpoint
            goto yield
        end

        if emvar_duration == 0 then
            goto step
        end

        if duration > treshold then
            log.warn('Too long event loop %.2f us (avg %.2f us, std %.2f)',
                duration * 1000000, ema_duration * 1000000, math.sqrt(emvar_duration) * 1000000)
            goto yield
        end

        ::step::
        ema_duration = ema_duration + vars.alpha * delta;
        emvar_duration = (1 - vars.alpha) * emvar_duration + vars.alpha * delta * delta;

        ::yield::
        vars.checkpoint = now
        fiber.yield()
    end
end

local function start_sentinel()
    if vars.sentinel_fiber == nil then
        vars.checkpoint = fiber.clock()
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
