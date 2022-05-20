local cartridge = require('cartridge')

return {
    init = function()
        local httpd = assert(cartridge.service_get('httpd'), "Failed to get httpd serivce")
        local vshard_router = cartridge.service_get('vshard-router').get()

        httpd:route({method = 'GET', path = '/test'}, function(req)
            local key = req:query_param('key')
            local bucket_id = vshard_router:bucket_id_strcrc32(key)
            local value, err = vshard_router:callrw(bucket_id, 'box.space.test:get', { key })
            if not value then
                return req:render{status = 500, error = err}
            end
            return req:render{json = value[3]}
        end)

        httpd:route({method = 'POST', path = '/test'}, function(req)
            local key = req:query_param('key')
            local value = req:json()
            local bucket_id = vshard_router:bucket_id_strcrc32(key)
            local ok, err = vshard_router:callrw(bucket_id, 'box.space.test:put', { { bucket_id, key, value } })
            if not ok then
                return req:render{status = 500, error = err}
            end
            return {status = 200}
        end)

    end,
    dependencies = { 'cartridge.roles.vshard-router' },
}
