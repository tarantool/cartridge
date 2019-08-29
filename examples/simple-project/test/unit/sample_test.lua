local t = require('luatest')
local g = t.group('unit_sample')

local storage_utils = require('app.roles.storage').utils

require('test.helper.unit')

g.test_update_balance = function()
    t.assertEquals(storage_utils.update_balance("88.95", 0.455), "89.40")
    t.assertEquals(storage_utils.update_balance("88.95", 0.455001), "89.41")

    t.assertEquals(storage_utils.update_balance("-18.99", 1.79), "-17.20")
    t.assertEquals(storage_utils.update_balance("88.95", 1.79), "90.74")
    t.assertEquals(storage_utils.update_balance("0.1", -0.2), "-0.10")
end
