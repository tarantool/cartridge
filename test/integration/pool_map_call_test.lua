#!/usr/bin/env tarantool

local log = require('log')
local fio = require('fio')
local t = require('luatest')
local g = t.group('pool_map_call')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

local pool = require('cartridge.pool')
local cluster_cookie = require('cartridge.cluster-cookie')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
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

    g.cluster:start()
    g.cluster.main_server.net_box:eval([[
        local remote_control = require('cartridge.remote-control')
        local cluster_cookie = require('cartridge.cluster-cookie')
        remote_control.start('0.0.0.0', 13302, {
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

    cluster_cookie.init(g.cluster.datadir)
    cluster_cookie.set_cookie(g.cluster.cookie)
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function assert_ret_equals(map, uri, expected)
    local ok, err = pcall(function()
        t.assert_not_nil(map[uri])
        t.assert_is_nil(map[uri][1])
        t.assert_is_table(map[uri][2])
        t.assert_equals(
            map[uri][2].class_name .. ': ' .. map[uri][2].err,
            expected)
    end)

    if not ok then
        error(string.format("Unexpected result for %q:\n%s", uri, err), 2)
    end
end

function g.test_timeout()
    local map = pool.map_call('package.loaded.fiber.sleep', {1}, {
        uri_list = {'localhost:13301'},
        timeout = 0,
    })

    assert_ret_equals(map, 'localhost:13301',
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
        ['localhost:13301'] = {true},
        ['localhost:13302'] = {true},
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
end

function g.test_negative()
    local srv = g.cluster.main_server
    srv.net_box:eval([[
        function _G.raise_error()
            error('Too long WAL write')
        end
    ]])

    local map = pool.map_call('_G.raise_error', nil, {
        uri_list = {
            '!@#$%^&*()',      -- invalid uri
            'localhost:13301', -- box.listen
            'localhost:13302', -- remote-control
            'localhost:13309', -- discard protocol
            'localhost:9',     -- connection refused
        },
        timeout = 1,
    })

    assert_ret_equals(map, '!@#$%^&*()',      'FormatURIError: Invalid URI "!@#$%^&*()"')
    assert_ret_equals(map, 'localhost:13301', 'Net.box call failed: eval:2: Too long WAL write')
    assert_ret_equals(map, 'localhost:13302', 'Net.box call failed: eval:2: Too long WAL write')
    assert_ret_equals(map, 'localhost:13309', 'NetboxConnectError: "localhost:13309": Invalid greeting')
    assert_ret_equals(map, 'localhost:9',     'NetboxConnectError: "localhost:9": Connection refused')
end

function g.test_positive()
    local map = pool.map_call('math.pow', {2, 4}, {
        uri_list = {
            'localhost:13301',
            'localhost:13302',
        }
    })

    t.assert_equals(map, {
        ['localhost:13301'] = {16},
        ['localhost:13302'] = {16},
    })
end
