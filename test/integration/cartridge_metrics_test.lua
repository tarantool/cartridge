-- luacheck: no max comment line length

-- Based on
-- https://github.com/tarantool/metrics/blob/eb35baf54f687c559420bef020e7a8a1fee57132/test/integration/cartridge_metrics_test.lua

local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_each(function()
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
    helpers.upload_default_metrics_config(g.cluster)
end)

g.after_each(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

g.test_cartridge_issues_present_on_healthy_cluster = function()
    -- In fact, supported since 0.6.0, but cartridge metrics are enabled
    -- together with default ones since 0.10.0.
    t.skip_if(helpers.is_metrics_version_less('0.10.0'), "Not supported in metrics")

    local main_server = g.cluster:server('main')
    local resp = main_server:http_request('get', '/metrics')
    local issues_metric = helpers.find_metric('tnt_cartridge_issues', resp.json)
    t.assert_is_not(issues_metric, nil, 'Cartridge issues metric presents in /metrics response')

    t.helpers.retrying({}, function()
        resp = main_server:http_request('get', '/metrics')
        issues_metric = helpers.find_metric('tnt_cartridge_issues', resp.json)
        for _, v in ipairs(issues_metric) do
            t.assert_equals(v.value, 0, 'Issues count is zero cause new-built cluster should be healthy')
        end
    end)
end

g.test_cartridge_issues_metric_critical = function()
    -- In fact, supported since 0.6.0, but cartridge metrics are enabled
    -- together with default ones since 0.10.0.
    t.skip_if(helpers.is_metrics_version_less('0.10.0'), "Not supported in metrics")

    local main_server = g.cluster:server('main')

    main_server.net_box:eval([[
        box.slab.info = function()
            return {
                items_used = 99,
                items_size = 100,
                arena_used = 99,
                arena_size = 100,
                quota_used = 99,
                quota_size = 100,
            }
        end
    ]])

    t.helpers.retrying({}, function()
        local resp = main_server:http_request('get', '/metrics')
        local issues_metric = helpers.find_metric('tnt_cartridge_issues', resp.json)[2]
        t.assert_equals(issues_metric.value, 1)
        t.assert_equals(issues_metric.label_pairs.level, 'critical')
    end)
end

g.test_clock_delta_metric_present = function()
    t.skip_if(helpers.is_metrics_version_less('0.10.0'), "Not supported in metrics")

    local main_server = g.cluster:server('main')

    t.helpers.retrying({}, function()
        local resp = main_server:http_request('get', '/metrics')
        local clock_delta_metrics = helpers.find_metric('tnt_clock_delta', resp.json)
        t.assert_equals(#clock_delta_metrics, 2)
        t.assert_equals(clock_delta_metrics[1].label_pairs.delta, 'max')
        t.assert_equals(clock_delta_metrics[2].label_pairs.delta, 'min')
    end)
end

g.test_read_only = function()
    t.skip_if(helpers.is_metrics_version_less('0.11.0'), "Not supported in metrics")

    local main_server = g.cluster:server('main')

    local resp = main_server:http_request('get', '/metrics')
    local read_only = helpers.find_metric('tnt_read_only', resp.json)
    t.assert_equals(read_only[1].value, 0)

    local replica_server = g.cluster:server('replica')
    resp = replica_server:http_request('get', '/metrics')
    read_only = helpers.find_metric('tnt_read_only', resp.json)
    t.assert_equals(read_only[1].value, 1)
end

g.test_failover = function()
    t.skip_if(helpers.is_metrics_version_less('0.15.1'), "Not supported in metrics")

    g.cluster:wait_until_healthy()
    g.cluster.main_server:graphql({
        query = [[
            mutation($mode: String) {
                cluster {
                    failover_params(
                        mode: $mode
                    ) {
                        mode
                    }
                }
            }
        ]],
        variables = { mode = 'eventual' },
        raise = false,
    })
    g.cluster:wait_until_healthy()
    g.cluster.main_server:stop()

    helpers.retrying({timeout = 30}, function()
        local resp = g.cluster:server('replica'):http_request('get', '/metrics')
        local failover_trigger_cnt = helpers.find_metric('tnt_cartridge_failover_trigger_total', resp.json)
        t.assert_equals(failover_trigger_cnt[1].value, 1)
    end)

    g.cluster.main_server:start()
    g.cluster:wait_until_healthy()
end
