local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.setup = function()
    g.datadir = fio.tempdir()

    fio.mktree(fio.pathjoin(g.datadir, 'stateboard'))
    g.kvpassword = 'password'
    g.stateboard = require('luatest.server'):new({
        command = helpers.entrypoint('srv_stateboard'),
        workdir = fio.pathjoin(g.datadir, 'stateboard'),
        net_box_port = 14401,
        net_box_credentials = {
            user = 'client',
            password = g.kvpassword,
        },
        env = {
            TARANTOOL_LOCK_DELAY = 1,
            TARANTOOL_PASSWORD = g.kvpassword,
        },
    })
    g.stateboard:start()
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
    end)

	g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = 'test-cluster-cookie',
        env = {
            TARANTOOL_SWIM_SUSPECT_TIMEOUT_SECONDS = 0,
            TARANTOOL_APP_NAME = 'cartridge-testing',
        },
        replicasets = {
            {
                alias = 'router1-do-not-use-me',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = {
                    {
                        alias = 'router',
                        env = {TARANTOOL_INSTANCE_NAME = 'r1'},
                        instance_uuid = helpers.uuid('a', 'a', 1),
                        advertise_port = 13301,
                        http_port = 8081
                    }
                }
            }, {
                alias = 'storage1-do-not-use-me',
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage', 'failover-coordinator'},
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
        command = helpers.entrypoint('srv_basic'),
        replicaset_uuid = helpers.uuid('с'),
        instance_uuid = helpers.uuid('b', 'b', 3),
        http_port = 8085,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13310,
        env = {
            TARANTOOL_WEBUI_BLACKLIST = '/cluster/configuration',
            TARANTOOL_SWIM_SUSPECT_TIMEOUT_SECONDS = 1,
        },
    })

    g.cluster:start()
    g.server:start()

    t.helpers.retrying({timeout = 5}, function()
        g.server:graphql({query = '{}'})
    end)
end

g.teardown = function()
    for _, srv in pairs(g.cluster.servers) do
        srv.process:kill('CONT')
    end
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
    local code = os.execute(
        "cd webui && npx cypress run --spec" ..
        ' cypress/integration/probe-server.spec.js' ..
        ',cypress/integration/demo-panel-not-present.spec.js'
    )
    t.assert_equals(code, 0)
end

function g.test_failover()
    cypress_run('failover.spec.js')
end

function g.test_users()
    local code = os.execute(
        "cd webui && npx cypress run --spec" ..
        ' cypress/integration/auth.spec.js' ..
        ',cypress/integration/users.spec.js' ..
        ',cypress/integration/server-details.spec.js' ..
        ',cypress/integration/server-details-dead-server.spec.js' ..
        ',cypress/integration/login-and-logout.spec.js'..
        ',cypress/integration/auth-switcher-not-moved.spec.js'
    )
    t.assert_equals(code, 0)
end

function g.test_schema_editor()
    cypress_run('schema-editor.spec.js')
end

function g.test_code()
    local code = os.execute(
        "cd webui && npx cypress run --spec" ..
        ' cypress/integration/code-empty-page.spec.js' ..
        ',cypress/integration/code-file-in-tree.spec.js' ..
        ',cypress/integration/code-folder-in-tree.spec.js'
    )
    t.assert_equals(code, 0)
end

function g.test_uninitialized()
    local code = os.execute(
        'cd webui && npx cypress run' ..
        ' --config baseUrl="http://localhost:8085"' ..
        ' --spec' ..
        ' cypress/integration/uninitialized.spec.js' ..
        ',cypress/integration/blacklist-pages.spec.js'
    )
    t.assert_equals(code, 0)
end

function g.test_offline_splash()
    cypress_run('network-error-splash.spec.js')
end

function g.test_401()
    g.cluster.main_server.net_box:eval([[
        local cartridge = require('cartridge')
        local httpd = cartridge.service_get('httpd')
        for _, route in ipairs(httpd.routes) do
            if route.path == '/admin/api' then
                if route.method == 'POST' then
                    local _sub = route.sub
                    route.sub = function(req)
                        cartridge.http_authorize_request(req)
                        if cartridge.http_get_username() ~= 'admin' then
                            return {status = 401}
                        end

                        return _sub(req)
                    end
                end
            end
        end
    ]])
    -- require('fiber').sleep(1000)
    cypress_run('401-error.spec.js')
end

function g.test_leader_promotion()
    cypress_run('leader-promotion.spec.js')
end

function g.test_replicaset_filtering()
    g.cluster.main_server:graphql({
        query = [[mutation {
            probe_server(
                uri: "localhost:13310"
            )
        }]]
    })
    cypress_run('replicaset-filtering.spec.js')
end
