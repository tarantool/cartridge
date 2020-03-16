#!/usr/bin/env tarantool

local log = require('log')
local fio = require('fio')
local errno = require('errno')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local pool = require('cartridge.pool')
local cluster_cookie = require('cartridge.cluster-cookie')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        use_vshard = false,
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {
                    {
                        alias = 'main',
                        http_port = 8081,
                        net_box_port = 13301,
                        instance_uuid = helpers.uuid('a', 'a', 1)
                    }
                },
            },
        },
    })

    g.server = helpers.Server:new({
        workdir = fio.pathjoin(g.cluster.datadir, 'victim'),
        alias = 'victim',
        command = helpers.entrypoint('srv_basic'),
        replicaset_uuid = helpers.uuid('b'),
        instance_uuid = helpers.uuid('b', 'b', 1),
        http_port = 8082,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13315,
    })

    g.cluster:start()
    g.cluster.main_server.net_box:eval([[
        local remote_control = require('cartridge.remote-control')
        local cluster_cookie = require('cartridge.cluster-cookie')
        remote_control.bind('0.0.0.0', 13302)
        remote_control.accept({
            username = cluster_cookie.username(),
            password = cluster_cookie.cookie(),
        })

        local socket = require('socket')
        local tcp_discard = socket.tcp_server('0.0.0.0', 13309, {
            name = 'tcp_discard',
            handler = function()
                -- Discard all data, never reply
            end,
        })
    ]])

    g.server:start()
    t.helpers.retrying({}, function()
        g.server:graphql({query = '{}'})
    end)

    cluster_cookie.init(g.cluster.datadir)
    cluster_cookie.set_cookie(g.cluster.cookie)
end

g.after_all = function()
    g.cluster:stop()
    g.server:stop()
    fio.rmtree(g.cluster.datadir)
end

local function assert_err_equals(map, uri, expected1, expected2)
    if map[uri] == nil then
        local err = string.format(
            "No error for %q:\n" ..
            "expected: %s",
            uri, expected1
        )
        error(err, 2)
    end

    local actual = map[uri].class_name .. ': ' .. map[uri].err
    if actual ~= expected1 and actual ~= expected2 then
        log.error('%s', map[uri])
        local err = string.format(
            "Unexpected error for %q:\n" ..
            "expected: %s\n" ..
            "  actual: %s\n",
            uri, expected1, actual
        )
        error(err, 2)
    end
end

function g.test_timeout()
    local retmap, errmap = pool.map_call('package.loaded.fiber.sleep', {1}, {
        uri_list = {'localhost:13301'},
        timeout = 0,
    })

    t.assert_equals(retmap, {})
    assert_err_equals(errmap, 'localhost:13301',
        'Net.box call failed: Timeout exceeded'
    )
end


function g.test_parallel()
    local srv = g.cluster.main_server
    srv.net_box:eval([[
        local fiber = require('fiber')
        _G._test_channel = fiber.channel(0)

        function _G.communicate()
            if not _G._test_channel:has_readers() then
                return _G._test_channel:get()
            else
                return _G._test_channel:put(true)
            end
        end
    ]])

    -- Test that `map_call` makes requests in parallel:
    --   The first one blocks with channel:get()
    --   The second one does channel:put()
    -- Otherwise, if requests are sequential,
    --   The first fiber isn't unlocked and returns timeout error

    local map = pool.map_call('_G.communicate', nil, {
        uri_list = {
            'localhost:13301',
            'localhost:13302',
        },
        timeout = 1,
    })

    t.assert_equals(map, {
        ['localhost:13301'] = true,
        ['localhost:13302'] = true,
    })
end


function g.test_errors()
    t.assert_error_msg_contains(
        'bad argument opts.uri_list to fizzbuzz ' ..
        '(table expected, got nil)',
        function()
            local fizzbuzz = pool.map_call
            fizzbuzz('math.floor', nil)
        end
    )

    t.assert_error_msg_contains(
        'bad argument opts.uri_list to map_call ' ..
        '(contiguous array of strings expected)',
        function()
            pool.map_call('math.floor', nil, {uri_list = {3301}})
        end
    )

    t.assert_error_msg_contains(
        'bad argument opts.uri_list to map_call ' ..
        '(contiguous array of strings expected)',
        pool.map_call, 'math.floor', nil, {uri_list = {'a', nil, 'b'}}
    )

    t.assert_error_msg_contains(
        'bad argument opts.uri_list to map_call ' ..
        '(duplicates are prohibited)',
        pool.map_call, 'math.floor', nil, {uri_list = {'x', 'x'}}
    )
end

function g.test_negative()
    local srv = g.cluster.main_server
    srv.net_box:eval([[
        function _G.raise_error()
            error('Too long WAL write', 0)
        end
    ]])

    local retmap, errmap = pool.map_call('_G.raise_error', nil, {
        uri_list = {
            '!@#$%^&*()',      -- invalid uri
            'localhost:13301', -- box.listen
            'localhost:13302', -- remote-control
            'localhost:13309', -- discard protocol
            'localhost:9',     -- connection refused
        },
        timeout = 1,
    })

    t.assert_equals(retmap, {})
    assert_err_equals(errmap, '!@#$%^&*()',      'FormatURIError: Malformed URI "!@#$%^&*()"')
    assert_err_equals(errmap, 'localhost:13301', 'Net.box call failed: Too long WAL write')
    assert_err_equals(errmap, 'localhost:13302', 'Net.box call failed: Too long WAL write')
    assert_err_equals(errmap, 'localhost:13309', 'NetboxConnectError: "localhost:13309": Invalid greeting')
    assert_err_equals(errmap, 'localhost:9',
        'NetboxConnectError: "localhost:9": ' .. errno.strerror(errno.ECONNREFUSED),
        'NetboxConnectError: "localhost:9": ' .. errno.strerror(errno.ENETUNREACH)
    )
end

function g.test_errors_united()
    local srv = g.cluster.main_server
    srv.net_box:eval([[
        local errors = require('errors')
        function _G.return_error()
            return nil, errors.new('E', 'Segmentation fault')
        end
    ]])

    local _, err = pool.map_call('_G.return_error', nil, {
        uri_list = {
            ')(*&^%$#@!',      -- invalid uri
            'localhost:13301', -- box.listen
            'localhost:13302', -- remote-control
            'localhost:13309', -- discard protocol
        },
        timeout = 1,
    })

    log.info('%s', err)

    t.assert_equals(err.class_name, 'NetboxMapCallError')
    t.assert_equals(#err.err:split('\n'), 3)
    t.assert_items_equals(
        err.err:split('\n'),
        {
            'Malformed URI ")(*&^%$#@!"',
            'Segmentation fault',
            '"localhost:13309": Invalid greeting',
        }
    )
end

function g.test_positive()
    local retmap, errmap = pool.map_call('math.pow', {2, 4}, {
        uri_list = {
            'localhost:13301',
            'localhost:13302',
        }
    })

    t.assert_equals(retmap, {
        ['localhost:13301'] = 16,
        ['localhost:13302'] = 16,
    })
    t.assert_equals(errmap, nil)
end


function g.test_deprecation()
    local errors = require('errors')
    local deprecation_errors = {}
    errors.set_deprecation_handler(function(err)
        table.insert(deprecation_errors, err.str)
    end)

    local conn, err = pool.connect(g.cluster.main_server.advertise_uri)
    t.assert_equals(err, nil)
    t.assert_equals(conn.opts, {
        user = 'admin',
        wait_connected = false,
    })

    t.assert_equals(#deprecation_errors, 0)

    g.cluster.main_server.net_box:eval([[
        box.schema.user.create('test1', {password = 'X'})
        box.schema.user.grant('test1', 'read,write,execute,create,drop','universe')
    ]])

    conn:close()

    local conn, err = pool.connect(g.cluster.main_server.advertise_uri, {
        user = 'test1',
        password = 'X',
        connect_timeout = 0.1,
        wait_connected = true,
        reconnect_after = 1,
    })

    t.assert_equals(err, nil)
    t.assert_equals(conn.opts, {
        user = 'admin',     -- other users deprecated
        wait_connected = false,
        connect_timeout = nil,
        reconnect_after = nil,
        password = nil,
    })

    t.assert_equals(#deprecation_errors, 3)

    t.assert_str_contains(deprecation_errors[1],
        'DeprecationError: Options "user" and "password" are useless ' ..
        'in pool.connect, they never worked as intended and will never do'
    )

    t.assert_str_contains(deprecation_errors[2],
        'DeprecationError: Option "reconnect_after" is useless in pool.connect, ' ..
        'it never worked as intended and will never do'
    )

    t.assert_str_contains(deprecation_errors[3],
        'DeprecationError: Option "connect_timeout" is useless in pool.connect, ' ..
        'use "wait_connected" instead'
    )
end


function g.test_pool_connect()
    local conn, err = pool.connect('localhost:13999')
    t.assert_equals(conn, nil)
    t.assert_equals(err.str, 'NetboxConnectError: "localhost:13999": Connection refused')

    g.server.process:kill('STOP')
    local conn, err = pool.connect('localhost:13315', {wait_connected = 0.1})
    t.assert_equals(conn, nil)
    t.assert_equals(err.str, 'NetboxConnectError: "localhost:13315": Connection not established (yet)')

    local conn, err = pool.connect('localhost:13315', {connect_timeout = 0.1})
    t.assert_equals(conn, nil)
    t.assert_equals(err.str, 'NetboxConnectError: "localhost:13315": Connection not established (yet)')

    local conn, err = pool.connect('localhost:13315', {wait_connected = false})
    t.assert_equals(err, nil)
    t.assert_equals(conn.state, 'initial')

    g.server.process:kill('CONT')
    t.helpers.retrying({}, function()
        t.assert_equals(conn.state, 'active')
    end)
end
