local fio = require('fio')
local t = require('luatest')
local g = t.group()

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
                alias = 'router1-do-not-use-me',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
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
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                servers = {
                    {
                        alias = 'storage',
                        instance_uuid = helpers.uuid('b', 'b', 1),
                        advertise_port = 13302,
                        http_port = 8082
                    }, {
                        alias = 'storage-2',
                        instance_uuid = helpers.uuid('b', 'b', 2),
                        advertise_port = 13304,
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
        advertise_port = 13310,
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

local function cypress_run(spec)
    local code = os.execute(
        "cd webui && npx cypress run --spec " ..
        fio.pathjoin('cypress/integration', spec)
    )
    if code ~= 0 then
        error('Cypress spec "' .. spec .. '" failed', 2)
    end
    t.assert_equals(code, 0)
end

function g.test_default_group()
    g.cluster.main_server:graphql({
        query = [[mutation {
            probe_server(
                uri: "localhost:13310"
            )
        }]]
    })
    cypress_run('default-group-test.spec.js')
end

function g.test_text_inputs()
    g.cluster.main_server:graphql({
        query = [[mutation {
            probe_server(
                uri: "localhost:13310"
            )
        }]]
    })
    cypress_run('text-inputs-tests.spec.js')
end

function g.test_probe_server()
    cypress_run('probe-server.spec.js')
end

function g.test_failover()
    cypress_run('failover.spec.js')
end

function g.test_users()
    local code = os.execute(
        "cd webui && npx cypress run --spec" ..
        ' cypress/integration/auth.spec.js' ..
        ',cypress/integration/add-user.spec.js' ..
        ',cypress/integration/edit-user.spec.js' ..
        ',cypress/integration/remove-user.spec.js' ..
        ',cypress/integration/server-details.spec.js' ..
        ',cypress/integration/login-and-logout.spec.js'..
        ',cypress/integration/auth-switcher-not-moved.spec.js'
    )
    t.assert_equals(code, 0)
end

function g.test_schema_editor()
    cypress_run('schema-editor.spec.js')
end
