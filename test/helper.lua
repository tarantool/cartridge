local fio = require('fio')
local t = require('luatest')

local helper = {}

helper.root = fio.dirname(fio.abspath(package.search('cartridge')))
helper.server_command = fio.pathjoin(helper.root, 'test', 'integration', 'srv_basic.lua')

function helper.table_find_by_attr(tbl, key, value)
    for _, v in pairs(tbl) do
        if v[key] == value then
            return v
        end
    end
end

return helper
