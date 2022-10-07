local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_each(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),

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
                }, {
                    alias = 'victim-brother',
                    instance_uuid = helpers.uuid('b', 'b', 2),
                    advertise_port = 13303,
                    http_port = 8083,
                }}
            }
        }
    })
    g.victim = g.cluster:server('victim')

    g.cluster:start()
end)

g.after_each(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_api_disable()
    g.victim:stop()

    g.cluster.main_server:graphql({query = [[
        mutation {
            cluster { disable_servers(uuids: ["bbbbbbbb-bbbb-0000-0000-000000000001"]) { uri } }
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

function g.test_suggestion()
    g.victim:stop()

    local suggestions = helpers.get_suggestions(g.cluster.main_server)
    t.assert_equals(suggestions.disable_servers, {{
        uuid = g.victim.instance_uuid
    }})

    g.cluster.main_server:graphql({query = [[
        mutation {
            cluster { disable_servers(uuids: ["bbbbbbbb-bbbb-0000-0000-000000000001"]) { uuid } }
        }
    ]]})
    local suggestions = helpers.get_suggestions(g.cluster.main_server)
    t.assert_equals(suggestions.disable_servers, box.NULL)
end


function g.test_leaders_order()
    g.cluster.main_server:graphql({query = [[
        mutation {
            cluster { disable_servers(uuids: ["bbbbbbbb-bbbb-0000-0000-000000000001"]) { uuid } }
        }
    ]]})

    t.assert_equals(g.cluster:server('victim-brother'):exec(function()
        local topology = require('cartridge.topology')
        local confapplier = require('cartridge.confapplier')
        local topology_cfg = confapplier.get_readonly('topology')
        return topology.get_leaders_order(topology_cfg, box.info.cluster.uuid, nil, {only_enabled = true})
    end), {helpers.uuid('b', 'b', 2)})

    t.assert_equals(g.cluster:server('victim-brother'):exec(function()
        return box.info.ro
    end), false)
end
