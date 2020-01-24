#!/usr/bin/env tarantool

-- Tests for http 1.1.0 (https://github.com/tarantool/http-1.1.0/tree/1.1.0/test)

local tap = require('tap')
local fio = require('fio')
local http_lib = require('http.lib')
local http_client = require('http.client')
local http_server = require('http.server')
local http_router = require('http.router')
local http_adapter = require('cartridge.http-adapter')
local json = require('json')
local urilib = require('uri')

local test = tap.test("http")
test:plan(8)

test:test("split_uri", function(test)
    test:plan(65)
    local function check(uri, rhs)
        local lhs = urilib.parse(uri)
        local extra = { lhs = lhs, rhs = rhs }
        if lhs.query == '' then
            lhs.query = nil
        end
        test:is(lhs.scheme, rhs.scheme, uri.." scheme", extra)
        test:is(lhs.host, rhs.host, uri.." host", extra)
        test:is(lhs.service, rhs.service, uri.." service", extra)
        test:is(lhs.path, rhs.path, uri.." path", extra)
        test:is(lhs.query, rhs.query, uri.." query", extra)
    end
    check('http://abc', { scheme = 'http', host = 'abc'})
    check('http://abc/', { scheme = 'http', host = 'abc', path ='/'})
    check('http://abc?', { scheme = 'http', host = 'abc'})
    check('http://abc/?', { scheme = 'http', host = 'abc', path ='/'})
    check('http://abc/?', { scheme = 'http', host = 'abc', path ='/'})
    check('http://abc:123', { scheme = 'http', host = 'abc', service = '123' })
    check('http://abc:123?', { scheme = 'http', host = 'abc', service = '123'})
    check('http://abc:123?query', { scheme = 'http', host = 'abc',
        service = '123', query = 'query'})
    check('http://domain.subdomain.com:service?query', { scheme = 'http',
        host = 'domain.subdomain.com', service = 'service', query = 'query'})
    check('google.com', { host = 'google.com'})
    check('google.com?query', { host = 'google.com', query = 'query'})
    check('google.com/abc?query', { host = 'google.com', path = '/abc',
        query = 'query'})
    check('https://google.com:443/abc?query', { scheme = 'https',
        host = 'google.com', service = '443', path = '/abc', query = 'query'})
end)

test:test("template", function(test)
    test:plan(5)
    test:is(http_lib.template("<% for i = 1, cnt do %> <%= abc %> <% end %>",
        {abc = '1 <3>&" ', cnt = 3}),
        ' 1 &lt;3&gt;&amp;&quot;   1 &lt;3&gt;&amp;&quot;   1 &lt;3&gt;&amp;&quot;  ',
        "tmpl1")
    test:is(http_lib.template("<% for i = 1, cnt do %> <%= ab %> <% end %>",
        {abc = '1 <3>&" ', cnt = 3}),
        ' nil  nil  nil ', "tmpl2")
    local r, msg = pcall(http_lib.template, "<% ab() %>", {ab = '1'})
    test:ok(r == false and msg:match("call local 'ab'") ~= nil, "bad template")

    -- gh-18: rendered tempate is truncated
    local template = [[
<html>
<body>
    <table border="1">
    % for i,v in pairs(t) do
    <tr>
    <td><%= i %></td>
    <td><%= v %></td>
    </tr>
    % end
    </table>
</body>
</html>
]]

    local t = {}
    for i=1, 100 do
        t[i] = string.rep('#', i)
    end

    local rendered, _ = http_lib.template(template, { t = t })
    test:ok(#rendered > 10000, "rendered size")
    test:is(rendered:sub(#rendered - 7, #rendered - 1), "</html>", "rendered eof")
end)

test:test('parse_request', function(test)
    test:plan(6)

    test:is_deeply(http_lib._parse_request('abc'),
        { error = 'Broken request line', headers = {} }, 'broken request')



    test:is(
        http_lib._parse_request("GET / HTTP/1.1\nHost: s.com\r\n\r\n").path,
        '/',
        'path'
    )
    test:is_deeply(
        http_lib._parse_request("GET / HTTP/1.1\nHost: s.com\r\n\r\n").proto,
        {1,1},
        'proto'
    )
    test:is_deeply(
        http_lib._parse_request("GET / HTTP/1.1\nHost: s.com\r\n\r\n").headers,
        {host = 's.com'},
        'host'
    )
    test:is_deeply(
        http_lib._parse_request("GET / HTTP/1.1\nHost: s.com\r\n\r\n").method,
        'GET',
        'method'
    )
    test:is_deeply(
        http_lib._parse_request("GET / HTTP/1.1\nHost: s.com\r\n\r\n").query,
        '',
        'query'
    )
end)

test:test('params', function(test)
    test:plan(6)
    test:is_deeply(http_lib.params(), {}, 'nil string')
    test:is_deeply(http_lib.params(''), {}, 'empty string')
    test:is_deeply(http_lib.params('a'), {a = ''}, 'separate literal')
    test:is_deeply(http_lib.params('a=b'), {a = 'b'}, 'one variable')
    test:is_deeply(http_lib.params('a=b&b=cde'), {a = 'b', b = 'cde'}, 'some')
    test:is_deeply(http_lib.params('a=b&b=cde&a=1'),
        {a = { 'b', '1' }, b = 'cde'}, 'array')
end)

local function cfgserv()
    local path = os.getenv('LUA_SOURCE_DIR') or './'
    path = fio.pathjoin(path, 'test', 'unit', 'http-1.1.0')

    local server = http_server.new('127.0.0.1', 12345, { log_requests = false, log_errors = false })
    local router = http_router.new({app_dir = path})
    server:set_router(router)
    local httpd = http_adapter.new(server, router)
        :route({path = '/abc/:cde/:def', name = 'test'}, function() end)
        :route({path = '/abc'}, function() end)
        :route({path = '/ctxaction'}, 'module.controller#action')
        :route({path = '/absentaction'}, 'module.controller#absent')
        :route({path = '/absent'}, 'module.absent#action')
        :route({path = '/abc/:cde'}, function() end)
        :route({path = '/abc_:cde_def'}, function() end)
        :route({path = '/abc-:cde-def'}, function() end)
        :route({path = '/aba*def'}, function() end)
        :route({path = '/abb*def/cde', name = 'star'}, function() end)
        :route({path = '/banners/:token'})
        :helper('helper_title', function(_, a) return 'Hello, ' .. a end)
        :route({path = '/helper', file = 'helper.html.el'})
        :route({ path = '/test', file = 'test.html.el' },
            function(cx) return cx:render({ title = 'title: 123' }) end)
    return httpd
end

test:test("server url match", function(test)
    test:plan(18)
    local httpd = cfgserv()
    test:istable(httpd, "httpd object")
    test:isnil(httpd:match('GET', '/'))
    test:is(httpd:match('GET', '/abc').endpoint.path, "/abc", "/abc")
    test:is(#httpd:match('GET', '/abc').stash, 0, "/abc")
    test:is(httpd:match('GET', '/abc/123').endpoint.path, "/abc/:cde", "/abc/123")
    test:is(httpd:match('GET', '/abc/123').stash.cde, "123", "/abc/123")
    test:is(httpd:match('GET', '/abc/123/122').endpoint.path, "/abc/:cde/:def",
        "/abc/123/122")
    test:is(httpd:match('GET', '/abc/123/122').stash.def, "122",
        "/abc/123/122")
    test:is(httpd:match('GET', '/abc/123/122').stash.cde, "123",
        "/abc/123/122")
    test:is(httpd:match('GET', '/abc_123-122').endpoint.path, "/abc_:cde_def",
        "/abc_123-122")
    test:is(httpd:match('GET', '/abc_123-122').stash.cde_def, "123-122",
        "/abc_123-122")
    test:is(httpd:match('GET', '/abc-123-def').endpoint.path, "/abc-:cde-def",
        "/abc-123-def")
    test:is(httpd:match('GET', '/abc-123-def').stash.cde, "123",
        "/abc-123-def")
    test:is(httpd:match('GET', '/aba-123-dea/1/2/3').endpoint.path,
        "/aba*def", '/aba-123-dea/1/2/3')
    test:is(httpd:match('GET', '/aba-123-dea/1/2/3').stash.def,
        "-123-dea/1/2/3", '/aba-123-dea/1/2/3')
    test:is(httpd:match('GET', '/abb-123-dea/1/2/3/cde').endpoint.path,
        "/abb*def/cde", '/abb-123-dea/1/2/3/cde')
    test:is(httpd:match('GET', '/abb-123-dea/1/2/3/cde').stash.def,
        "-123-dea/1/2/3", '/abb-123-dea/1/2/3/cde')
    test:is(httpd:match('GET', '/banners/1wulc.z8kiy.6p5e3').stash.token,
        '1wulc.z8kiy.6p5e3', "stash with dots")
end)

test:test("server url_for", function(test)
    test:plan(5)
    local httpd = cfgserv()
    test:is(httpd:url_for('abcdef'), '/abcdef', '/abcdef')
    test:is(httpd:url_for('test'), '/abc//', '/abc//')
    test:is(httpd:url_for('test', { cde = 'cde_v', def = 'def_v' }),
        '/abc/cde_v/def_v', '/abc/cde_v/def_v')
    test:is(httpd:url_for('star', { def = '/def_v' }),
        '/abb/def_v/cde', '/abb/def_v/cde')
    test:is(httpd:url_for('star', { def = '/def_v' }, { a = 'b', c = 'd' }),
        '/abb/def_v/cde?a=b&c=d', '/abb/def_v/cde?a=b&c=d')
end)

test:test("server requests", function(test)
    test:plan(36)
    local httpd = cfgserv()
    httpd:start()

    local r = http_client.get('http://127.0.0.1:12345/test')
    test:is(r.status, 200, '/test code')
    test:is(r.proto[1], 1, '/test http 1.1')
    test:is(r.proto[2], 1, '/test http 1.1')
    test:is(r.reason, 'Ok', '/test reason')
    test:is(string.match(r.body, 'title: 123'), 'title: 123', '/test body')

    local r = http_client.get('http://127.0.0.1:12345/test404')
    test:is(r.status, 404, '/test404 code')
    -- broken in built-in tarantool/http
    --test:is(r.reason, 'Not found', '/test404 reason')

    local r = http_client.get('http://127.0.0.1:12345/absent')
    test:is(r.status, 500, '/absent code')
    --test:is(r.reason, 'Internal server error', '/absent reason')
    test:is(string.match(r.body, 'load module'), 'load module', '/absent body')

    local r = http_client.get('http://127.0.0.1:12345/ctxaction')
    test:is(r.status, 200, '/ctxaction code')
    test:is(r.reason, 'Ok', '/ctxaction reason')
    test:is(string.match(r.body, 'Hello, Tarantool'), 'Hello, Tarantool',
        '/ctxaction body')
    test:is(string.match(r.body, 'action: action'), 'action: action',
        '/ctxaction body action')
    test:is(string.match(r.body, 'controller: module[.]controller'),
        'controller: module.controller', '/ctxaction body controller')

    local r = http_client.get('http://127.0.0.1:12345/ctxaction.invalid')
    test:is(r.status, 404, '/ctxaction.invalid code') -- WTF?
    --test:is(r.reason, 'Not found', '/ctxaction.invalid reason')
    --test:is(r.body, '', '/ctxaction.invalid body')

    local r = http_client.get('http://127.0.0.1:12345/hello.html')
    test:is(r.status, 200, '/hello.html code')
    test:is(r.reason, 'Ok', '/hello.html reason')
    test:is(string.match(r.body, 'static html'), 'static html',
        '/hello.html body')

    local r = http_client.get('http://127.0.0.1:12345/absentaction')
    test:is(r.status, 500, '/absentaction 500')
    --test:is(r.reason, 'Internal server error', '/absentaction reason')
    test:is(string.match(r.body, 'contain function'), 'contain function',
        '/absentaction body')

    local r = http_client.get('http://127.0.0.1:12345/helper')
    test:is(r.status, 200, 'helper 200')
    test:is(r.reason, 'Ok', 'helper reason')
    test:is(string.match(r.body, 'Hello, world'), 'Hello, world', 'helper body')

    local r = http_client.get('http://127.0.0.1:12345/helper?abc')
    test:is(r.status, 200, 'helper?abc 200')
    test:is(r.reason, 'Ok', 'helper?abc reason')
    test:is(string.match(r.body, 'Hello, world'), 'Hello, world', 'helper body')

    httpd:route({path = '/die', file = 'helper.html.el'},
        function() error(123) end )

    local r = http_client.get('http://127.0.0.1:12345/die')
    test:is(r.status, 500, 'die 500')
    --test:is(r.reason, 'Internal server error', 'die reason')

    httpd:route({ path = '/info' }, function(cx)
        return cx:render({ json = cx.peer })
    end)
    local r = json.decode(http_client.get('http://127.0.0.1:12345/info').body)
    test:is(r.host, '127.0.0.1', 'peer.host')
    test:isnumber(r.port, 'peer.port')

    local r = httpd:route({method = 'POST', path = '/dit', file = 'helper.html.el'},
        function(tx)
            return tx:render({text = 'POST = ' .. tx:read()})
        end)
    test:istable(r, ':route')


    test:test('GET/POST at one route', function(test)
        test:plan(8)

        r = httpd:route({method = 'POST', path = '/dit', file = 'helper.html.el'},
            function(tx)
                return tx:render({text = 'POST = ' .. tx:read()})
            end)
        test:istable(r, 'add POST method')

        r = httpd:route({method = 'GET', path = '/dit', file = 'helper.html.el'},
            function(tx)
                return tx:render({text = 'GET = ' .. tx:read()})
            end )
        test:istable(r, 'add GET method')

        r = httpd:route({method = 'DELETE', path = '/dit', file = 'helper.html.el'},
            function(tx)
                return tx:render({text = 'DELETE = ' .. tx:read()})
            end )
        test:istable(r, 'add DELETE method')

        r = httpd:route({method = 'PATCH', path = '/dit', file = 'helper.html.el'},
            function(tx)
                return tx:render({text = 'PATCH = ' .. tx:read()})
            end )
        test:istable(r, 'add PATCH method')

        r = http_client.request('POST', 'http://127.0.0.1:12345/dit', 'test')
        test:is(r.body, 'POST = test', 'POST reply')

        r = http_client.request('GET', 'http://127.0.0.1:12345/dit')
        test:is(r.body, 'GET = ', 'GET reply')

        r = http_client.request('DELETE', 'http://127.0.0.1:12345/dit', 'test1')
        test:is(r.body, 'DELETE = test1', 'DELETE reply')

        r = http_client.request('PATCH', 'http://127.0.0.1:12345/dit', 'test2')
        test:is(r.body, 'PATCH = test2', 'PATCH reply')
    end)

    httpd:route({path = '/chunked'}, function(self)
        return self:iterate(ipairs({'chunked', 'encoding', 't\r\nest'}))
    end)

    -- http client currently doesn't support chunked encoding
    local r = http_client.get('http://127.0.0.1:12345/chunked')
    test:is(r.status, 200, 'chunked 200')
    test:is(r.headers['transfer-encoding'], 'chunked', 'chunked headers')
    test:is(r.body, 'chunkedencodingt\r\nest', 'chunked body')

    test:test('get cookie', function(test)
        test:plan(2)
        httpd:route({path = '/receive_cookie'}, function(req)
            local foo = req:cookie('foo')
            local baz = req:cookie('baz')
            return req:render({
                text = ('foo=%s; baz=%s'):format(foo, baz)
            })
        end)
        local r = http_client.get('http://127.0.0.1:12345/receive_cookie', {
            headers = {
                cookie = 'foo=bar; baz=feez',
            }
        })
        test:is(r.status, 200, 'status')
        test:is(r.body, 'foo=bar; baz=feez', 'body')
    end)

    test:test('cookie', function(test)
        test:plan(2)
        httpd:route({path = '/cookie'}, function(req)
            local resp = req:render({text = ''})
            resp:setcookie({ name = 'test', value = 'tost',
                expires = '+1y', path = '/abc' })
            resp:setcookie({ name = 'xxx', value = 'yyy' })
            return resp
        end)
        local r = http_client.get('http://127.0.0.1:12345/cookie')
        test:is(r.status, 200, 'status')
        test:ok(r.headers['set-cookie'] ~= nil, "header")
    end)

    test:test('post body', function(test)
        test:plan(2)
        httpd:route({ path = '/post', method = 'POST'}, function(req)
           local t = {
                #req:read("\n");
                #req:read(10);
                #req:read({ size = 10, delimiter = "\n"});
                #req:read("\n");
                #req:read();
                #req:read();
                #req:read();
            }
            return req:render({json = t})
        end)
        local bodyf = os.getenv('LUA_SOURCE_DIR') or './'
        bodyf = io.open(fio.pathjoin(bodyf, 'test/unit/http-1.1.0/public/lorem.txt'))
        local body = bodyf:read('*a')
        bodyf:close()
        local r = http_client.post('http://127.0.0.1:12345/post', body)
        test:is(r.status, 200, 'status')
        test:is_deeply(json.decode(r.body), { 541,10,10,458,1375,0,0 },
            'req:read() results')
    end)

    httpd:stop()
end)

local log_queue = {}

local custom_logger = {
    debug = function() end,
    verbose = function()
        table.insert(log_queue, { log_lvl = 'verbose', })
    end,
    info = function(...)
        table.insert(log_queue, { log_lvl = 'info', msg = string.format(...)})
    end,
    warn = function(...)
        table.insert(log_queue, { log_lvl = 'warn', msg = string.format(...)})
    end,
    error = function(...)
        table.insert(log_queue, { log_lvl = 'error', msg = string.format(...)})
    end
}

local function find_msg_in_log_queue(msg, strict)
    for _, log in ipairs(log_queue) do
        if not strict then
            if log.msg:match(msg) then
                return log
            end
        else
            if log.msg == msg then
                return log
            end
        end
    end
end

local function clear_log_queue()
    log_queue = {}
end

test:test("Custom log functions for route", function(test)
    test:plan(5)

    test:test("Setting log option for server instance", function(test)
        test:plan(2)

        local server = http_server.new(
            "127.0.0.1", 12345, { log_requests = custom_logger.info, log_errors = custom_logger.error }
        )
        local router = http_router.new()
        server:set_router(router)
        local httpd = http_adapter.new(server, router)
        httpd:route({ path='/' }, function(_) end)
        httpd:route({ path='/error' }, function(_) error('Some error...') end)
        httpd:start()

        http_client.get("127.0.0.1:12345")
        test:is_deeply(
            find_msg_in_log_queue("GET /"), { log_lvl = 'info', msg = 'GET /' },
            "Route should logging requests in custom logger if it's presents"
        )
        clear_log_queue()

        http_client.get("127.0.0.1:12345/error")
        test:ok(
            find_msg_in_log_queue("Some error...", false),
            "Route should logging error in custom logger if it's presents"
        )
        clear_log_queue()

        httpd:stop()
    end)

    test:test("Setting log options for route", function(test)
        test:plan(8)
        local server = http_server.new("127.0.0.1", 12345, { log_requests = true, log_errors = false })
        local router = http_router.new()
        server:set_router(router)
        local httpd = http_adapter.new(server, router)
        local dummy_logger = function() end

        local ok, err = pcall(httpd.route, httpd, { path = '/', log_requests = 3 })
        test:is(
            ok, false, "Route logger can't be a log_level digit"
        )
        test:like(
            err, "'log_requests' option should be a function",
            "route() should return error message in case of incorrect logger option"
        )

        ok, err = pcall(httpd.route, httpd, { path = '/', log_requests = { info = dummy_logger } })
        test:is(ok, false, "Route logger can't be a table")
        test:like(
            err, "'log_requests' option should be a function",
            "route() should return error message in case of incorrect logger option"
        )

        local ok, err = pcall(httpd.route, httpd, { path = '/', log_errors = 3 })
        test:is(ok, false, "Route error logger can't be a log_level digit")
        test:like(
            err, "'log_errors' option should be a function",
            "route() should return error message in case of incorrect logger option"
        )

        ok, err = pcall(httpd.route, httpd, { path = '/', log_errors = { error = dummy_logger } })
        test:is(ok, false, "Route error logger can't be a table")
        test:like(
            err, "'log_errors' option should be a function",
            "route() should return error message in case of incorrect log_errors option"
        )
    end)

    test:test("Log output with custom loggers on route", function(test)
        test:plan(3)
        local server = http_server.new("127.0.0.1", 12345, { log_requests = true, log_errors = true })
        local router = http_router.new()
        server:set_router(router)
        local httpd = http_adapter.new(server, router)
        httpd:start()

        httpd:route(
            { path = '/', log_requests = custom_logger.info, log_errors = custom_logger.error }, function(_) end
        )
        http_client.get("127.0.0.1:12345")
        test:is_deeply(
            find_msg_in_log_queue("GET /"), { log_lvl = 'info', msg = 'GET /' },
            "Route should logging requests in custom logger if it's presents"
        )
        clear_log_queue()

        httpd.routes = {}

        --todo fix it
        httpd:route({ path = '/', log_requests = custom_logger.info, log_errors = custom_logger.error }, function(_)
            error("User business logic exception...")
        end)
        http_client.get("127.0.0.1:12345/")
        test:is_deeply(
            find_msg_in_log_queue("GET /"), { log_lvl = 'info', msg = 'GET /' },
            "Route should logging request and error in case of route exception"
        )
        test:ok(find_msg_in_log_queue("User business logic exception...", false),
                "Route should logging error custom logger if it's presents in case of route exception")
        clear_log_queue()

        httpd:stop()
    end)

    test:test("Log route requests with turned off 'log_requests' option", function(test)
        test:plan(1)
        local server = http_server.new("127.0.0.1", 12345, { log_requests = false })
        local router = http_router.new()
        server:set_router(router)
        local httpd = http_adapter.new(server, router)
        httpd:start()

        httpd:route({ path = '/', log_requests = custom_logger.info }, function(_) end)
        http_client.get("127.0.0.1:12345")
        test:is_deeply(
            find_msg_in_log_queue("GET /"), { log_lvl = 'info', msg = 'GET /' },
            "Route can override logging requests if the http server have turned off 'log_requests' option"
        )
        clear_log_queue()

        httpd:stop()
    end)

    test:test("Log route requests with turned off 'log_errors' option", function(test)
        test:plan(1)
        local server = http_server.new("127.0.0.1", 12345, { log_errors = false })
        local router = http_router.new()
        server:set_router(router)
        local httpd = http_adapter.new(server, router)
        httpd:start()

        httpd:route({ path = '/', log_errors = custom_logger.error }, function(_)
            error("User business logic exception...")
        end)
        http_client.get("127.0.0.1:12345")
        test:ok(
            find_msg_in_log_queue("User business logic exception...", false),
            "Route can override logging requests if the http server have turned off 'log_errors' option"
        )
        clear_log_queue()

        httpd:stop()
    end)
end)

os.exit(test:check() == true and 0 or 1)
