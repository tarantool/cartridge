--- Class to run and manage stateboard.
--
-- @classmod cartridge.test-helpers.stateboard

local luatest = require('luatest')
local log = require('log')

--- Build stateboard object.
-- @function new
-- @param object
-- @string object.name Human-readable node name.
-- @string object.command Command to run stateboard.
-- @string object.workdir Path to the data directory.
-- @string object.net_box_port Value to be passed in `TARANTOOL_LISTEN` and used for net_box connection.
-- @tab[opt] object.net_box_credentials Override default net_box credentials.
-- @tab[opt] object.env Environment variables passed to the process.
-- @return object
local Stateboard = luatest.Server:inherit({})

-- Start stateboard
function Stateboard:start()
    getmetatable(getmetatable(self)).start(self)
end

-- Stop stateboard
function Stateboard:stop()
    local process = self.process
    if process == nil then
        return
    end
    getmetatable(getmetatable(self)).stop(self)
    luatest.helpers.retrying({}, function()
        luatest.assert_not(
            process:is_alive(),
            string.format('Process %s is still running', self.alias)
        )
    end)
    log.warn('Process %s killed', self.alias)
end

return Stateboard
