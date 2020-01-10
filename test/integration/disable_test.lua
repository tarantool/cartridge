local fio = require('fio')
local t = require('luatest')
local g = t.group()

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        cookie = 'test-cluster-cookie',

        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = {{
                    alias = 'survivor',
                    instance_uuid = helpers.uuid('a', 'a', 1),
                    advertise_port = 13301,
                    http_port = 8081,
                }}
            }, {
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                servers = {{
                    alias = 'victim',
                    instance_uuid = helpers.uuid('b', 'b', 1),
                    advertise_port = 13302,
                    http_port = 8082,
                }}
            }
        }
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function wish_state(srv, desired_state)
    g.cluster:retrying({}, function()
        srv.net_box:eval([[
            local confapplier = require('cartridge.confapplier')
            local desired_state = ...
            local state = confapplier.wish_state(desired_state)
            assert(
                state == desired_state,
                string.format('Inappropriate state %q ~= desired %q',
                state, desired_state)
            )
        ]], {desired_state})
    end)
end

function g.test_disable_alive()
    g.cluster.main_server:graphql({query = [[
        mutation {
            cluster { disable_servers(uuids: ["bbbbbbbb-bbbb-0000-0000-000000000001"]) }
        }
    ]]})

    wish_state(g.cluster:server('victim'), 'Disabled')
end

function g.test_api_disable()
    g.cluster:server('victim'):stop()

    g.cluster.main_server:graphql({query = [[
        mutation {
            cluster { disable_servers(uuids: ["bbbbbbbb-bbbb-0000-0000-000000000001"]) }
        }
    ]]})

    local res = g.cluster.main_server:graphql({query = [[
        {
            servers(uuid: "bbbbbbbb-bbbb-0000-0000-000000000001") {
                disabled
            }
        }
    ]]})

    local servers = res.data.servers
    t.assert_equals(#servers, 1)
    t.assert_equals(servers[1], {disabled = true})
end
