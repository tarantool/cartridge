-- luacheck: no max comment line length

-- Based on
-- https://github.com/tarantool/metrics/blob/eb35baf54f687c559420bef020e7a8a1fee57132/test/integration/cartridge_health_test.lua

local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    local is_metrics_provided = pcall(require, 'metrics')
    t.skip_if(not is_metrics_provided, "metrics not installed")

    g.cluster = helpers.Cluster:new({
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
    g.cluster:start()
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

g.after_each(function()
    local main_server = g.cluster:server("main")
    main_server:exec(function()
        local membership = package.loaded['membership']
        membership.myself = function()
            return {
                status = 'alive',
                payload = {
                    state='RolesConfigured',
                    state_prev='ConfiguringRoles',
                }
            }
        end
    end)
end)

g.after_test('test_metrics_custom_is_health_handler', function()
    local main_server = g.cluster:server('main')
    main_server:exec(function()
        local cartridge = require('cartridge')
        local metrics = cartridge.service_get('metrics')
        metrics.set_is_health_handler(nil)
    end)
end)

g.test_metrics_health_handler = function()
    helpers.upload_default_metrics_config(g.cluster)
    local main_server = g.cluster:server('main')
    local resp = main_server:http_request('get', '/health', {raise = false})
    t.assert_equals(resp.status, 200)
    t.assert_equals(resp.body, 'main is OK')
end

g.test_metrics_custom_is_health_handler = function()
    local main_server = g.cluster:server('main')
    main_server:exec(function()
        local cartridge = require('cartridge')
        local metrics = cartridge.service_get('metrics')
        metrics.set_is_health_handler(function(req)
            local health = require('cartridge.health')
            local resp = req:render{
                json = {
                    my_healthcheck_format = health.is_healthy()
                }
            }
            resp.status = 200
            return resp
        end)
    end)

    helpers.upload_default_metrics_config(g.cluster)
    local resp = main_server:http_request('get', '/health', {raise = false})
    t.assert_equals(resp.status, 200)
    t.assert_equals(type(resp.json), 'table')
    t.assert_equals(resp.json, { my_healthcheck_format = true })
end

g.test_metrics_health_fail_handler = function()
    helpers.upload_default_metrics_config(g.cluster)
    local main_server = g.cluster:server('main')
    main_server.net_box:eval([[
        _G.old_info = box.info
        box.info = {
            status = 'orphan',
        }
    ]])
    local resp = main_server:http_request('get', '/health', {raise = false})
    t.assert_equals(resp.status, 500)
    main_server.net_box:eval([[
        box.info = _G.old_info
    ]])
end

g.test_metrics_health_handler_member_alive_state_configured_to_configuring = function()
    helpers.upload_default_metrics_config(g.cluster)
    local main_server = g.cluster:server("main")

    main_server:exec(function()
        local membership = package.loaded['membership']
        membership.myself = function()
            return {
                status = 'alive',
                payload = {
                    state='ConfiguringRoles',
                    state_prev='RolesConfigured',
                }
            }
        end
    end)

    local resp = main_server:http_request("get", "/health", {raise = false})
    t.assert_equals(resp.status, 200)
    t.assert_equals(resp.body, "main is OK")
end

g.test_metrics_health_handler_member_suspect_state_configured_to_configuring = function()
    helpers.upload_default_metrics_config(g.cluster)
    local main_server = g.cluster:server("main")

    main_server:exec(function()
        local membership = package.loaded['membership']
        membership.myself = function()
            return {
                status = 'suspect',
                payload = {
                    state='ConfiguringRoles',
                    state_prev='RolesConfigured',
                }
            }
        end
    end)

    local resp = main_server:http_request("get", "/health", {raise = false})
    t.assert_equals(resp.status, 200)
end

g.test_metrics_health_handler_member_alive_state_boxconfigured_to_configuring = function()
    helpers.upload_default_metrics_config(g.cluster)
    local main_server = g.cluster:server("main")

    main_server:exec(function()
        local membership = package.loaded['membership']
        membership.myself = function()
            return {
                status = 'alive',
                payload = {
                    state='ConfiguringRoles',
                    state_prev='BoxConfigured',
                }
            }
        end
    end)

    local resp = main_server:http_request("get", "/health", {raise = false})
    t.assert_equals(resp.status, 500)
end

g.test_metrics_health_handler_member_suspect_state_boxconfigured_to_configuring = function()
    helpers.upload_default_metrics_config(g.cluster)
    local main_server = g.cluster:server("main")

    main_server:exec(function()
        local membership = package.loaded['membership']
        membership.myself = function()
            return {
                status = 'suspect',
                payload = {
                    state='ConfiguringRoles',
                    state_prev='BoxConfigured',
                }
            }
        end
    end)

    local resp = main_server:http_request("get", "/health", {raise = false})
    t.assert_equals(resp.status, 500)
end
