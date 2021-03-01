local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_each(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {
            {
                alias = 'main',
                uuid = helpers.uuid('a'),
                roles =  {'vshard-router', 'vshard-storage'},
                servers = {
                    {instance_uuid = helpers.uuid('a', 'a', 1)},
                },
            }
        },
    })

    g.servers = {}
    for i = 2, 3 do
        local http_port = 8080 + i
        local advertise_port = 13300 + i
        local alias = string.format('srv%d', i - 1)

        g.servers[i - 1] = helpers.Server:new({
            alias = alias,
            command = helpers.entrypoint('srv_basic'),
            workdir = fio.pathjoin(g.cluster.datadir, alias),
            cluster_cookie = g.cluster.cookie,
            http_port = http_port,
            advertise_port = advertise_port,
            instance_uuid = helpers.uuid('a', 'a', i),
        })
    end

    for _, server in pairs(g.servers) do
        server:start()
    end
    g.cluster:start()
end)

g.after_each(function()
    for _, server in pairs(g.servers or {}) do
        server:stop()
    end
    g.cluster:stop()

    fio.rmtree(g.cluster.datadir)
    g.cluster = nil
    g.servers = nil
end)


local function edit_topology(server, rpl_uuid, join_servers)
    return server:graphql({query = [[
        mutation($replicasets: [EditReplicasetInput]) {
            cluster {
                edit_topology(replicasets: $replicasets) {
                    servers {uuid uri}
                    replicasets {uuid master { uuid uri }}
                }
            }
        }]],
        variables = {
            replicasets = {{
                uuid = rpl_uuid,
                join_servers = join_servers,
            }}
        },
        raise = false,
    })
end

local function get_topology(server)
    return server:graphql({
        query = '{ servers {uri uuid}}'
    }).data.servers
end

function g.test_dead_destination()
    local server = g.servers[1]

    g.cluster.main_server:stop()
    server.net_box:call(
        'package.loaded.membership.probe_uri',
        {g.cluster.main_server.advertise_uri}
    )

    local resp = get_topology(server)
    t.assert_items_include(resp, {
        {uri = 'localhost:13303', uuid = ''},
        {uri = 'localhost:13302', uuid = ''}
    })

    local rpl_uuid = helpers.uuid('b')
    local resp = edit_topology(server, rpl_uuid,
        {{uri = 'localhost:13302', uuid = server.instance_uuid}}
    ).data.cluster.edit_topology

    t.assert_equals(resp.replicasets, {{
        master = {uri = "localhost:13302", uuid = server.instance_uuid},
        uuid = rpl_uuid,
    }})
    t.assert_equals(resp.servers, {
        {uri = "localhost:13302", uuid = server.instance_uuid}
    })
end

function g.test_alive_destination()
    local server = g.servers[1]
    server.net_box:call(
        'package.loaded.membership.probe_uri',
        {g.cluster.main_server.advertise_uri}
    )

    -- check get_topology proxy works
    local topology_from_bootsrapped = get_topology(g.cluster.main_server)
    local topology_from_unconfigured = get_topology(server)
    t.assert_items_include(topology_from_bootsrapped, {
        {uri = 'localhost:13302', uuid = ''},
        {uri = 'localhost:13301', uuid = g.cluster.main_server.instance_uuid},
        {uri = 'localhost:13303', uuid = ''}
    })
    t.assert_items_include(topology_from_unconfigured, topology_from_bootsrapped)

    -- bootstrap remotely
    local join_servers = {
        {uri = 'localhost:13302', uuid = g.servers[1].instance_uuid},
        {uri = 'localhost:13303', uuid = g.servers[2].instance_uuid}
    }

    local resp = edit_topology(
        server, helpers.uuid('a'), join_servers
    ).data.cluster.edit_topology

    t.assert_equals(resp.replicasets, {{
        master = {uri = "localhost:13301", uuid = helpers.uuid('a', 'a', 1)},
        uuid = helpers.uuid('a'),
    }})
    t.assert_items_include(resp.servers, join_servers)
end
