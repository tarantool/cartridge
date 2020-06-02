local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.setup = function()
    local t1 = require('clock').time()
	g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_woauth'),
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
    local t2 = require('clock').time()
    require('log').info('before_each: %s', t2-t1)
end

g.teardown = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function cypress_run(spec)
    local code = os.execute(
        "cd webui && time -f \"npx_cypress_run %E\" npx cypress run --spec " ..
        fio.pathjoin('cypress/integration', spec)
    )
    if code ~= 0 then
        error('Cypress spec "' .. spec .. '" failed', 2)
    end
    t.assert_equals(code, 0)
end

function g.test_auth_switcher_moved()
    cypress_run('auth-switcher-moved.spec.js')
end
