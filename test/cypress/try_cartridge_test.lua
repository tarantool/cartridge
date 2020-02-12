local fio = require('fio')
local t = require('luatest')
local g = t.group()

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.setup = function()
	g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = fio.pathjoin(test_helper.root, 'test', 'integration', 'srv_basic.lua'),
        use_vshard = false,
        cookie = 'test-cluster-cookie',

        replicasets = {
            {
                alias = 'router1-do-not-use-me',
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {
                    {
                        alias = 'router',
                        instance_uuid = helpers.uuid('a', 'a', 1),
                    }
                }
            }
        }
    })

    g.cluster:start()

    g.cluster.main_server.net_box:eval([[
        os.setenv('TARANTOOL_DEMO_URI', 'admin:password@try-cartridge.tarantool.io:26333')
    ]])

end

g.teardown = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
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

function g.test_demo_panel_present()
    cypress_run('demo-panel-present.spec.js')
end
