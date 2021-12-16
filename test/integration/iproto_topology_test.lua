local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local log = require('log')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = require('digest').urandom(6):hex(),

        replicasets = {
            {
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
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                all_rw = true,
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
            }, {
                uuid = helpers.uuid('c'),
                roles = {},
                servers = {
                    {
                        alias = 'expelled',
                        instance_uuid = helpers.uuid('c', 'c', 1),
                        advertise_port = 13309,
                        http_port = 8089
                    }
                }
            }
        }
    })
    g.cluster:start()

    g.cluster:server('expelled'):eval([[
        local last_will_path = ...
        last_will_path = require('fio').pathjoin(last_will_path, 'last_will.txt')
        package.loaded['mymodule-permanent'].stop = function()
            require('cartridge.utils').file_write(last_will_path,

                "In the name of God, amen! I Expelled in perfect health"..
                "and memorie, God be praysed, doe make and ordayne this"..
                "my last will and testament in manner and forme"..
                "followeing, that ys to saye, first, I comend my soule"..
                "into the handes of God my Creator, hoping and"..
                "assuredlie beleeving, through thonelie merites of Jesus"..
                "Christe my Saviour, to be made partaker of lyfe"..
                "everlastinge, and my bodye to the earth whereof yt ys"..
                "made.")

        end
    ]], {g.cluster.datadir})

    g.cluster:server('expelled'):stop()
    g.cluster:server('router'):graphql({
        query = [[
            mutation($uuid: String!) {
                expelServerResponse: cluster{edit_topology(
                    servers: [{
                        uuid: $uuid
                        expelled: true
                    }]
                ) {
                    servers{status}
                }}
            }
        ]],
        variables = {
            uuid = g.cluster:server('expelled').instance_uuid
        }
    })

    g.server = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'spare',
        command = helpers.entrypoint('srv_basic'),
        replicaset_uuid = helpers.uuid('b'),
        instance_uuid = helpers.uuid('b', 'b', 1),
        http_port = 8083,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13303,
        env = {
            TARANTOOL_WEBUI_BLACKLIST = '/cluster/code:/cluster/schema',
        }
    })

    g.server:start()
    t.helpers.retrying({timeout = 5}, function()
        g.server:graphql({query = '{ servers { uri } }'})
        g.cluster.main_server:graphql({
            query = 'mutation($uri: String!) { probe_server(uri:$uri) }',
            variables = {uri = g.server.advertise_uri},
        })
    end)
end

g.before_each(function()
    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.cluster.main_server), {})
    end)
end)

g.after_all = function()
    g.cluster:stop()
    g.server:stop()
    fio.rmtree(g.cluster.datadir)
    fio.rmtree(g.server.workdir)
end


function g.test_cartridge_get_topology_iproto()
    g.cluster:server('router').net_box:eval([[
        require('membership').probe_uri('localhost:13303')
    ]])

    local res = g.cluster:server('router').net_box:eval([[
        return require('cartridge.lua-api.get-topology').get_servers()
    ]])

    local expected = {{
            alias = "router",
            disabled = false,
            labels = {},
            priority = 1,
            status = "healthy",
            replicaset_uuid = "aaaaaaaa-0000-0000-0000-000000000000",
            uri = "localhost:13301",
            uuid = "aaaaaaaa-aaaa-0000-0000-000000000001",
        }, {
            alias = "storage",
            disabled = false,
            labels = {},
            priority = 1,
            replicaset_uuid = "bbbbbbbb-0000-0000-0000-000000000000",
            uri = "localhost:13302",
            uuid = "bbbbbbbb-bbbb-0000-0000-000000000001",
        }, {
            alias = "spare",
            uri = "localhost:13303",
            uuid = "",
        }, {
            alias = "storage-2",
            disabled = false,
            labels = {},
            priority = 2,
            replicaset_uuid = "bbbbbbbb-0000-0000-0000-000000000000",
            uri = "localhost:13304",
            uuid = "bbbbbbbb-bbbb-0000-0000-000000000002",
    }}

    t.assert_equals(#expected, #res)

    table.sort(expected, function(a,b) return a.uri < b.uri end)
    table.sort(res, function(a,b) return a.uri < b.uri end)
    for i, exp_server in ipairs(expected) do
        t.assert_covers(res[i], exp_server)
    end
end
