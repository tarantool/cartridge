local fio = require('fio')
local t = require('luatest')

local helper = {}

helper.root = fio.dirname(fio.abspath(package.search('cluster')))
helper.datadir = fio.pathjoin(helper.root, 'dev', 'db_test')
helper.server_command = fio.pathjoin(helper.root, 'test', 'integration', 'instance.lua')

t.before_suite(function() fio.rmtree(helper.datadir) end)

return helper
