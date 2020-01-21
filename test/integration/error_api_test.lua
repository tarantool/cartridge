local fio = require('fio')
local t = require('luatest')
local g = t.group()

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        use_vshard = true,
        cookie = 'test-cluster-cookie',

        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {'vshard-router', 'vshard-storage'},
            servers = {
                {
                    alias = 'main',
                    instance_uuid = helpers.uuid('a', 'a', 1),
                    advertise_port = 13301,
                    http_port = 8081,
                }
            }
        }}
    })

    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_disable()
    local error_resp = g.cluster.main_server:graphql({query = [[
        mutation($uuids: [String!]) {
            cluster {
                disable_servers(uuids: $uuids) {}
            }
        }]],
        variables = {uuids = {helpers.uuid('a', 'a', 1)}},
        raise = false
    }).errors[1]

    t.assert_str_icontains(
        error_resp.extensions['io.tarantool.errors.stack'],
        'stack traceback:'
    )

    error_resp.extensions['io.tarantool.errors.stack'] = nil
    t.assert_equals(
        error_resp, {
            message = 'Current instance "localhost:13301" can not be disabled',
            extensions = {
                ['io.tarantool.errors.class_name'] = 'Invalid cluster topology config',
                ['io.tarantool.errors.stack'] = nil, -- already checked above
            }
        }
    )
end
