-- Based on
-- https://github.com/tarantool/metrics/blob/eb35baf54f687c559420bef020e7a8a1fee57132/cartridge/roles/metrics.lua

local cartridge = require('cartridge')
local argparse = require('cartridge.argparse')
local hotreload = require('cartridge.hotreload')
local metrics = require('metrics')
-- Backward compatibility with metrics 0.16.0 or older.
local metrics_stash_supported, metrics_stash = pcall(require, 'metrics.stash')
local log = require('log')
local health = require('cartridge.health')

local metrics_vars = require('cartridge.vars').new('metrics_vars')
metrics_vars:new('current_paths', {})
metrics_vars:new('default', {})
metrics_vars:new('config', {})
metrics_vars:new('default_labels', {})
metrics_vars:new('custom_labels', {})

local handlers = {
    ['json'] = function(req)
        local json_exporter = require('metrics.plugins.json')
        return req:render({ text = json_exporter.export() })
    end,
    ['prometheus'] = function(...)
        local http_handler = require('metrics.plugins.prometheus').collect_http
        return http_handler(...)
    end,
    ['health'] = health.default_is_healthy_handler,
}

local function set_labels(custom_labels)
    custom_labels = custom_labels or {}
    local params, err = argparse.parse()
    assert(params, err)
    local this_instance = cartridge.admin_get_servers(box.info.uuid)
    local zone
    if this_instance and this_instance[1] then
        zone = this_instance[1].zone
    end
    local labels = {alias = params.alias or params.instance_name, zone = zone}
    for label, value in pairs(metrics_vars.default_labels) do
        labels[label] = value
    end
    for label, value in pairs(custom_labels) do
        labels[label] = value
    end
    metrics.set_global_labels(labels)
    metrics_vars.custom_labels = custom_labels
end

local function delete_route(httpd, name)
    local route = assert(httpd.iroutes[name])
    httpd.iroutes[name] = nil
    table.remove(httpd.routes, route)

    -- Update httpd.iroutes numeration
    for n, r in ipairs(httpd.routes) do
        if r.name then
            httpd.iroutes[r.name] = n
        end
    end
end

-- removes '/' from start and end of the path to avoid paths duplication
local function remove_side_slashes(path)
    if path:startswith('/') then
        path = path:sub(2)
    end
    if path:endswith('/') then
        path = path:sub(1, -2)
    end
    return path
end

local function validate_routes(export)
    local paths = {}
    for i, v in ipairs(export) do
        if v.path == nil then
            error(('metrics.export[%d]: missing path'):format(i), 0)
        end
        if v.format == nil then
            error(('metrics.export[%d]: missing format'):format(i), 0)
        end
        if type(v.path) ~= 'string' then
            error(('metrics.export[%d]: path must be a string'):format(i), 0)
        end
        if not handlers[v.format] then
            error(('metrics.export[%d]: format must be "json", "prometheus" or "health"'):format(i), 0)
        end
        v.path = remove_side_slashes(v.path)
        if paths[v.path] ~= nil then
            error(('metrics.export[%d]: paths must be unique'):format(i), 0)
        end
        paths[v.path] = true
    end
    return true
end

local function format_paths(export)
    local paths = {}
    for _, exporter in ipairs(export) do
        paths[remove_side_slashes(exporter.path)] = exporter.format
    end
    return paths
end

local function validate_global_labels(custom_labels)
    custom_labels = custom_labels or {}
    for label, _ in pairs(custom_labels) do
        if type(label) ~= 'string' then
            error(('metrics.global-labels[%s]: global label name must be a string, got %s'):
                format(tostring(label), type(label)), 0)
        end
        if label == 'zone' or label == 'alias' then
            error(('metrics.global-labels[%s]: global label name is not allowed to be "zone" or "alias"'):
                format(tostring(label)), 0)
        end
    end
    return true
end

local function validate_config(conf_new)
    conf_new = conf_new.metrics
    if conf_new == nil then
        return true
    end
    if type(conf_new) ~= 'table' then
        error('config must be a table', 0)
    end
    if conf_new.metrics ~= nil then
        error([["metrics" section is already present as a name of "metrics.yml"]]..
            [[don't use it as a top-level section name]], 0)
    end

    if type(conf_new.export or {}) ~= 'table' then
        error('export section must be a table', 0)
    end
    if type(conf_new['global-labels'] or {}) ~= 'table' then
        error('global-labels section must be a table', 0)
    end

    return validate_routes(conf_new.export) and validate_global_labels(conf_new['global-labels'])
end

local function apply_routes(paths)
    local httpd = cartridge.service_get('httpd')
    if httpd == nil then
        return
    end

    for path, format in pairs(metrics_vars.current_paths) do
        if paths[path] ~= format then
            delete_route(httpd, path)
        end
    end

    for path, format in pairs(paths) do
        if metrics_vars.current_paths[path] ~= format then
            httpd:route({
                method = 'GET',
                name = path,
                path = path
            }, handlers[format])
        end
    end

    metrics_vars.current_paths = paths
end

-- removes routes that changed in config and adds new routes
local function apply_config(conf)
    local metrics_conf = conf.metrics or {}
    metrics_conf.export = metrics_conf.export or {}
    set_labels(metrics_conf['global-labels'])
    local paths = format_paths(metrics_conf.export)
    metrics_vars.config = table.copy(paths)
    for path, format in pairs(metrics_vars.default) do
        if paths[path] == nil then
            paths[path] = format
        end
    end
    apply_routes(paths)
    metrics.enable_default_metrics(metrics_conf.include, metrics_conf.exclude)
end

local function set_export(export)
    local ok, err = pcall(validate_routes, export)
    if ok then
        local paths = format_paths(export)
        local current_paths = table.copy(metrics_vars.config)
        for path, format in pairs(paths) do
            if current_paths[path] == nil then
                current_paths[path] = format
            end
        end
        apply_routes(current_paths)
        metrics_vars.default = paths
        log.info('Set default metrics endpoints')
    else
        error(err)
    end
end

local function set_default_labels(default_labels)
    local ok, err = pcall(validate_global_labels, default_labels)
    if ok then
        metrics_vars.default_labels = default_labels
        set_labels(metrics_vars.custom_labels)
    else
        error(err, 0)
    end
end

local function init()
    set_labels(metrics_vars.custom_labels)
    metrics.enable_default_metrics()
    local current_paths = table.copy(metrics_vars.config)
    for path, format in pairs(metrics_vars.default) do
        if current_paths[path] == nil then
            current_paths[path] = format
        end
    end
    apply_routes(current_paths)

    hotreload.whitelist_globals({'__metrics_registry'})

    -- Backward compatibility with metrics 0.16.0 or older.
    if metrics_stash_supported then
        metrics_stash.setup_cartridge_reload()
    end
end

local function stop()
    local httpd = cartridge.service_get('httpd')
    if httpd ~= nil then
        for path, _ in pairs(metrics_vars.current_paths) do
            delete_route(httpd, path)
        end
    end

    metrics_vars.current_paths = {}
    metrics_vars.config = {}
    metrics_vars.custom_labels = {}
end

local function set_is_health_handler(new_handler)
    handlers['health'] = new_handler or health.default_is_healthy_handler

    local paths = table.copy(metrics_vars.current_paths)
    for path, _ in pairs(metrics_vars.current_paths) do
        metrics_vars.current_paths[path] = ''
    end

    apply_routes(paths)
end

return setmetatable({
    role_name = 'metrics',
    permanent = true,
    init = init,
    stop = stop,
    validate_config = validate_config,
    apply_config = apply_config,
    set_export = set_export,
    set_default_labels = set_default_labels,
    set_is_health_handler = set_is_health_handler,
}, { __index = metrics })
