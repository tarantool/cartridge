local t = require('luatest')
local g = t.group()
local fio = require('fio')
local yaml = require('yaml')
local utils = require('cartridge.utils')

local helpers = require('test.helper')

g.before_each(function()
    g.tempdir = fio.tempdir()
    g.server = helpers.Server:new({
        alias = 'srv',
        workdir = g.tempdir,
        command = helpers.entrypoint('srv_basic'),
        cluster_cookie = require('digest').urandom(6):hex(),
        advertise_port = 13301,
        http_port = 8081,
    })
end)

g.after_each(function()
    g.server:stop()
    fio.rmtree(g.tempdir)
end)

function g.test_failover_params()
    -- Test the issue https://github.com/tarantool/cartridge/issues/754d
    local instance_uuid = helpers.uuid('a', 'a', 1)
    local replicaset_uuid = helpers.uuid('a')
    utils.file_write(g.tempdir .. '/config.yml', yaml.encode({
        topology = {
            servers = {
                [instance_uuid] = {
                    uri = 'localhost:13301',
                    replicaset_uuid = replicaset_uuid,
                },
            },
            replicasets = {
                [replicaset_uuid] = {
                    roles = {},
                    master = instance_uuid,
                },
            },
            failover = {
                enabled = true,
            },
        },
        vshard_groups = {
            default = {
                bucket_count = 3000,
                bootstrapped = false,
            }
        }
    }))

    g.server:start()
    helpers.retrying({}, function()
        g.server.net_box:eval([[
            local cartridge = package.loaded['cartridge']
            return assert(cartridge) and assert(cartridge.is_healthy())
        ]])
    end)

    local failover_params = g.server:graphql({query = [[mutation{
        cluster { failover_params(mode: "eventual") {
            mode
            state_provider
            tarantool_params {}
        }}
    }]]}).data.cluster.failover_params

    t.assert_equals(failover_params, {
        mode = 'eventual',
        state_provider = box.NULL,
        tarantool_params = box.NULL,
    })
end
