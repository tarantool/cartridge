local function init(httpd)
    local ok, lsp = pcall(require, 'tarantool-lsp')
    if not ok then
        return nil, err
    end

    httpd:route({
        path = '/admin/lsp',
        method = 'GET'
    }, lsp.create_websocket_handler())

    return true
end

return {
    init = init,
}
