--- Class to run and manage etcd node.
--
-- @classmod cartridge.test-helpers.etcd

local checks = require('checks')
local log = require('log')
local fun = require('fun')
local httpc = require('http.client')

local luatest = require('luatest')
local Process = require('luatest.process')

-- Defaults.
local Etcd = {
    workdir = nil,
    etcd_path = nil,
    name = 'default',
    peer_url = 'http://127.0.0.1:17001',
    client_url = 'http://127.0.0.1:14001',
    args = {},
    env = {},
}

function Etcd:inherit(object)
    setmetatable(object, self)
    self.__index = self
    return object
end

--- Build etcd node object.
-- @param object
-- @string object.name Human-readable node name.
-- @string object.workdir Path to the data directory.
-- @string object.etcd_path Path to the etcd executable.
-- @string object.peer_url URL to listen on for peer traffic.
-- @string object.client_url URL to listen on for client traffic.
-- @tab[opt] object.env Environment variables passed to the process.
-- @tab[opt] object.args Command-line arguments passed to the process.
-- @return object
function Etcd:new(object)
    checks('table', {
        name = '?string',
        workdir = 'string',
        etcd_path = 'string',
        peer_url = '?string',
        client_url = '?string',
        args = '?table',
        env = '?table',
    })
    self:inherit(object)
    object:initialize()
    return object
end

function Etcd:initialize()
    self.env = fun.chain({
        ETCD_NAME = self.name,
        ETCD_DATA_DIR = self.workdir,
        ETCD_LISTEN_PEER_URLS = self.peer_url,
        ETCD_LISTEN_CLIENT_URLS = self.client_url,
        ETCD_ADVERTISE_CLIENT_URLS = self.client_url,
    }, self.env):tomap()
end

--- Start the node.
function Etcd:start()
    local log_cmd = {}
    for k, v in pairs(self.env) do
        table.insert(log_cmd, string.format('%s=%q', k, v))
    end
    table.insert(log_cmd, self.command)
    for _, v in ipairs(self.args) do
        table.insert(log_cmd, string.format('%q', v))
    end

    log.debug(table.concat(log_cmd, ' '))

    self.process = Process:start(self.etcd_path, self.args, self.env, {
        output_prefix = 'etcd-' .. self.name,
    })
    log.debug('Started server PID: ' .. self.process.pid)

    luatest.helpers.retrying({}, function()
        local resp = httpc.put(self.client_url .. '/v2/keys/hello?value=world')
        luatest.assert(resp.status == 200, resp.body)
    end)

    log.info(httpc.get(self.client_url .. '/version').body)
end

--- Stop the node.
function Etcd:stop()
    local process = self.process
    if process == nil then
        return
    end
    self.process:kill()
    luatest.helpers.retrying({}, function()
        luatest.assert_not(process:is_alive(),
            'etcd-%s is still running', self.name
        )
    end)
    log.warn('etcd-%s killed', self.name)
    self.process = nil
end

function Etcd.connect_net_box()
    -- Do nothing, mimic tarantool server API
    return nil
end

return Etcd
