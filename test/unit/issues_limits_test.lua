#!/usr/bin/env tarantool

local t = require('luatest')
local g = t.group()

local issues = require("cartridge.issues")

function g.test_positive()
    local function check_ok(limits)
        return t.assert_equals(
            {issues.validate_limits(limits)},
            {true, nil}
        )
    end

    check_ok({})
    check_ok(issues.default_limits)

    check_ok({clock_delta_threshold_warning = 0})
    check_ok({clock_delta_threshold_warning = math.huge})

    check_ok({fragmentation_threshold_warning = 0})
    check_ok({fragmentation_threshold_warning = 1})

    check_ok({fragmentation_threshold_critical = 0})
    check_ok({fragmentation_threshold_critical = 1})

    check_ok({fragmentation_threshold_full = 0})
    check_ok({fragmentation_threshold_full = 1})
end

function g.test_negative()
    local function check_error(limits, err_expected)
        local ok, err = issues.validate_limits(limits)
        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = "ValidateConfigError",
            err = err_expected,
        })
    end

    local nan = 0/0
    assert(nan ~= nan)

    check_error(0,        'limits must be a table, got number')
    check_error(nil,      'limits must be a table, got nil')
    check_error(box.NULL, 'limits must be a table, got cdata')

    check_error({{}},       'limits table keys must be string, got number')
    check_error({[{}] = 1}, 'limits table keys must be string, got table')

    check_error({unknown_limit = 0}, 'unknown limits key "unknown_limit"')

    -- clock_delta_threshold_warning
    check_error(
        {clock_delta_threshold_warning = 'yes'},
        'limits.clock_delta_threshold_warning must be a number, got string'
    )
    check_error(
        {clock_delta_threshold_warning = 12ULL},
        'limits.clock_delta_threshold_warning must be a number, got cdata'
    )
    check_error(
        {clock_delta_threshold_warning = -1e-7},
        'limits.clock_delta_threshold_warning must be in range [0, inf]'
    )
    check_error(
        {clock_delta_threshold_warning = nan},
        'limits.clock_delta_threshold_warning must be in range [0, inf]'
    )

    -- fragmentation_threshold_warning
    check_error(
        {fragmentation_threshold_warning = 0 - 1e-7},
        'limits.fragmentation_threshold_warning must be in range [0, 1]'
    )
    check_error(
        {fragmentation_threshold_warning = 1 + 1e-7},
        'limits.fragmentation_threshold_warning must be in range [0, 1]'
    )

    -- fragmentation_threshold_critical
    check_error(
        {fragmentation_threshold_critical = 0 - 1e-7},
        'limits.fragmentation_threshold_critical must be in range [0, 1]'
    )
    check_error(
        {fragmentation_threshold_critical = 1 + 1e-7},
        'limits.fragmentation_threshold_critical must be in range [0, 1]'
    )

    check_error(
        {fragmentation_threshold_full = 0 - 1e-7},
        'limits.fragmentation_threshold_full must be in range [0, 1]'
    )
    check_error(
        {fragmentation_threshold_full = 1 + 1e-7},
        'limits.fragmentation_threshold_full must be in range [0, 1]'
    )
end
