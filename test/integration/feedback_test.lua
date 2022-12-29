local fio = require('fio')
local t = require('luatest')
local g = t.group()

local log = require('log')
local json = require('json')
local http = require('http.server')
local fiber = require('fiber')
local helpers = require('test.helper')

local ch = fiber.channel(0)
local function handle_feedback(req)
    ch:put(req:json(), 0)
end

g.before_all = function()
    g.tempdir = fio.tempdir()

    g.httpd = http.new('127.0.0.1', nil, {log_requests = false})
    g.httpd:start()

    g.httpd:route({
        path = '/',
        method = 'POST'
    }, handle_feedback)


    local feedback_host = string.format('http://127.0.0.1:%d',
        g.httpd.tcp_server:name().port
    )

    g.cluster = helpers.Cluster:new({
        datadir = g.tempdir,
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {
            {
                alias = 'initial-alias',
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {{
                    instance_uuid = helpers.uuid('a', 'a', 1),
                    env = {
                        TARANTOOL_FEEDBACK_INTERVAL = 1,
                        TARANTOOL_FEEDBACK_HOST = feedback_host,
                    },
                }},
            },
        },
    })
    g.cluster:start()

    g.msg = ch:get(2)
    t.assert_type(g.msg, 'table', 'No feedback received')
    log.info('Feedback: %s', json.encode(g.msg))
end

g.after_all = function()
    g.httpd:stop()
    g.cluster:stop()
    fio.rmtree(g.tempdir)
end

function g.test_feedback()
    t.assert_equals(g.msg.server_id, helpers.uuid('a', 'a', 1))
    t.assert_equals(g.msg.cluster_id, helpers.uuid('a'))
    t.assert_type(g.msg.rocks.cartridge, 'string')
end

function g.test_app_name()
    t.skip_if(
        package.setsearchroot == nil,
        'package.searchroot not implemented'
    )

    t.assert_equals(g.msg.app_name, 'cartridge')
    t.assert_equals(g.msg.app_version, 'app_version_test_value')
end

function g.test_rocks()
    t.skip_if(
        package.setsearchroot == nil,
        'package.searchroot not implemented'
    )

    t.assert_type(g.msg.rocks.http, 'string')
end
