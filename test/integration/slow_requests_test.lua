local fio = require('fio')
local fiber = require('fiber')
local netbox = require('net.box')
local utils = require('cartridge.utils')

local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.expected_request_time = 2
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {{
            alias = 'main',
            roles = {},
            servers = 2
        }}
    })
    g.cluster:start()
    g.s1 = g.cluster:server('main-1')
    g.s2 = g.cluster:server('main-2')
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

g.before_each(function()
    g.s2.process:kill('STOP')
    -- create config.prepare to check issues will be shown for available instances
    -- (pool.map_call works correctly)
    utils.file_write(fio.pathjoin(g.s1.workdir, 'config.prepare'), 'prepare')
    g.s1:eval([[
        require('cartridge.pool').connect(...):close()
    ]], {g.s2.advertise_uri, {wait_connected = false}})
end)

g.after_each(function()
    g.s2.process:kill('CONT')
end)

local function graphql_bench(srv, args)
    local t1 = fiber.clock()
    local resp = srv:graphql(args)
    local t2 = fiber.clock()

    return t2 - t1, resp
end

function g.test_boxinfo()
    local time, resp = graphql_bench(g.s1, {
        query = '{servers {boxinfo {general {pid}}}}',
    })
    helpers.assert_le(time, 2)
    t.assert_equals(#resp.data.servers, 2)
end

function g.test_stat()
    local time, resp = graphql_bench(g.s1, {
        query = [[query($uuid: String!) {
            servers(uuid: $uuid) {statistics {arena_size}}
        }]],
        variables = {uuid = g.s2.instance_uuid},
    })
    helpers.assert_le(time, 2)
    t.assert_equals(resp.data.servers[1].statistics, box.NULL)
end

function g.test_issues()
    local time, resp = graphql_bench(g.s1, {
        query = '{cluster {issues {message}}}',
    })
    helpers.assert_le(time, 2)
    t.assert_equals(resp.data.cluster.issues[1].message,
        'Configuration is prepared and locked on localhost:13301 (main-1)'
    )
end

function g.test_suggestions()
    local time, resp = graphql_bench(g.s1, {
        query = [[{
            cluster {suggestions {
                force_apply {uuid}
                refine_uri {uuid}
                disable_servers {uuid}
            }}
        }]],
    })
    helpers.assert_le(time, 2)
    t.assert_equals(resp.data.cluster.suggestions.force_apply[1].uuid,
        g.s1.instance_uuid
    )
end

function g.test_netbox_timeouts()
    local t0 = fiber.clock()

    local conn = netbox.connect(g.s2.advertise_uri, {
        wait_connected = false,
        user = 'admin',
        password = g.cookie,
        connect_timeout = 1,
    })
    t.assert_covers(conn, {state = 'initial'})

    -- Async request will fail.
    -- Tarantool calls:
    -- - remote_methods:_request
    -- - transport.perform_async_request
    t.assert_error_msg_contains(
        'Connection is not established, state is "initial"',
        conn.eval, conn, "return 'something'", nil, {is_async = true}
    )
    t.assert_covers(conn, {state = 'initial'})

    -- Tarantool calls:
    -- - remote_methods:_request
    -- - wait_state('active', 1)
    -- - transport.perform_request
    -- - transport.perform_async_request
    local t1 = fiber.clock()
    t.assert_error_msg_contains(
        'Connection is not established, state is "initial"',
        conn.eval, conn, "return 'something'", nil, {timeout = 0.3}
    )
    local t2 = fiber.clock()
    t.assert_covers(conn, {state = 'initial'})
    t.assert_almost_equals(t2-t1, 0.3, 0.15)

    -- check that connection have status error after connect_timeout
    -- perform nb call -> remote_methods:_request ->
    -- wait_state('active', TIMEOUT_INF) -> establish_connection will
    -- fail after connect timeout
    t.assert_error_msg_matches(
        ".*timed out",
        conn.eval, conn, "return 'something'", nil
    )
    t.assert_covers(conn, {
        state = 'error',
    })
    t.assert_str_matches(conn.error, ".*timed out")

    t.assert_almost_equals(fiber.clock()-t0, 1, 0.3)
end
