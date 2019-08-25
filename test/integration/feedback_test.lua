local fio = require('fio')
local t = require('luatest')
local g = t.group('feedback')

local log = require('log')
local json = require('json')
local http = require('http.server')
local fiber = require('fiber')
local test_helper = require('test.helper')
local helpers = require('cluster.test_helpers')

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
        server_command = test_helper.server_command,
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
end
g.after_all = function()
    g.httpd:stop()
    g.cluster:stop()
    fio.rmtree(g.tempdir)
end

function g.test_feedback()
    local msg = ch:get(2)
    t.assertIsTable(msg, 'No feedback received')
    log.info('Feedback: %s', json.encode(msg))
    t.assertEquals(msg.server_id, helpers.uuid('a', 'a', 1))
    t.assertEquals(msg.cluster_id, helpers.uuid('a'))
    t.assertIsString(msg.rocks.cluster)
end
