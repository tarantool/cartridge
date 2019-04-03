#!/usr/bin/env tarantool

-- local log = require('log')
local front = require('frontend-core')

local graphql = require('cluster.graphql')
local front_bundle = require('cluster.front-bundle')

local api_auth = require('cluster.webui.api-auth')
local api_config = require('cluster.webui.api-config')
local api_topology = require('cluster.webui.api-topology')

local function init(httpd)
    front.init(httpd)
    front.add('cluster', front_bundle)

    graphql.init(httpd)
    graphql.add_mutation_prefix('cluster', 'Cluster management')
    graphql.add_callback_prefix('cluster', 'Cluster management')

    -- User management
    api_auth.init(graphql)

    -- Config upload/download
    api_config.init(httpd)

    -- Basic topology operations
    api_topology.init(graphql)

    return true
end

return {
    init = init,
}
