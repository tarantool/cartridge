local clock = require('clock')
local fiber = require('fiber')

local membership = require('membership')

local vars = require('cartridge.vars').new('cartridge.eventloop-speedometer')

vars:new('eventloop_speedometer', nil)
vars:new('eventloop_speed_threshold', 0.5)
vars:new('eventloop_speed_resolution', 0.2)
vars:new('eventloop_speed_measure_every', 5)

local function speedometer(resolution)
    resolution = resolution or 0.2
    local start = clock.monotonic64()
    fiber.sleep(resolution)
    local diff = clock.monotonic64() - start

    local err = (diff - tonumber64(resolution*1e9))/1e9

    return err
end

local function speedometer_fiber()
    fiber.self():name("eventloop-speedometer")
    while true do
        membership.set_payload('slow', nil)

        local slow = false
        for _=1,10 do
            local err = speedometer(vars.eventloop_speed_resolution)
            if err > vars.eventloop_speed_threshold then
                membership.set_payload('slow', true)
                slow = true
                break
            end
        end
        if not slow then
            if membership.myself().payload.slow then
                membership.set_payload('slow', nil)
            end
        end

        fiber.sleep(vars.eventloop_speed_measure_every)
    end
end

local function init()
    assert(vars.eventloop_speedometer == nil)
    vars.eventloop_speedometer = fiber.new(speedometer_fiber)
end

local function deinit()
    if vars.eventloop_speedometer ~= nil then
        if vars.eventloop_speedometer:status() ~= 'dead' then
            vars.eventloop_speedometer:cancel()
        end
    end
end

return {
    init=init,
    deinit=deinit,
}