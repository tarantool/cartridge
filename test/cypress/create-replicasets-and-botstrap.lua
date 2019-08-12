local fio = require('fio')
local t = require('luatest')
local g = t.group('cypress_create_replicasets_and_botstrap')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.server1 = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'server1',
        command = test_helper.server_command,
        replicaset_uuid = helpers.uuid('с'),
        instance_uuid = helpers.uuid('b', 'b', 3),
        http_port = 8081,
        cluster_cookie = 'super-cluster-cookie',
        advertise_port = 33001,
    })
    g.server2 = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'server2',
        command = test_helper.server_command,
        replicaset_uuid = helpers.uuid('с'),
        instance_uuid = helpers.uuid('b', 'b', 3),
        http_port = 8082,
        cluster_cookie = 'super-cluster-cookie',
        advertise_port = 33002,
    })
    g.server3 = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'server3',
        command = test_helper.server_command,
        replicaset_uuid = helpers.uuid('с'),
        instance_uuid = helpers.uuid('b', 'b', 3),
        http_port = 8083,
        cluster_cookie = 'super-cluster-cookie',
        advertise_port = 33003,
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
    g.server1:start()
    g.server2:start()
    g.server3:start()
    g.server4:start()
    g.server5:start()

end

g.after_all = function()
    g.server1:stop()
    g.server2:stop()
    g.server3:stop()
    g.server4:stop()
    g.server5:stop()
    fio.rmtree(g.server1.workdir)
    fio.rmtree(g.server2.workdir)
    fio.rmtree(g.server3.workdir)
    fio.rmtree(g.server4.workdir)
    fio.rmtree(g.server5.workdir)

end

function g.test_cypress_run()
    local code = os.execute("cd webui && npx cypress run --spec cypress/integration/create-replicasets-and-botstrap.spec.js")
    t.assert_equals(code, 0)
end
