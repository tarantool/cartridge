local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local cluster

g.before_all = function()
    cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {
            {
                alias = 'router',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router', 'vshard-storage'},
                servers = {
                    {instance_uuid = helpers.uuid('a', 'a', 1)},
                },
            },
        },
        env = {
            TARANTOOL_DISABLE_ERRSTACK = 'true',
        }
    })
    cluster:start()
end

g.after_all = function()
    cluster:stop()
    fio.rmtree(cluster.datadir)
end

function g.test_error_extensions_errstack()
    local request = {
        query = [[mutation($uuids: [String!]) {
            cluster {
                disable_servers(uuids: $uuids) { uuid }
            }
        }]],
        variables = {uuids = {cluster.main_server.instance_uuid}},
        raise = box.NULL,
    }

    t.assert_error_msg_equals(
        'Current instance "localhost:13301" can not be disabled',
        helpers.Server.graphql, cluster.main_server, request
    )

    request.raise = false
    local response = cluster.main_server:graphql(request)
    local extensions = response.errors[1].extensions
    t.assert_str_matches(
        extensions['io.tarantool.errors.stack'],
        '^not available'
    )
    t.assert_equals(
        extensions['io.tarantool.errors.class_name'],
        'Invalid cluster topology config'
    )
end
