local fio = require('fio')
local t = require('luatest')
local g = t.group('cypress_bootstrap')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

local servers = {}
local tempdir = fio.tempdir()

g.before_all = function()
    local function add_server(i)
        local http_port = 8080 + i
        local advertise_port = 13310 + i
        local alias = 'server' .. tostring(i)

        servers[i] = helpers.Server:new({
            alias = alias,
            command = test_helper.server_command,
            workdir = fio.pathjoin(tempdir, alias),
            cluster_cookie = 'test-cluster-cookie',
            http_port = http_port,
            advertise_port = advertise_port,
            instance_uuid = helpers.uuid('a', 'a', i),
            replicaset_uuid = helpers.uuid('a'),
        })
    end

    add_server(1)
    add_server(2)
    add_server(3)
    add_server(4)
    add_server(5)

    for _, server in pairs(servers) do
        server:start()
    end
end

g.after_all = function()
    for _, server in pairs(servers) do
        server:stop()
    end

    fio.rmtree(tempdir)
    tempdir = nil
end

function g.test_bootstrap()
    local code = os.execute(
        "cd webui && npx cypress run --spec" ..
        ' cypress/integration/create-replicasets-and-botstrap.spec.js'..
        ',cypress/integration/code-page-files.spec.js'
    )
    t.assert_equals(code, 0)
end
