#!/usr/bin/env tarantool

local t = require('luatest')
local g = t.group()

local http_server = require('http.server')
local http_router = require('http.router')
local http_client = require('http.client')

local http_adapter = require('cartridge.http-adapter')

function g.setup()
    g.server = http_server.new("127.0.0.1", 12345)
    g.router = http_router.new()
    g.server:set_router(g.router)
    g.http_adapter = http_adapter.new(g.server, g.router)
end

function g.test_adapter_server_fields()
    local server_fields = {
        "host",
        "port",
        "tcp_server",
        "is_run",
    }

    for _, field in ipairs(server_fields) do
        local field_value = g.server[field]
        g.server[field] = nil
        t.assert_equals(g.http_adapter[field], g.server[field])
        t.assert_is(g.router[field], nil)

        g.http_adapter[field] = field_value
        t.assert_equals(g.http_adapter[field], g.server[field])
        t.assert_is(g.router[field], nil)
    end
end

function g.test_adapter_router_fields()
    local router_fields = {
        "routes",
        "iroutes",
        "helpers",
        "hooks",
        "cache",
    }

    for _, field in ipairs(router_fields) do
        local field_value = g.router[field]
        g.router[field] = nil
        t.assert_equals(g.http_adapter[field], g.router[field])
        t.assert_is(g.server[field], nil)

        g.http_adapter[field] = field_value
        t.assert_equals(g.http_adapter[field], g.router[field])
        t.assert_is(g.server[field], nil)
    end
end

function g.test_custom_adapter_field()
    g.http_adapter.some_field = 42
    t.assert_is(g.router.some_field, nil)
    t.assert_is(g.server.some_field, nil)
    t.assert_equals(g.http_adapter.some_field, 42)
end

function g.test_server_options_fields()
    local server_options = {
        "router",
        "log_requests",
        "log_errors",
        "display_errors",
    }

    for _, option in ipairs(server_options) do
        local option_value = g.server.options[option]
        g.server.options[option] = nil
        t.assert_equals(g.http_adapter.options[option], g.server.options[option])
        t.assert_is(g.router.options[option], nil)

        g.http_adapter.options[option] = option_value
        t.assert_equals(g.http_adapter.options[option], g.server.options[option])
        t.assert_is(g.router.options[option], nil)
    end
end

function g.test_router_options_fields()
    local router_options = {
        "max_header_size",
        "header_timeout",
        "app_dir",
        "charset",
        "cache_templates",
        "cache_controllers",
        "cache_static"
    }

    for _, option in ipairs(router_options) do
        local option_value = g.router.options[option]
        g.router.options[option] = nil
        t.assert_equals(g.http_adapter.options[option], g.router.options[option])
        t.assert_is(g.server.options[option], nil)

        g.http_adapter.options[option] = option_value
        t.assert_equals(g.http_adapter.options[option], g.router.options[option])
        t.assert_is(g.server.options[option], nil)
    end
end

function g.test_request_substitution()
    g.http_adapter:start()
    g.http_adapter:route({path = '/', method = 'GET'},
        function(req)
            req.additional_field = 42
        end
    )
    g.router:use(function(req)
        local resp = req:next()
        assert(req.additional_field == nil)
        return resp
    end, {path = '/', method = 'GET'})

    local r = http_client.get('http://127.0.0.1:12345/')
    t.assert_equals(r.status, 200)
    g.http_adapter:stop()
end
