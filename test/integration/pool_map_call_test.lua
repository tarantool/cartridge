#!/usr/bin/env tarantool

local log = require('log')
local fio = require('fio')
local errno = require('errno')
local fiber = require('fiber')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local errors = require('errors')
local pool = require('cartridge.pool')
local cluster_cookie = require('cartridge.cluster-cookie')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        use_vshard = false,
        replicasets = {{
            alias = 'main',
            roles = {},
            servers = 1,
        }},
    })

    g.cluster:start()
    g.cluster.main_server:eval([[
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

        local tcp_hanged = socket.tcp_server('0.0.0.0', 13311, {
            name = 'hanged_server',
            handler = function()
                require('fiber').sleep(10)
            end
        })
    ]])

    cluster_cookie.init(g.cluster.datadir)
    cluster_cookie.set_cookie(g.cluster.cookie)
end

g.after_all = function()
    g.cluster:stop()
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

local function assert_err_matches(map, uri, expected1, expected2)
    if map[uri] == nil then
        local err = string.format(
            "No error for %q:\n" ..
            "expected: %s",
            uri, expected1
        )
        error(err, 2)
    end

    local actual = map[uri].class_name .. ': ' .. map[uri].err
    if actual:match(expected1) == nil and actual:match(expected2) == nil then
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

-- check that all errors at NetboxMapCallError has errors metatable
-- and tostring works fine (there is no error in log like: table: 0x41b7b968)
local function assert_multiple_error_str_valid(err)
    local lines = err.str:split('\n')
    for _, line in ipairs(lines) do
        if line:match('^%* table: 0[xX]%x+') then
            local err = string.format(
                'Unexpected error message %q at multiple error.\n' ..
                'Seems there was lost error object metatable', line
            )
            error(err, 2)
        end
    end
end

function g.test_timeout()
    local retmap, errmap = pool.map_call('package.loaded.fiber.sleep', {1}, {
        uri_list = {'localhost:13301'},
        timeout = 0,
    })

    t.assert_equals(retmap, {})
    assert_err_equals(errmap, 'localhost:13301',
        'NetboxCallError: "localhost:13301":' ..
        ' Connection is not established, state is "initial"'
    )

    g.cluster.main_server:eval([[
        _G.simple = function() return 5 end
    ]])

    local retmap, errmap = pool.map_call('_G.simple', nil, {
        uri_list = {'localhost:13301', 'localhost:13311'},
        timeout = 1
    })
    t.assert_equals(retmap, {['localhost:13301'] = 5})
    assert_err_equals(errmap, 'localhost:13311',
        'NetboxCallError: "localhost:13311":' ..
        ' Connection is not established, state is "initial"'
    )
    assert_multiple_error_str_valid(errmap)
end


function g.test_parallel()
    local srv = g.cluster.main_server
    srv:eval([[
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

g.before_test('test_fiber_storage', function()
    g._netbox_call_original = errors.netbox_call
end)

function g.test_fiber_storage()
    -- Test for https://github.com/tarantool/cartridge/issues/1293
    -- pool.map_call spawns new fibers which doesn't preserve fiber
    -- storage needed for TDG request context passing.
    errors.netbox_call = function(conn, fn_name, _, opts)
        local args = {fiber.self().storage.secret}
        return g._netbox_call_original(conn, fn_name, args, opts)
    end

    local srv = g.cluster.main_server
    srv:eval('function _G.echo(...) return ... end')

    local secret = '935052d0-deb5-49a8-995f-c139bfa9dc4f'
    fiber.self().storage.secret = secret
    local map = pool.map_call('_G.echo', nil, {
        uri_list = {
            'localhost:13301',
            'localhost:13302',
        },
    })

    t.assert_equals(map, {
        ['localhost:13301'] = secret,
        ['localhost:13302'] = secret,
    })
end

g.after_test('test_fiber_storage', function()
    -- Revert monkeypatch
    if g._netbox_call_original then
        errors.netbox_call = g._netbox_call_original
    end
    g._netbox_call_original = nil
end)

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
    srv:eval([[
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
    assert_err_equals(errmap, '!@#$%^&*()',      'FormatURIError: Invalid URI "!@#$%^&*()"')
    assert_err_equals(errmap, 'localhost:13301', 'NetboxCallError: "localhost:13301": Too long WAL write')
    assert_err_equals(errmap, 'localhost:13302', 'NetboxCallError: "localhost:13302": Too long WAL write')
    if helpers.tarantool_version_ge('2.10.0') then
        assert_err_matches(errmap, 'localhost:13309', 'NetboxCallError: "localhost:13309": unexpected EOF.*')
    else
        assert_err_matches(errmap, 'localhost:13309', 'NetboxCallError: "localhost:13309": Invalid greeting')
    end
    
    assert_err_matches(errmap, 'localhost:9',
        'NetboxCallError: "localhost:9":.*' .. errno.strerror(errno.ECONNREFUSED),
        'NetboxCallError: "localhost:9": ' .. errno.strerror(errno.ENETUNREACH)
    )
    assert_multiple_error_str_valid(errmap)
end

function g.test_errors_united()
    local srv = g.cluster.main_server
    srv:eval([[
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
    local errs = err.err:split('\n')

    t.assert_equals(errs[1], 'Invalid URI ")(*&^%$#@!"')
    if helpers.tarantool_version_ge('2.10.0') then
        t.assert_str_matches(errs[2], '"localhost:13309": unexpected EOF.*')
    else
        t.assert_str_matches(errs[2], '"localhost:13309": Invalid greeting')
    end
    t.assert_equals(errs[3], '"localhost:13302": Segmentation fault')

    assert_multiple_error_str_valid(err)
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

function g.test_futures()
    -- Make sure 3301 is connected and uses a future
    pool.connect('localhost:13301')

    -- Make sure map_call doesn't spawn new fibers
    local fiber_new_original = fiber.new
    fiber.new = function()
        fiber.new = fiber_new_original
        error('Fiber creation temporarily forbidden', 2)
    end

    local retmap, errmap = pool.map_call('math.abs', {-1}, {
        uri_list = {'localhost:13301'},
    })
    t.assert_equals(retmap, {['localhost:13301'] = 1})
    t.assert_equals(errmap, nil)

    fiber.new = fiber_new_original

    -- Make sure that hanging connection doesn't affect other requests
    local retmap, errmap = pool.map_call('math.abs', {-2}, {
        timeout = 1,
        uri_list = {
            'localhost:13311',
            'localhost:13301',
        },
    })

    t.assert_equals(retmap, {['localhost:13301'] = 2})
    assert_err_equals(errmap, 'localhost:13311',
        'NetboxCallError: "localhost:13311":' ..
        ' Connection is not established, state is "initial"'
    )
end
