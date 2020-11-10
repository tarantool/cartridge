local fio = require('fio')
local httpc = require('http.client')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local function reload_myrole(fn)
    local ok, err = g.cluster.main_server.net_box:eval([[
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
    g.cluster:start()
    g.srv = g.cluster.main_server

    local ok, err = g.srv.net_box:eval([[
        return require("cartridge.roles").reload()
    ]])
    t.assert_equals({ok, err}, {true, nil})
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_reload()
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
end

-- TODO
-- Check failover-coordinator reloadability
