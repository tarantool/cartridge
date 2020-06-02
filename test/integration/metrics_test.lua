local fio = require('fio')
local t = require('luatest')
local g = t.group()
local json = require("json")

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {
                  'metrics'
                },
                servers = {
                    {
                        alias = 'main',
                        http_port = 8081,
                        advertise_port = 13301,
                        instance_uuid = helpers.uuid('a', 'a', 1)
                    }
                },
            },
        },
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

g.test_role_enabled = function()
    local resp = g.cluster.main_server.net_box:eval([[
      local cartridge = require("cartridge")
      return cartridge.service_get("metrics") == nil
    ]])
    t.assert_equals(resp, false)
end

g.test_role_add_metrics_http_endpoint = function()
    local server = g.cluster.main_server
    local resp = server:http_request('put', '/admin/config', {
        body = json.encode({
          metrics = {
            export = {
              {
                path = "/metrics",
                format = "json"
              }
            },
            collect = {
              default = {},
            }
          }
        }),
        raise = false
    })

    local resp = server:http_request('get', '/metrics')
    t.assert_equals(resp.status, 200)
end
