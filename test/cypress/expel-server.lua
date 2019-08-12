local fio = require('fio')
local t = require('luatest')
local g = t.group('cypress_basic')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        use_vshard = true,
        cookie = 'super-cluster-cookie',

        replicasets = {
            {
                alias = 'router1-do-not-use-me',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router', 'myrole', 'myrole-dependency'},
                servers = {
                    {
                        alias = 'router',
                        instance_uuid = helpers.uuid('a', 'a', 1),
                        advertise_port = 33001,
                        http_port = 8081
                    }
                }
            }, {
                alias = 'storage1-do-not-use-me',
                uuid = helpers.uuid('d'),
                roles = {'vshard-storage'},
                servers = {
                    {
                        alias = 'storage-1',
                        instance_uuid = helpers.uuid('d', 'd', 1),
                        advertise_port = 33002,
                        http_port = 8082
                    }, { 
                        alias = 'storage-2',
                        instance_uuid = helpers.uuid('d', 'd', 2),
                        advertise_port = 33003,
                        http_port = 8083
                    }
                }
            }
        }
    })

    g.server4 = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'server4',
        command = test_helper.server_command,
        replicaset_uuid = helpers.uuid('с'),
        instance_uuid = helpers.uuid('b', 'b', 3),
        http_port = 8084,
        cluster_cookie = 'super-cluster-cookie',
        advertise_port = 33004,
    })
    g.server5 = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'server5',
        command = test_helper.server_command,
        replicaset_uuid = helpers.uuid('с'),
        instance_uuid = helpers.uuid('b', 'b', 3),
        http_port = 8085,
        cluster_cookie = 'super-cluster-cookie',
        advertise_port = 33005,
    })
    g.cluster:start()
    g.server4:start()
    g.server5:start()

end

g.after_all = function()
    g.cluster:stop()
    g.server4:stop()
    g.server5:stop()
    fio.rmtree(g.cluster.datadir)
    fio.rmtree(g.server4.workdir)
    fio.rmtree(g.server5.workdir)

end

function g.test_cypress_run()
    local code = os.execute("cd webui && npx cypress run --spec cypress/integration/expel-server.spec.js")
    t.assert_equal(code, 0)
end
