local fio = require('fio')
local fun = require('fun')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local function move(srv, uri)
    srv.env['TARANTOOL_ADVERTISE_URI'] = uri
    srv.net_box_uri = uri
end

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {},
            alias = 'A',
            servers = {
                {advertise_port = 13301},
            },
        }, {
            uuid = helpers.uuid('b'),
            roles = {},
            alias = 'B',
            servers = {
                {advertise_port = 13302},
                {advertise_port = 13303},
            },
        }},
        env = {
            TARANTOOL_REPLICATION_CONNECT_QUORUM = 1,
        }
    })

    g.cluster:start()
    g.A1 = g.cluster:server('A-1')
    g.B1 = g.cluster:server('B-1')
    g.B2 = g.cluster:server('B-2')

    g.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{failover_timeout = 0}}
    )

    fun.foreach(function(s) s:stop() end, g.cluster.servers)
    move(g.A1, 'localhost:13311')
    move(g.B1, 'localhost:13312')
    fun.foreach(function(s) s:start() end, g.cluster.servers)

    helpers.retrying({}, function()
        g.cluster.main_server.net_box:eval([[
            local m = require('membership')
            assert(m.get_member('localhost:13301').status == 'dead')
            assert(m.get_member('localhost:13302').status == 'dead')
            assert(m.get_member('localhost:13311').payload.uuid)
            assert(m.get_member('localhost:13312').payload.uuid)
        ]])
    end)
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_issues()
    t.assert_items_include(
        helpers.list_cluster_issues(g.cluster.main_server),
        {{
            level = 'warning',
            topic = 'configuration',
            instance_uuid = g.A1.instance_uuid,
            replicaset_uuid = g.A1.replicaset_uuid,
            message = 'Advertise URI (localhost:13311) differs' ..
                ' from clusterwide config (localhost:13301)',
        }, {
            level = 'warning',
            topic = 'configuration',
            instance_uuid = g.B1.instance_uuid,
            replicaset_uuid = g.B1.replicaset_uuid,
            message = 'Advertise URI (localhost:13312) differs' ..
                ' from clusterwide config (localhost:13302)',
        }}
    )
end

function g.test_topology_query()
    local servers = g.cluster.main_server:graphql({
        query = [[{
            servers {
                uri uuid alias
                boxinfo { general { listen ro } }
            }
        }]]
    }).data.servers

    t.assert_items_include(servers, {{
        uri = 'localhost:13311',
        uuid = g.A1.instance_uuid,
        alias = 'A-1',
        boxinfo = {general = {listen = '13311', ro = false}},
    }, {
        uri = 'localhost:13312',
        uuid = g.B1.instance_uuid,
        alias = 'B-1',
        boxinfo = {general = {listen = '13312', ro = false}},
    }})
end

function g.test_suggestion()
    local suggestions = helpers.get_suggestions(g.cluster.main_server)
    t.assert_items_equals(suggestions.refine_uri, {{
        uuid = g.A1.instance_uuid,
        uri_new = g.A1.net_box_uri,
        uri_old = 'localhost:13301',
    }, {
        uuid = g.B1.instance_uuid,
        uri_new = g.B1.net_box_uri,
        uri_old = 'localhost:13302',
    }})
end

function g.test_2pc()
    local query = [[ mutation($servers: [EditServerInput]) {
      cluster{ edit_topology(servers: $servers){} }
    }]]

    g.cluster.main_server:graphql({
        query = query,
        variables = {servers = {
            {uuid = g.A1.instance_uuid, uri = g.A1.net_box_uri},
        }},
    })

    g.cluster.main_server:graphql({
        query = query,
        variables = {servers = {
            {uuid = g.B1.instance_uuid, uri = g.B1.net_box_uri},
        }},
    })

    t.assert_equals(helpers.get_suggestions(g.A1), {
        refine_uri = box.NULL,
        force_apply = box.NULL,
        disable_servers = box.NULL,
    })
    helpers.retrying({}, function()
        -- Replication takes time to re-establish
        t.assert_equals(helpers.list_cluster_issues(g.A1), {})
    end)

    g.cluster.main_server:graphql({
        query = query,
        variables = {servers = {
            {uuid = g.A1.instance_uuid, uri = 'localhost:13301'},
            {uuid = g.B1.instance_uuid, uri = 'localhost:13302'},
        }},
    })
end

function g.test_failover()
    -- Test for https://github.com/tarantool/cartridge/issues/1029

    local ok, err = g.A1.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{mode = 'eventual'}}
    )
    t.assert_equals({ok, err}, {true, nil})

    local ok, err = g.B1.net_box:call(
        'package.loaded.cartridge.admin_probe_server',
        {g.B2.advertise_uri}
    )
    t.assert_equals({ok, err}, {true, nil})

    local servers = g.cluster.main_server:graphql({
        query = [[{
            servers {
                uuid
                boxinfo { general { listen ro } }
            }
        }]]
    }).data.servers

    t.assert_items_include(servers, {{
        uuid = g.B1.instance_uuid,
        boxinfo = {general = {listen = '13312', ro = true}},
    }, {
        uuid = g.B2.instance_uuid,
        boxinfo = {general = {listen = '13303', ro = false}},
    }})

    local ok, err = g.A1.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{mode = 'disabled'}}
    )
    t.assert_equals({ok, err}, {true, nil})
end
