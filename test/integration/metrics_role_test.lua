-- luacheck: no max comment line length

-- Based on
-- https://github.com/tarantool/metrics/blob/eb35baf54f687c559420bef020e7a8a1fee57132/test/integration/cartridge_role_test.lua

local fio = require('fio')
local t = require('luatest')
local yaml = require('yaml')
local fun = require('fun')
local g = t.group()

local helpers = require('test.helper')

local function assert_counter(name)
    local server = g.cluster.main_server
    g.cluster.main_server.net_box:eval([[
        local cartridge = require('cartridge')
        local metrics = cartridge.service_get('metrics')
        metrics.counter(...):inc(1)
    ]], {name})

    local counter_present = false

    local resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)
    for _, obs in pairs(resp.json) do
        t.assert_equals(
            g.cluster.main_server.alias, obs.label_pairs['alias'],
            ('Alias label is present in metric %s'):format(obs.metric_name)
        )
        if obs.metric_name == name then
            counter_present = true
            t.assert_equals(obs.value, 1)
        end
    end
    t.assert(counter_present)
    g.cluster.main_server.net_box:eval([[
        local cartridge = require('cartridge')
        local metrics = cartridge.service_get('metrics')
        metrics.registry:unregister(metrics.counter(...))
    ]], {name})
end

local function assert_bad_config(config, error)
    local server = g.cluster.main_server
    local resp = server:http_request('put', '/admin/config', {
        body = yaml.encode(config),
        raise = false
    })
    t.assert_str_icontains(resp.json.err, error)
end

local function assert_set_export(path)
    local ret = helpers.set_metrics_export(g.cluster, {
        {
            path = path,
            format = 'json',
        },
    })
    t.assert_not(ret)
end

local function assert_upload_metrics_config(path)
    local server = g.cluster.main_server
    local resp = server:upload_config({
        metrics = {
            export = {
                {
                    path = path,
                    format = 'json'
                },
            },
        }
    })
    t.assert_equals(resp.status, 200)
end


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

g.before_each(function ()
    g.cluster.main_server:upload_config({metrics = { export = {}}})
    helpers.set_metrics_export(g.cluster, {
        {
            path = '/metrics',
            format = 'json',
        },
        {
            path = '/health',
            format = 'health',
        },
    })
end)

g.test_role_enabled = function()
    local resp = g.cluster.main_server.net_box:eval([[
        local cartridge = require('cartridge')
        return cartridge.service_get('metrics') == nil
    ]])
    t.assert_equals(resp, false)
end

g.test_role_add_metrics_http_endpoint = function()
    local server = g.cluster.main_server
    local resp = server:upload_config({
        metrics = {
            export = {
                {
                    path = '/metrics-1',
                    format = 'json'
                },
            },
        }
    })
    t.assert_equals(resp.status, 200)
    assert_counter('test-upload')
    resp = server:upload_config({
        metrics = {
            export = {
                {
                    path = '/metrics-1',
                    format = 'json'
                },
                {
                    path = '/metrics-2',
                    format = 'json'
                },
            },
        }
    })
    t.assert_equals(resp.status, 200)

    g.cluster.main_server.net_box:eval([[
        local cartridge = require('cartridge')
        local httpd = cartridge.service_get('httpd')
        for i = 1, table.maxn(httpd.routes) do
            if httpd.routes[i] == nil then
                error(('There is a gap in httpd.route[%d]'):format(i))
            end
        end
    ]])

    resp = server:http_request('get', '/metrics-1', {raise = false})
    t.assert_equals(resp.status, 200)
    resp = server:http_request('get', '/metrics-2', {raise = false})
    t.assert_equals(resp.status, 200)

    resp = server:upload_config({
        metrics = {
            export = {}
        }
    })
    t.assert_equals(resp.status, 200)
    resp = server:http_request('get', '/new-metrics', {raise = false})
    t.assert_equals(resp.status, 404)

end

g.test_validate_config_invalid_export_section = function()
    assert_bad_config({
        metrics = {
            export = '/metrics',
        },
    }, 'export section must be a table')
end

g.test_validate_config_invalid_top_level_section = function()
    assert_bad_config({
        metrics = {
            metrics = {},
        },
    }, [["metrics" section is already present as a name of "metrics.yml"]]..
    [[don't use it as a top-level section name]])
end

g.test_validate_config_invalid_export_format = function()
    assert_bad_config({
        metrics = {
            export = {
                {
                    path = '/valid-path',
                    format = 'invalid-format'
                },
            },
        }
    }, 'format must be "json", "prometheus" or "health"')
end

g.test_validate_config_duplicate_paths = function()
    assert_bad_config({
        metrics = {
            export = {
                {
                    path = '/metrics',
                    format = 'json'
                },
                {
                    path = '/metrics',
                    format = 'prometheus'
                },
            },
        }
    }, 'paths must be unique')

    assert_bad_config({
        metrics = {
            export = {
                {
                    path = '/metrics',
                    format = 'json'
                },
                {
                    path = 'metrics/',
                    format = 'prometheus'
                },
            },
        }
    }, 'paths must be unique')

    assert_bad_config({
        metrics = {
            export = {
                {
                    path = '/metrics/',
                    format = 'json'
                },
                {
                    path = 'metrics',
                    format = 'prometheus'
                },
            },
        }
    }, 'paths must be unique')
end

g.test_set_export_add_metrics_http_endpoint = function()
    local server = g.cluster.main_server
    local ret = helpers.set_metrics_export(g.cluster, {
        {
            path = '/metrics',
            format = 'json',
        },
    })
    t.assert_not(ret)
    assert_counter('test-set')
    ret = helpers.set_metrics_export(g.cluster, {
        {
            path = '/new-metrics',
            format = 'json',
        },
    })
    t.assert_not(ret)
    local resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 404)
    resp = server:http_request('get', '/new-metrics', {raise = false})
    t.assert_equals(resp.status, 200)

    ret = helpers.set_metrics_export(g.cluster, {})
    t.assert_not(ret)
    resp = server:http_request('get', '/new-metrics', {raise = false})
    t.assert_equals(resp.status, 404)
end

g.test_set_export_validates_input = function()
    local err = helpers.set_metrics_export(g.cluster, {
        {
            path = '/valid-path',
            format = 'invalid-format'
        },
    })
    t.assert_str_icontains(err, 'format must be "json", "prometheus" or "health"')
end

g.test_empty_clusterwide_config_not_overrides_set_export = function()
    local server = g.cluster.main_server
    assert_set_export('/metrics')
    local resp = server:upload_config({})
    t.assert_equals(resp.status, 200)
    resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)
end

g.test_non_empty_clusterwide_config_combines_with_set_export = function()
    local server = g.cluster.main_server
    assert_upload_metrics_config('/metrics')
    assert_set_export('/new-metrics')
    assert_upload_metrics_config('/metrics')
    local resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)
    resp = server:http_request('get', '/new-metrics', {raise = false})
    t.assert_equals(resp.status, 200)
end

g.test_role_change_format_from_config = function()
    local server = g.cluster.main_server
    local resp = server:upload_config({
        metrics = {
            export = {
                {
                    path = '/metrics-1',
                    format = 'json'
                },
            },
        }
    })
    t.assert_equals(resp.status, 200)
    resp = server:http_request('get', '/metrics-1', {raise = false})
    t.assert_equals(resp.status, 200)
    t.assert_equals(resp.body:sub(1,1), '[')

    resp = server:upload_config({
        metrics = {
            export = {
                {
                    path = '/metrics-1',
                    format = 'prometheus'
                },
            },
        }
    })
    t.assert_equals(resp.status, 200)
    resp = server:http_request('get', '/metrics-1', {raise = false})
    t.assert_equals(resp.status, 200)
    t.assert_equals(resp.body:sub(1,1), '#')
end

g.test_role_change_format_from_set_export = function()
    local server = g.cluster.main_server
    helpers.set_metrics_export(g.cluster, {
        {
            path = '/metrics-1',
            format = 'json'
        },
    })
    local resp = server:http_request('get', '/metrics-1', {raise = false})
    t.assert_equals(resp.status, 200)
    t.assert_equals(resp.body:sub(1,1), '[')

    helpers.set_metrics_export(g.cluster, {
        {
            path = '/metrics-1',
            format = 'prometheus'
        },
    })
    t.assert_equals(resp.status, 200)
    resp = server:http_request('get', '/metrics-1', {raise = false})
    t.assert_equals(resp.status, 200)
    t.assert_equals(resp.body:sub(1,1), '#')
end

g.test_role_dont_change_format_from_set_export_to_config = function()
    local server = g.cluster.main_server
    local resp = server:upload_config({
        metrics = {
            export = {
                {
                    path = '/metrics-1',
                    format = 'json'
                },
            },
        }
    })
    t.assert_equals(resp.status, 200)
    resp = server:http_request('get', '/metrics-1', {raise = false})
    t.assert_equals(resp.status, 200)
    t.assert_equals(resp.body:sub(1,1), '[')

    helpers.set_metrics_export(g.cluster, {
        {
            path = '/metrics-1',
            format = 'prometheus'
        },
    })
    t.assert_equals(resp.status, 200)
    resp = server:http_request('get', '/metrics-1', {raise = false})
    t.assert_equals(resp.status, 200)
    -- format doesn't change
    t.assert_equals(resp.body:sub(1,1), '[')
end

g.test_role_change_format_from_config_to_set_export = function()
    local server = g.cluster.main_server
    helpers.set_metrics_export(g.cluster, {
        {
            path = '/metrics-1',
            format = 'json'
        },
    })
    local resp = server:http_request('get', '/metrics-1', {raise = false})
    t.assert_equals(resp.status, 200)
    t.assert_equals(resp.body:sub(1,1), '[')

    resp = server:upload_config({
        metrics = {
            export = {
                {
                    path = '/metrics-1',
                    format = 'prometheus'
                },
            },
        }
    })
    t.assert_equals(resp.status, 200)
    resp = server:http_request('get', '/metrics-1', {raise = false})
    t.assert_equals(resp.status, 200)
    t.assert_equals(resp.body:sub(1,1), '#')
end

g.test_set_export_from_require_role = function()
    local server = g.cluster.main_server
    server.net_box:eval([[
        local metrics = require('cartridge.roles.metrics')
        metrics.set_export(...)
    ]], {{
        {
            path = '/metrics',
            format = 'json',
        },
    }})
    local resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)
end

local function set_zones(zones)
    local servers = {}
    for k, v in pairs(zones) do
        table.insert(servers, {uuid = k, zone = v})
    end
    return g.cluster.main_server.net_box:eval([[
        local servers = ...
        local ret, err = require('cartridge').admin_edit_topology({
            servers = servers,
        })
        if ret == nil then
            return nil, err
        end
        return true
    ]], {servers})
end

g.test_zone_label_present = function()
    local server = g.cluster.main_server

    local ok, err = set_zones({
        [server.instance_uuid] = 'z1',
    })
    t.assert_equals({ok, err}, {true, nil})
    assert_upload_metrics_config('/metrics')

    local resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)
    for _, obs in pairs(resp.json) do
        t.assert_equals(
            'z1', obs.label_pairs['zone'],
            ('Alias label is present in metric %s'):format(obs.metric_name)
        )
    end
end

g.test_zone_label_changes_in_runtime = function()
    local server = g.cluster.main_server
    assert_upload_metrics_config('/metrics')

    local ok, err = set_zones({
        [server.instance_uuid] = 'z2',
    })
    t.assert_equals({ok, err}, {true, nil})

    local resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)
    for _, obs in pairs(resp.json) do
        t.assert_equals(
            'z2', obs.label_pairs['zone'],
            ('Alias label is present in metric %s'):format(obs.metric_name)
        )
    end
end


g.test_add_custom_labels = function()
    t.skip_if(helpers.is_metrics_version_less('0.1.8'), "Not supported in metrics")

    local server = g.cluster.main_server
    server:upload_config({
        metrics = {
            export = {
                {
                    path = '/metrics',
                    format = 'json'
                },
            },
            ['global-labels'] = {
                system = 'some-system',
                app_name = 'myapp',
            }
        }
    })

    local resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)
    for _, obs in pairs(resp.json) do
        t.assert_equals(obs.label_pairs.system, 'some-system')
        t.assert_equals(obs.label_pairs.app_name, 'myapp')
        t.assert_equals(obs.label_pairs.alias, 'main')
    end
end

g.test_add_custom_labels_with_set_labels = function()
    t.skip_if(helpers.is_metrics_version_less('0.1.8'), "Not supported in metrics")

    local server = g.cluster.main_server
    server.net_box:eval([[
        local metrics = require('cartridge.roles.metrics')
        metrics.set_default_labels(...)
    ]], {{
        system = 'some-system',
        app_name = 'myapp',
    }})

    local resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)
    for _, obs in pairs(resp.json) do
        t.assert_equals(obs.label_pairs.system, 'some-system')
        t.assert_equals(obs.label_pairs.app_name, 'myapp')
        t.assert_equals(obs.label_pairs.alias, 'main')
    end
end

g.test_add_custom_labels_with_set_labels_and_config = function()
    t.skip_if(helpers.is_metrics_version_less('0.1.8'), "Not supported in metrics")

    local server = g.cluster.main_server
    server.net_box:eval([[
        local metrics = require('cartridge.roles.metrics')
        metrics.set_default_labels(...)
    ]], {{
        system = 'some-system',
        source = 'api',
    }})
    server:upload_config({
        metrics = {
            export = {
                {
                    path = '/metrics',
                    format = 'json'
                },
            },
            ['global-labels'] = {
                app_name = 'myapp',
                source = 'config',
            }
        }
    })
    local resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)
    for _, obs in pairs(resp.json) do
        t.assert_equals(obs.label_pairs.system, 'some-system')
        t.assert_equals(obs.label_pairs.app_name, 'myapp')
        t.assert_equals(obs.label_pairs.source, 'config')
        t.assert_equals(obs.label_pairs.alias, 'main')
    end
end

g.test_add_custom_labels_with_config_and_set_labels = function()
    t.skip_if(helpers.is_metrics_version_less('0.1.8'), "Not supported in metrics")

    local server = g.cluster.main_server
    server:upload_config({
        metrics = {
            export = {
                {
                    path = '/metrics',
                    format = 'json'
                },
            },
            ['global-labels'] = {
                app_name = 'myapp',
                source = 'config',
            }
        }
    })
    server.net_box:eval([[
        local metrics = require('cartridge.roles.metrics')
        metrics.set_default_labels(...)
    ]], {{
        system = 'some-system',
        source = 'api',
    }})
    local resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)
    for _, obs in pairs(resp.json) do
        t.assert_equals(obs.label_pairs.system, 'some-system')
        t.assert_equals(obs.label_pairs.app_name, 'myapp')
        t.assert_equals(obs.label_pairs.source, 'config')
        t.assert_equals(obs.label_pairs.alias, 'main')
    end
end

g.test_add_custom_labels_with_set_labels_overrides_default = function()
    t.skip_if(helpers.is_metrics_version_less('0.1.8'), "Not supported in metrics")

    local server = g.cluster.main_server
    server.net_box:eval([[
        local metrics = require('cartridge.roles.metrics')
        metrics.set_default_labels(...)
    ]], {{
        system = 'some-system',
    }})
    server.net_box:eval([[
        local metrics = require('cartridge.roles.metrics')
        metrics.set_default_labels(...)
    ]], {{
        app_name = 'myapp',
    }})
    local resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)
    for _, obs in pairs(resp.json) do
        t.assert_not(obs.label_pairs.system)
        t.assert_equals(obs.label_pairs.app_name, 'myapp')
        t.assert_equals(obs.label_pairs.alias, 'main')
    end
end

g.test_invalig_global_labels_format = function()
    assert_bad_config({
        metrics = {
            export = {
                {
                    path = '/metrics',
                    format = 'json'
                },
            },
            ['global-labels'] = 'string',
        }
    }, 'global-labels section must be a table')
end

g.test_invalig_global_labels_names = function()
    assert_bad_config({
        metrics = {
            export = {
                {
                    path = '/metrics',
                    format = 'json'
                },
            },
            ['global-labels'] = {
                zone = 'zone',
            }
        }
    }, 'label name is not allowed to be "zone" or "alias"')

    assert_bad_config({
        metrics = {
            export = {
                {
                    path = '/metrics',
                    format = 'json'
                },
            },
            ['global-labels'] = {
                alias = 'alias',
            }
        }
    }, 'label name is not allowed to be "zone" or "alias"')
    assert_bad_config({
        metrics = {
            export = {
                {
                    path = '/metrics',
                    format = 'json'
                },
            },
            ['global-labels'] = {
                [1] = 'my-label',
            }
        }
    }, 'label name must be a string, got number')
end

g.test_exclude_after_include = function()
    t.skip_if(helpers.is_metrics_version_less('0.10.0'), "Not supported in metrics")

    local server = g.cluster.main_server
    server:upload_config({
        metrics = {
            export = {
                {
                    path = '/metrics',
                    format = 'json'
                },
            },
            include = {
                'vinyl', 'luajit',
            }
        }
    })

    local resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)

    local metrics_cnt = #resp.json
    local vinyl_metrics = fun.iter(resp.json):filter(function(x)
        return x.metric_name:find('tnt_vinyl')
    end):length()
    local lj_metrics = fun.iter(resp.json):filter(function(x)
        return x.metric_name:find('lj_')
    end):length()
    t.assert_equals(metrics_cnt, vinyl_metrics + lj_metrics)

    server:upload_config({
        metrics = {
            export = {
                {
                    path = '/metrics',
                    format = 'json'
                },
            },
            exclude = {
                'vinyl', 'luajit',
            }
        }
    })

    resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)

    metrics_cnt = #resp.json
    t.assert(metrics_cnt >= 0)
    vinyl_metrics = fun.iter(resp.json):filter(function(x)
        return x.metric_name:find('tnt_vinyl')
    end):length()
    t.assert_equals(vinyl_metrics, 0)
    lj_metrics = fun.iter(resp.json):filter(function(x)
        return x.metric_name:find('lj_')
    end):length()
    t.assert_equals(lj_metrics, 0)
end

g.test_exclude_and_include_metrics = function()
    t.skip_if(helpers.is_metrics_version_less('0.16.1'), "Not supported in metrics")

    local server = g.cluster.main_server
    server:upload_config({
        metrics = {
            export = {
                {
                    path = '/metrics/',
                    format = 'json'
                },
            },
            include = { 'info', 'operations' },
            exclude = { 'operations' },
        }
    })

    local resp = server:http_request('get', '/metrics', {raise = false})
    t.assert_equals(resp.status, 200)

    local info_metrics = fun.iter(resp.json):filter(function(x)
        return x.metric_name:find('tnt_info_')
    end):length()
    t.assert_gt(info_metrics, 0)
    local op_metrics = fun.iter(resp.json):filter(function(x)
        return x.metric_name:find('tnt_stats_op_total')
    end):length()
    t.assert_equals(op_metrics, 0)
end
