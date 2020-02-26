--- Administration functions.
--
-- @module cartridge.admin

local errors = require('errors')
errors.deprecate(
    "Module `cartridge.admin` is internal." ..
    " You should use `require('cartridge').admin_*` functions instead."
)

local lua_api_stat = require('cartridge.lua-api.stat')
local lua_api_boxinfo = require('cartridge.lua-api.boxinfo')
local lua_api_topology = require('cartridge.lua-api.topology')
local lua_api_failover = require('cartridge.lua-api.failover')
local lua_api_vshard = require('cartridge.lua-api.vshard')
local lua_api_deprecated = require('cartridge.lua-api.deprecated')

return {
    get_stat = lua_api_stat.get_stat,
    get_info = lua_api_boxinfo.get_info,

    get_self = lua_api_topology.get_self,
    get_servers = lua_api_topology.get_servers,
    get_replicasets = lua_api_topology.get_replicasets,
    get_topology = lua_api_topology.get_topology,

    edit_topology = lua_api_topology.edit_topology,
    probe_server = lua_api_topology.probe_server,
    enable_servers = lua_api_topology.enable_servers,
    disable_servers = lua_api_topology.disable_servers,

    get_failover_enabled = lua_api_failover.get_failover_enabled,
    set_failover_enabled = lua_api_failover.set_failover_enabled,

    bootstrap_vshard = lua_api_vshard.bootstrap_vshard,

    edit_replicaset = lua_api_deprecated.edit_replicaset, -- deprecated
    edit_server = lua_api_deprecated.edit_server, -- deprecated
    join_server = lua_api_deprecated.join_server, -- deprecated
    expel_server = lua_api_deprecated.expel_server, -- deprecated
}
