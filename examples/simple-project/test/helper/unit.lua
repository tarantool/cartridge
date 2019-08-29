local t = require('luatest')

local shared = require('test.helper')

local helper = {shared = shared}

t.before_suite(function() box.cfg({work_dir = shared.datadir}) end)

return helper
