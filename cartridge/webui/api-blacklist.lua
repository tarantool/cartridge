#!/usr/bin/env tarantool

local gql_types = require('cartridge.graphql.types')
local module_name = 'cartridge.webui.api-blacklist'

local function get_webui_blacklist(_, _)
	require('log').info('callback get_webui_blacklist')
	return require('cartridge.webui').get_blacklist()
end

local function init(graphql)
	graphql.add_callback({
		name = 'webui_blacklist',
		args = {},
        kind = gql_types.list(gql_types.string.nonNull),
        callback = module_name .. '.get_webui_blacklist',
	})
end

return {
	init = init,

	get_webui_blacklist = get_webui_blacklist,
}
