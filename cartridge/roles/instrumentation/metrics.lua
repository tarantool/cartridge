local cartridge = require("cartridge")
local argparse = require("cartridge.argparse")
local metrics = require("metrics")

local handlers = {
  ['json'] = function(req)
      local json_exporter = require("metrics.plugins.json")
      return req:render({ text = json_exporter.export() })
  end,
  ['prometheus'] = function(...)
      local http_handler = require("metrics.plugins.prometheus").collect_http
      return http_handler(...)
  end,
}

local collectors = {
  ['default'] = function(...)
      metrics.enable_default_metrics()
  end
}

local function init()
    local params, err = argparse.parse()
    if err ~= nil then
        return err
    end
end

local function validate_config(conf_new, conf_old)
    --[[
    metrics:
      export:
        - path: "/metrics/json"
          format: "json"
        - path: "/metrics/prom"
          format: "prometheus"
      collect:
        default:
    ]]

    return true
end

local function apply_config(conf)
    local metrics_conf = conf.metrics
    if metrics_conf == nil then
        return true
    end

    for name, opts in pairs(metrics_conf.collect) do
        collectors[name](opts)
    end

    local httpd = cartridge.service_get("httpd")
    for _, exporter in ipairs(metrics_conf.export) do
        httpd:route({method = "GET", path = exporter.path}, handlers[exporter.format])
    end
end

return {
    role_name = 'metrics',

    init = init,
    validate_config = validate_config,
    apply_config = apply_config
}
