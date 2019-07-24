local fio = require('fio')
local t = require('luatest')

local helper = {}

helper.root = fio.dirname(fio.abspath(package.search('cluster')))
helper.server_command = fio.pathjoin(helper.root, 'test', 'integration', 'srv_basic.lua')

return helper
