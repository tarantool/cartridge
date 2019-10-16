local fio = require('fio')
local t = require('luatest')
local g = t.group('cypress_basic')

local srv_helpers = require('test.cypress.srv')

g.setup = function()
    g.shut_down_func = srv_helpers.basic_cluster()
end

g.teardown = function()
    g.shut_down_func()
end

function g.test_cypress_run()
    local code = os.execute("cd webui && npx cypress run --spec cypress/integration/probe-server.spec.js")
    t.assert_equals(code, 0)
end
