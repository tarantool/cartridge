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


local function join_servers(server, join_servers)
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
                uuid = helpers.uuid('a'),
                join_servers = join_servers,
            }}
        },
        raise = false,
    })
end

local function update_membership_data(member_uri)
    g.servers[1].net_box:eval([[
        require('membership').probe_uri(...)
    ]], {member_uri})
end

function g.test_proxy_call_on_dead_instance()
    update_membership_data('localhost:13301')

    g.cluster.main_server:stop()

    local function check_error(err)
        t.assert_equals(err.message, 'No available instances to perform proxy call')
        t.assert_covers(err.extensions, {
            ['io.tarantool.errors.class_name'] = 'ProxyCallError',
        })
    end

    local server = g.servers[1]
    local resp = join_servers(server, {
        {uri = 'localhost:13302', uuid = server.uuid}
    })
    check_error(resp.errors[1])

    local resp = server:graphql({
        query = 'mutation { bootstrap_vshard }',
        raise = false
    })
    check_error(resp.errors[1])

    -- Proxy call wasn't performed
    local resp = server:graphql({query = [[{
        servers { uri uuid status }
    }]]})
    t.assert_items_include(resp.data.servers, {
        {status = 'unconfigured', uri = 'localhost:13303', uuid = ''},
        {status = 'unconfigured', uri = 'localhost:13302', uuid = ''}
    })
end

function g.test_proxy_call_ok()
    update_membership_data('localhost:13301')

    local function get_topology_servers(server)
        return server:graphql({query = [[{
            servers {uri uuid}
        }]]}).data.servers
    end

    local server = g.servers[1]

    -- check get_topology proxy works
    local topology_from_bootsrapped = get_topology_servers(g.cluster.main_server)
    local topology_from_unconfigured = get_topology_servers(server)
    t.assert_items_include(topology_from_bootsrapped, {
        {uri = 'localhost:13302', uuid = ''},
        {uri = 'localhost:13301', uuid = g.cluster.main_server.instance_uuid},
        {uri = 'localhost:13303', uuid = ''}
    })
    t.assert_items_include(topology_from_unconfigured, topology_from_bootsrapped)

    -- check bootstrap vshard proxy works
    local resp = server:graphql({query = 'mutation { bootstrap_vshard }'})
    t.assert_equals(resp.data.bootstrap_vshard, true)

    -- bootstrap remotely (edit_topology)
    local resp = join_servers(server, {
        {uri = 'localhost:13302', uuid = g.servers[1].instance_uuid},
        {uri = 'localhost:13303', uuid = g.servers[2].instance_uuid}
    })
    t.assert_items_include(resp.data.cluster.edit_topology.replicasets, {{
        master = {uri = "localhost:13301", uuid = helpers.uuid('a', 'a', 1)},
        uuid = helpers.uuid('a'),
    }})
    t.assert_items_include(resp.data.cluster.edit_topology.servers, {
        {uri = "localhost:13302", uuid = g.servers[1].instance_uuid},
        {uri = "localhost:13303", uuid = g.servers[2].instance_uuid},
    })
end
