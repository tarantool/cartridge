local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_each(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {{
            alias = 'main',
            roles =  {},
            servers = 1,
        }},
    })
    g.cluster:start()

    g.main_server = g.cluster.main_server
    g.unconfigured = helpers.Server:new({
        alias = 'unconfigured',
        workdir = fio.pathjoin(g.cluster.datadir, 'unconfigured'),
        command = helpers.entrypoint('srv_basic'),
        cluster_cookie = g.cluster.cookie,
        http_port = 8082,
        advertise_port = 13302,
        replicaset_uuid = g.cluster.main_server.replicaset_uuid,
    })

    g.unconfigured:start()
    t.helpers.retrying({}, function()
        g.unconfigured:graphql({query = '{ servers {uri} }'})
        local probe = g.unconfigured:call(
            'package.loaded.membership.probe_uri',
            {g.main_server.advertise_uri}
        )
        t.assert_equals(probe, true)
    end)
end)

g.after_each(function()
    g.unconfigured:stop()
    g.cluster:stop()

    fio.rmtree(g.cluster.datadir)
    g.unconfigured = nil
    g.cluster = nil
end)

local function edit_replicasets(server, args)
    return server:graphql({query = [[
        mutation($replicasets: [EditReplicasetInput]) {
            cluster {
                edit_topology(replicasets: $replicasets) {
                    servers {uuid uri}
                }
            }
        }]],
        variables = {replicasets = args},
        raise = false,
    })
end

local function get_topology(server)
    return server:graphql({
        query = '{ servers {uri uuid}}'
    }).data.servers
end

function g.test_alive_destination()
    -- both instances show the same info
    local expected = {
        {uri = 'localhost:13301', uuid = g.main_server.instance_uuid},
        {uri = 'localhost:13302', uuid = ''},
    }
    t.assert_items_equals(get_topology(g.main_server), expected)
    t.assert_items_equals(get_topology(g.unconfigured), expected)

    -- join unconfigured server to the existing cluster
    local join_servers = {{
        uuid = g.unconfigured.instance_uuid,
        uri = g.unconfigured.advertise_uri,
    }}
    t.assert_equals(
        edit_replicasets(g.unconfigured, {{
            uuid = g.unconfigured.replicaset_uuid,
            join_servers = join_servers
        }}),
        {data = {cluster = {edit_topology = {servers = join_servers}}}}
    )

    -- both instances show the same
    t.assert_items_equals(
        get_topology(g.main_server),
        get_topology(g.unconfigured)
    )
end

function g.test_dead_destination()
    g.main_server:call('box.cfg', {{
        listen = box.NULL, -- restrict connections
        replication = box.NULL, -- produce an issue
    }})
    helpers.run_remotely(g.unconfigured, function()
        -- Make sure unconfigured server isn't connected to main.
        local t = require('luatest')
        local pool = require('cartridge.pool')
        pool.connect('localhost:13301', {wait_connected = false}):close()
        local ok, err = pool.connect('localhost:13301')
        t.assert_equals(ok, nil)
        t.assert_covers(err, {
            class_name = 'NetboxConnectError',
            err = '"localhost:13301": Connection refused',
        })

        -- But it's alive in membership and suitable for proxying
        local proxy = require('cartridge.lua-api.proxy')
        t.assert_equals(proxy.can_call(), true)
    end)

    t.assert_items_equals(get_topology(g.main_server), {
        {uri = 'localhost:13301', uuid = g.main_server.instance_uuid},
        {uri = 'localhost:13302', uuid = ''},
    })
    t.assert_items_equals(get_topology(g.unconfigured), {
        {uri = 'localhost:13302', uuid = ''},
    })

    -- Todo check alien issue in scope of
    -- https://github.com/tarantool/cartridge/issues/1301

    t.assert_covers(
        edit_replicasets(g.unconfigured, {{
            uuid = g.unconfigured.replicaset_uuid,
            join_servers = {{
                uuid = g.unconfigured.instance_uuid,
                uri = g.unconfigured.advertise_uri,
            }}
        }}).errors[1],
        {message = '"localhost:13301": Connection refused'}
    )
end

function g.test_issues()
    -- Check that issue are proxied
    g.main_server:eval([[
        local workdir = require('cartridge.confapplier').get_workdir()
        require('fio').mktree(workdir .. '/config.prepare/lock')
    ]])

    local expected_issues = {{
        level = "warning",
        topic = "config_locked",
        instance_uuid = g.main_server.instance_uuid,
        replicaset_uuid = g.main_server.replicaset_uuid,
        message = 'Configuration is prepared and locked' ..
            ' on localhost:13301 (main-1)',
    }}

    t.assert_items_equals(helpers.list_cluster_issues(g.main_server), expected_issues)
    t.assert_items_equals(helpers.list_cluster_issues(g.unconfigured), expected_issues)

    g.main_server:stop()
    t.assert_items_equals(helpers.list_cluster_issues(g.unconfigured), {})
end
