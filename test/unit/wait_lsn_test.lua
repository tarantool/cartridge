local t = require('luatest')
local g = t.group()

local fiber = require('fiber')
local utils = require('cartridge.utils')
local helpers = require('test.helper')

g.before_all(function()
    helpers.box_cfg()
    box.schema.sequence.create('wait_lsn_test')
end)

function g.test_zero_timeout()
    local id = box.info.id
    local lsn = box.info.lsn

    -- Wait_lsn with zero timeout should never yield
    local csw1 = utils.fiber_csw()
    t.assert_equals(utils.wait_lsn(id, lsn,   0.1, 0), true)
    t.assert_equals(utils.wait_lsn(id, lsn+1, 0.1, 0), false)
    local csw2 = utils.fiber_csw()

    t.assert_equals(csw1, csw2, 'Unnecessary yield')
end

function g.test_timings()
    local id = box.info.id
    local lsn = box.info.lsn

    -- 1. If condition is already met wait_lsn shouldn't yield
    local csw1 = utils.fiber_csw()
    t.assert_equals(utils.wait_lsn(id, lsn, 0.1, 1), true)
    local csw2 = utils.fiber_csw()
    t.assert_equals(csw1, csw2, 'Unnecessary yield')

    -- 2. False result shouldn't return until timeout expires
    local t0 = fiber.time()
    t.assert_equals(utils.wait_lsn(id, lsn+1, 0.1, 0.2), false)
    local t1 = fiber.time()

    helpers.assert_ge(t1-t0, 0.2, 'Too early wake up (wait_lsn == false)')

    -- 3. True result should return asap
    fiber.new(function()
        fiber.sleep(0.2)
        box.sequence.wait_lsn_test:next()
    end)

    local t0 = fiber.time()
    t.assert_equals(utils.wait_lsn(id, lsn+1, 0.01, 1), true)
    local t1 = fiber.time()

    helpers.assert_le(t1-t0, 0.21, 'Too late wake up (wait_lsn == true)')
end

function g.test_absent_lsn()
    -- Unknown (yet) vclock component shouldn't raise
    t.assert_equals(utils.wait_lsn(32, 0, 0.1, 0), true)
    t.assert_equals(utils.wait_lsn(32, 1, 0.1, 0), false)
end
