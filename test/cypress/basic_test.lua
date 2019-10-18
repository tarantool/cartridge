local fio = require('fio')
local t = require('luatest')
local g = t.group('cypress_basic')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.setup = function()
	g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        use_vshard = true,
        cookie = 'test-cluster-cookie',

        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = {
                    {
                        alias = 'router',
                        instance_uuid = helpers.uuid('a', 'a', 1),
                        advertise_port = 33001,
                        http_port = 8081
                    }
                }
            }, {
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                servers = {
                    {
                        alias = 'storage',
                        instance_uuid = helpers.uuid('b', 'b', 1),
                        advertise_port = 33002,
                        http_port = 8082
                    }, {
                        alias = 'storage-2',
                        instance_uuid = helpers.uuid('b', 'b', 2),
                        advertise_port = 33004,
                        http_port = 8084
                    }
                }
            }
        }
    })

    g.server = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'spare',
        command = test_helper.server_command,
        replicaset_uuid = helpers.uuid('с'),
        instance_uuid = helpers.uuid('b', 'b', 3),
        http_port = 8085,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 33010,
    })

    g.cluster:start()
    g.server:start()

    t.helpers.retrying({timeout = 5}, function()
        g.server:graphql({query = '{}'})
    end)
end

g.teardown = function()
    g.cluster:stop()
    g.server:stop()
    fio.rmtree(g.cluster.datadir)
    fio.rmtree(g.server.workdir)
end

function g.test_cypress_run()
    local code = os.execute("cd webui && npx cypress run --spec cypress/integration/probe-server.spec.js")
    t.assert_equals(code, 0)
end
