#!/usr/bin/env tarantool

local tarantool_lsp = require('tarantool-lsp')

local function init(httpd)

    httpd:route({
        path = '/admin/lsp',
        method = 'GET'
    }, tarantool_lsp.create_websocket_handler())

    return true
end

return {
    init = init,
}
