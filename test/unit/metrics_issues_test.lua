-- luacheck: no max comment line length

-- Based on
-- https://github.com/tarantool/metrics/blob/eb35baf54f687c559420bef020e7a8a1fee57132/test/unit/cartridge_issues_test.lua

local helpers = require('test.helper')

local t = require('luatest')
local g = t.group()

g.before_all(function()
    local is_metrics_provided = pcall(require, 'metrics')
    t.skip_if(not is_metrics_provided, "metrics not installed")
end)

g.test_cartridge_issues_before_cartridge_cfg = function()
    t.skip_if(helpers.is_metrics_version_less('0.11.0'), "Not supported in metrics")

    require('cartridge.issues')
    local issues = require('metrics.cartridge.issues')
    local ok, error = pcall(issues.update)
    t.assert(ok, error)
end
