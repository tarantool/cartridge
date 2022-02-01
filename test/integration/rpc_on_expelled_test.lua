local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'myrole'},
                servers = {
                    {
                        alias = 'main',
                    }
                }
            }, {
                uuid = helpers.uuid('c'),
                roles = {},
                servers = {
                    {
                        alias = 'expelled',
                    }
                }
            }
        }
    })

    g.cluster:start()

    g.cluster:server('expelled'):stop()
    g.cluster:server('main'):graphql({
        query = [[
            mutation($uuid: String!) {
                expel_server(uuid: $uuid)
            }
        ]],
        variables = {
            uuid = g.cluster:server('expelled').instance_uuid
        }
    })

    g.cluster:server('expelled'):start()
    g.cluster:wait_until_healthy(g.cluster:server('expelled'))
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

g.test_rpc_on_expelled = function()
    t.xfail("You can perform rpc calls on expelled instances. It's a bug. See #1726")
    local res, err = g.cluster:server('expelled'):exec(function()
        local cartridge = require('cartridge')
        return cartridge.rpc_call('myrole', 'dog_goes')
    end)

    t.assert_not_equals(res, 'woof')
    t.assert(err)
end
