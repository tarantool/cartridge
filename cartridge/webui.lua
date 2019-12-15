#!/usr/bin/env tarantool

local log = require('log')
local lsp = require('tarantool-lsp')
local json = require('json').new()
local front = require('frontend-core')
local checks = require('checks')
local errors = require('errors')

local vars = require('cartridge.vars').new('cartridge.webui')
local auth = require('cartridge.auth')
local graphql = require('cartridge.graphql')
local front_bundle = require('cartridge.front-bundle')

local api_auth = require('cartridge.webui.api-auth')
local api_config = require('cartridge.webui.api-config')
local api_issues = require('cartridge.webui.api-issues')
local api_vshard = require('cartridge.webui.api-vshard')
local api_topology = require('cartridge.webui.api-topology')
local api_failover = require('cartridge.webui.api-failover')
local api_ddl = require('cartridge.webui.api-ddl')
local gql_types = require('cartridge.graphql.types')

json.cfg({
    encode_use_tostring = true,
})

local LspError = errors.new_class('LspError')
local module_name = 'cartridge.webui'

vars:new('blacklist', {})

local function set_blacklist(blacklist)
    vars.blacklist = table.copy(blacklist)
end

local function get_blacklist()
    return vars.blacklist
end

local function http_finalize_error(http_code, err)
    log.error('%s', err)

    return auth.render_response({
        status = http_code,
        headers = {
            ['content-type'] = "application/json; charset=utf-8"
        },
        body = json.encode(err),
    })
end

local function init(httpd, options)
    checks('?', {
        lsp_enabled = '?boolean',
    })

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
    api_failover.init(graphql)

    -- Replication warnings and other problems
    api_issues.init(graphql)

    graphql.add_callback({
        prefix = 'cluster',
        name = 'webui_blacklist',
        doc = 'List of pages to be hidden in WebUI',
        args = {},
        kind = gql_types.list(gql_types.string.nonNull),
        callback = module_name .. '.get_blacklist',
    })

    -- LSP
    local lsp_handler
    if options.lsp_enabled == true then
        lsp_handler = lsp.create_websocket_handler()
    else
        lsp_handler = function()
            local err = LspError:new('LSP support is disabled')
            return http_finalize_error(501, err)
        end
    end

    httpd:route({
        path = '/admin/lsp',
        method = 'GET'
    }, function(req)
        if not auth.authorize_request(req) then
            local err = errors.new('LspError', 'Unauthorized')
            return http_finalize_error(401, err)
        end

        return lsp_handler(req)
    end)

    return true
end

return {
    init = init,

    set_blacklist = set_blacklist,
    get_blacklist = get_blacklist,
}
