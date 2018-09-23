#!/usr/bin/env tarantool

-- this file is used for development purposes only
-- during rock installation it is replaced
-- with constant table { ['filename.ext'] = 'content' }

local log = require('log')
local fio = require('fio')
local utils = require('cluster.utils')

local function __index(self, key)
    local path = fio.pathjoin('webui/build', key)
    local content, err = utils.file_read(path)
    if not content then
        log.error('%s', err)
        return nil
    end

    return content
end

return setmetatable({}, {__index = __index})
