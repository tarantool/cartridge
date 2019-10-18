#!/usr/bin/env tarantool

local vars = require('cartridge.vars').new('cartridge.box-atomic')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')

vars:new('lock', false)
vars:new('cond', fiber.cond())

local AtomicCallError = errors.new_class('AtomicCallError')
local BoxError = errors.new_class('BoxError', {log_on_creation = true})

local function cfg(cfg, opts)
    checks('table', {
        timeout = '?number',
    })

    if vars.lock then
        local timeout = opts and opts.timeout
        if timeout == nil then
            while vars.lock do
                vars.cond:wait()
            end
        elseif timeout > 0 then
            local deadline = fiber.time() + timeout
            while vars.lock and fiber.time() < deadline do
                vars.cond:wait(deadline - fiber.time())
            end
        end
    end

    if vars.lock then
        return nil, AtomicCallError:new(
            'box.cfg() is already running'
        )
    end

    vars.lock = true
    local _, err = BoxError:pcall(box.cfg, cfg)
    vars.lock = false
    vars.cond:signal()

    if err ~= nil then
        return nil, err
    end
    return true
end

return {
    cfg = cfg,
}