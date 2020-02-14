#!/usr/bin/env tarantool

-- local log = require('log')
local front = require('frontend-core')

local graphql = require('cartridge.graphql')
local front_bundle = require('cartridge.front-bundle')

local api_auth = require('cartridge.webui.api-auth')
local api_config = require('cartridge.webui.api-config')
local api_vshard = require('cartridge.webui.api-vshard')
local api_topology = require('cartridge.webui.api-topology')
local api_ddl = require('cartridge.webui.api-ddl')
local api_blacklist = require('cartridge.webui.api-blacklist')

local webui_blacklist = {}
local function set_blacklist(blacklist)
    require('log').info('call set_blacklist')
    webui_blacklist = table.deepcopy(blacklist)
end

local function get_blacklist()
    require('log').info('call get_blacklist')
    return table.deepcopy(webui_blacklist)
end

local function init(httpd)
    front.init(httpd)
    front.add('cluster', front_bundle)

    graphql.init(httpd)
    graphql.add_mutation_prefix('cluster', 'Cluster management')
    graphql.add_callback_prefix('cluster', 'Cluster management')

    -- User management
    api_auth.init(graphql)

    -- Config upload/download
    api_config.init(graphql, httpd)

    api_ddl.init(graphql)

    -- Vshard operations
    api_vshard.init(graphql)

    -- Basic topology operations
    api_topology.init(graphql)

    -- Pages blacklist
    api_blacklist.init(graphql)

    return true
end

return {
    init = init,

    set_blacklist = set_blacklist,
    get_blacklist = get_blacklist,
}
