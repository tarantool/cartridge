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
                        advertise_port = 13301,
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
                        advertise_port = 13311,
                        http_port = 8091
                    }, {
                        alias = 'storage-2',
                        instance_uuid = helpers.uuid('d', 'd', 2),
                        advertise_port = 13312,
                        http_port = 8092
                    }
                }
            }
        }
    })

    g.server3 = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'server3',
        command = test_helper.server_command,
        replicaset_uuid = helpers.uuid('a'),
        instance_uuid = helpers.uuid('a', 'a', 2),
        http_port = 8082,
        cluster_cookie = 'super-cluster-cookie',
        advertise_port = 13302,
    })
    g.server4 = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'server4',
        command = test_helper.server_command,
        replicaset_uuid = helpers.uuid('d'),
        instance_uuid = helpers.uuid('d', 'd', 3),
        http_port = 8093,
        cluster_cookie = 'super-cluster-cookie',
        advertise_port = 13313,
    })

    g.cluster:start()
    g.server3:start()
    g.server4:start()
end

g.after_all = function()
    g.cluster:stop()
    g.server3:stop()
    g.server4:stop()

    fio.rmtree(g.cluster.datadir)
    fio.rmtree(g.server3.workdir)
    fio.rmtree(g.server4.workdir)
end

function g.test_edit_join_expel()
    local code = os.execute(
        "cd webui && npx cypress run --spec" ..
        " cypress/integration/edit-replicaset.spec.js" ..
        ",cypress/integration/expel-server.spec.js" ..
        ",cypress/integration/join-replicaset.spec.js" ..
        ",cypress/integration/search.spec.js"
    )
    t.assert_equals(code, 0)
end

