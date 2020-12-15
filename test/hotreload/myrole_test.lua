local fio = require('fio')
local yaml = require('yaml')
local fiber = require('fiber')
local httpc = require('http.client')
local socket = require('socket')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local function reload_myrole(fn)
    local ok, err = g.srv.net_box:eval([[
        package.preload["mymodule"] = loadstring(...)
        return require("cartridge.roles").reload()
    ]], {string.dump(fn)})

    t.assert_equals({ok, err}, {true, nil})
end

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {{
            alias = 'A',
            roles = {'myrole'},
            servers = 1,
        }},
    })
    g.srv = g.cluster:server('A-1')
    g.srv.env['TARANTOOL_CONSOLE_SOCK'] = g.srv.workdir .. '/console.sock'
    g.cluster:start()

    local ok, err = g.srv.net_box:eval([[
        return require("cartridge.roles").reload()
    ]])
    t.assert_equals({ok, err}, {true, nil})
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_events()
    reload_myrole(function()
        rawset(_G, 'events', {})
        table.insert(_G.events, 'require')
        return {
            role_name = 'myrole',
            validate_config = function() table.insert(_G.events, 'validate') return true end,
            apply_config = function() table.insert(_G.events, 'apply') end,
            init = function() table.insert(_G.events, 'init') end,
        }
    end)

    t.assert_equals(
        g.srv.net_box:eval('return _G.events'),
        {'require', 'validate', 'init', 'apply'}
    )
end

function g.test_errors()
    local ok, err = g.srv.net_box:eval([[
        package.preload["mymodule"] = function() error("F", 0) end
        return require("cartridge.roles").reload()
    ]])

    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'RegisterRoleError',
        err = 'F',
    })

    local resp = g.srv:graphql({query = [[
        {cluster { self {state error} }}
    ]]})

    t.assert_equals(resp.data.cluster.self, {
        state = "ReloadError",
        error = "F",
    })

    reload_myrole(function() return {role_name = 'myrole'} end)
    g.cluster:wait_until_healthy()
end

function g.test_roledeps()
    g.srv.net_box:eval([[
        package.preload["role-a"] = function() return {} end
        package.preload["role-b"] = function() return {} end
    ]])

    reload_myrole(function()
        return {
            role_name = 'myrole',
            dependencies = {'role-a'},
        }
    end)

    g.srv.net_box:eval([[
        local cartridge = require('cartridge')
        assert(package.loaded['role-a'])
        assert(package.loaded['role-b'] == nil)
        assert(cartridge.service_get('role-a'))
        assert(cartridge.service_get('role-b') == nil)
    ]])

    reload_myrole(function()
        return {
            role_name = 'myrole',
            dependencies = {'role-b'},
        }
    end)

    g.srv.net_box:eval([[
        local cartridge = require('cartridge')
        assert(package.loaded['role-a'] == nil)
        assert(package.loaded['role-b'])
        assert(cartridge.service_get('role-a') == nil)
        assert(cartridge.service_get('role-b'))
    ]])
end

function g.test_rpc()
    reload_myrole(function()
        return {
            role_name = 'myrole',
            cheer = function() return 'Hello, Cartridge' end,
        }
    end)

    -- New RPC works
    t.assert_equals(g.srv.net_box:call(
        'package.loaded.cartridge.rpc_call',
        {'myrole', 'cheer'}
    ), 'Hello, Cartridge')

    reload_myrole(function()
        return {
            role_name = 'myrole',
            echo = function(...) return ... end,
        }
    end)

    -- Old RPC isn't available anymore
    local ret, err = g.srv.net_box:call(
        'package.loaded.cartridge.rpc_call',
        {'myrole', 'cheer'}
    )
    t.assert_equals(ret, nil)
    t.assert_covers(err, {
        class_name = 'RemoteCallError',
        err = 'Role "myrole" has no method "cheer"',
    })

    -- New RPC works
    t.assert_equals(g.srv.net_box:call(
        'package.loaded.cartridge.rpc_call',
        {'myrole', 'echo', {'2020-11-10'}}
    ), '2020-11-10')
end

function g.test_netbox()
    reload_myrole(function()
        rawset(_G, 'hang', function()
            rawset(_G, 'test_ready', true)
            require('log').info('Weird netbox call')
            require('fiber').sleep(math.huge)
            return true
        end)
        return {role_name = 'myrole'}
    end)

    local future = g.srv.net_box:call('hang', nil, {is_async = true})
    helpers.retrying({}, function()
        g.srv.net_box:eval('return test_ready')
    end)

    reload_myrole(function()
        return {role_name = 'myrole'}
    end)

    -- The call is aborted
    local ok, err = future:wait_result(1)
    t.assert_equals(ok, nil)
    t.assert_equals(type(err), 'cdata')
    t.assert_equals(tostring(err), 'fiber is cancelled')

    -- But connection remains alive
    t.assert_equals(g.srv.net_box:ping(), true)
    t.assert_covers(g.srv.net_box, {state = 'active'})
end

function g.test_routes()
    reload_myrole(function()
        local service_registry = require('cartridge.service-registry')
        local httpd = service_registry.get('httpd')

        local function echo(req)
            return {
                status = 200,
                body = ('Echo 1 %s %s'):format(req.method, req.path),
            }
        end
        httpd:route({method = 'ANY', path = '/route-a'}, echo)
        httpd:route({method = 'GET', path = '/route-b'}, echo)

        return {role_name = 'myrole'}
    end)

    t.assert_covers(
        httpc.get('localhost:8081/route-a'),
        {status = 200, body = 'Echo 1 GET /route-a'}
    )
    t.assert_covers(
        httpc.put('localhost:8081/route-a'),
        {status = 200, body = 'Echo 1 PUT /route-a'}
    )
    t.assert_covers(
        httpc.get('localhost:8081/route-b'),
        {status = 200, body = 'Echo 1 GET /route-b'}
    )
    t.assert_covers(
        httpc.put('localhost:8081/route-b'),
        {status = 404}
    )

    reload_myrole(function()
        local service_registry = require('cartridge.service-registry')
        local httpd = service_registry.get('httpd')

        local function echo(req)
            return {
                status = 200,
                body = ('Echo 2 %s %s'):format(req.method, req.path),
            }
        end
        httpd:route({method = 'GET', path = '/route-a'}, echo)
        httpd:route({method = 'POST', path = '/route-c'}, echo)

        return {role_name = 'myrole'}
    end)


    t.assert_covers(
        httpc.get('localhost:8081/route-a'),
        {status = 200, body = 'Echo 2 GET /route-a'}
    )
    t.assert_covers(
        httpc.put('localhost:8081/route-a'),
        {status = 404}
    )
    t.assert_covers(
        httpc.get('localhost:8081/route-b'),
        {status = 404}
    )
    t.assert_covers(
        httpc.post('localhost:8081/route-c'),
        {status = 200, body = 'Echo 2 POST /route-c'}
    )

    reload_myrole(function()
        local service_registry = require('cartridge.service-registry')
        local httpd = service_registry.get('httpd')
        httpd:route({method = 'GET', path = '/sleep'}, function()
            rawset(_G, 'test_ready', true)
            require('log').info('Weird http callback')
            require('fiber').sleep(math.huge)
            return {status = 200}
        end)
        return {role_name = 'myrole'}
    end)

    local f = fiber.new(httpc.get, 'localhost:8081/sleep')
    f:name('http_get')
    f:set_joinable(true)
    helpers.retrying({}, function()
        g.srv.net_box:eval('return test_ready')
    end)

    reload_myrole(function()
        return {role_name = 'myrole'}
    end)

    local ok, resp = f:join()
    t.assert_equals(ok, true)
    t.assert_covers(resp, {status = 500})
    t.assert_str_matches(resp.body, 'Unhandled error: fiber is cancelled\n.+')

    t.assert_covers(
        httpc.get('localhost:8081/sleep'),
        {status = 404}
    )
end

function g.test_globals()
    local function inspect(var)
        return g.srv.net_box:eval([[
            return rawget(_G, ...)
        ]], {var})
    end

    reload_myrole(function()
        rawset(_G, '__var_on_require', true)
        rawset(_G, '__var_whitelisted', true)
        require('cartridge.hotreload').whitelist_globals({'__var_whitelisted'})
        return {
            role_name = 'myrole',
            apply_config = function()
                rawset(_G, '__var_on_apply', true)
            end
        }
    end)

    t.assert_equals(inspect('__var_whitelisted'), true)
    t.assert_equals(inspect('__var_on_require'), true)
    t.assert_equals(inspect('__var_on_apply'), true)

    reload_myrole(function()
        return {role_name = 'myrole'}
    end)

    t.assert_equals(inspect('__var_whitelisted'), true)
    t.assert_equals(inspect('__var_on_require'), nil)
    t.assert_equals(inspect('__var_on_apply'), nil)
end

function g.test_fibers()
    g.srv.net_box:eval([[
        local fiber = require('fiber')
        fiber.fibers = {}
        function fiber.spawn(name, fn, ...)
            local f = fiber.new(fn, ...)
            f:name(name)
            fiber.fibers[name] = f
            return f
        end
    ]])

    local function inspect(fname)
        return g.srv.net_box:eval([[
            return require('fiber').fibers[...]:status()
        ]], {fname})
    end

    reload_myrole(function()
        local fiber = require('fiber')
        local hotreload = require('cartridge.hotreload')
        local f_managed
        return {
            role_name = 'myrole',
            init = function()
                f_managed = fiber.spawn('managed', fiber.sleep, math.huge)
                fiber.spawn('infsleep', fiber.sleep, math.huge)
                fiber.spawn('whitelisted', fiber.sleep, math.huge)
                hotreload.whitelist_fibers({'managed'})
                hotreload.whitelist_fibers({'whitelisted'})
            end,
            stop = function()
                f_managed:cancel()
            end,
        }
    end)

    t.assert_equals(inspect('managed'), 'suspended')
    t.assert_equals(inspect('infsleep'), 'suspended')
    t.assert_equals(inspect('whitelisted'), 'suspended')

    reload_myrole(function()
        return {role_name = 'myrole'}
    end)

    t.assert_equals(inspect('managed'), 'dead')
    t.assert_equals(inspect('infsleep'), 'dead')
    t.assert_equals(inspect('whitelisted'), 'suspended')
end

function g.test_console()
    local s = socket.tcp_connect(
        'unix/', g.srv.env.TARANTOOL_CONSOLE_SOCK
    )
    t.assert(s)
    local greeting = s:read('\n', 0.1)
    t.assert(greeting)
    t.assert_str_matches(greeting:strip(), 'Tarantool.*%(Lua console%)')
    s:read('\n', 0)

    reload_myrole(function()
        return {role_name = 'myrole'}
    end)

    s:write('return "of reckoning"\n')
    local resp = s:read('...\n', 1)
    t.assert_equals(resp, yaml.encode({'of reckoning'}))
end
