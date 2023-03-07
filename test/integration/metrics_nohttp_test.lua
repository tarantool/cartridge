-- luacheck: no max comment line length

-- Based on
-- https://github.com/tarantool/metrics/blob/eb35baf54f687c559420bef020e7a8a1fee57132/test/integration/cartridge_nohttp_test.lua

local fio = require('fio')
local t = require('luatest')
local g = t.group('metrics-cartridge-without-http')

local helpers = require('test.helper')

g.test_http_disabled = function()
    local is_metrics_provided = pcall(require, 'metrics')
    t.skip_if(not is_metrics_provided, "metrics not installed")

    local cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_metrics'),
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {
                    {instance_uuid = helpers.uuid('a', 1), alias = 'main'},
                    {instance_uuid = helpers.uuid('b', 1), alias = 'replica'},
                },
            },
        },
    })
    cluster:start()

    local server = cluster.main_server

    server.net_box:eval([[
        local cartridge = require('cartridge')
        _G.old_service = cartridge.service_get('httpd')
        cartridge.service_set('httpd', nil)
    ]])

    local ret = helpers.set_metrics_export(cluster, {
        {
            path = '/metrics',
            format = 'json',
        },
    })
    t.assert_not(ret)

    server.net_box:eval([[
        require('cartridge').service_set('httpd', _G.old_service)
    ]])

    cluster:stop()
    fio.rmtree(cluster.datadir)
end
