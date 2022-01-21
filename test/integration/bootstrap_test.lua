local fio = require('fio')
local log = require('log')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.after_each(function()
    if g.cluster then
        g.cluster:stop()
        g.cluster = nil
    end

    if g.server then
        g.server:stop()
        g.server = nil
    end

    if g.tempdir then
        fio.rmtree(g.tempdir)
        g.tempdir = nil
    end
end)

function g.test_cookie_change()
    g.tempdir = fio.tempdir()
    g.cluster = helpers.Cluster:new({
        datadir = g.tempdir,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'myrole'},
                servers = {
                    {
                        alias = 'master',
                        instance_uuid = helpers.uuid('a', 'a', 1)
                    }, {
                        alias = 'replica',
                        instance_uuid = helpers.uuid('a', 'a', 2)
                    }
                },
            },
        },
    })

    g.cluster:start()

    local master = g.cluster:server('master')
    local replica = g.cluster:server('replica')

    g.cluster:stop()
    log.warn('Cluster stopped')

    local cc = 'new-cluster-cookie'
    for _, srv in pairs(g.cluster.servers) do
        srv.cluster_cookie = cc
        srv.env.TARANTOOL_CLUSTER_COOKIE = cc
        srv.net_box_credentials.password = cc
    end
    log.warn('Cluster cookie changed')


    master:start()
    replica:start()
    g.cluster:retrying({}, function()
        master:connect_net_box()
        replica:connect_net_box()
    end)
    log.warn('Cluster restarted')

    local cookie = master:eval([[
        local cluster_cookie = require('cartridge.cluster-cookie')
        return cluster_cookie.cookie()
    ]])

    t.assert_equals(cookie, 'new-cluster-cookie')
    g.cluster:wait_until_healthy()

    local resp = g.cluster.main_server:graphql({
        query = [[{
            servers {
                uuid
                boxinfo {
                    general { instance_uuid }
                }
            }
        }]]
    })

    t.assert_equals(resp.data.servers, {{
        boxinfo={general={instance_uuid=master.instance_uuid}},
        uuid=master.instance_uuid
    }, {
        boxinfo={general={instance_uuid=replica.instance_uuid}},
        uuid=replica.instance_uuid
    }})

end

function g.test_workdir_collision()
    -- We create a single-instance cluster
    -- and another instance in the same workdir
    -- Test checks that attempt to join it doesn't break anything

    g.tempdir = fio.tempdir()
    g.cluster = helpers.Cluster:new({
        datadir = g.tempdir,
        server_command = helpers.entrypoint('srv_basic'),
        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {'myrole'},
            servers = {{
                alias = 'master',
                instance_uuid = helpers.uuid('a', 'a', 1),
                workdir = g.tempdir,
                http_port = 8081,
                advertise_port = 13301,
            }},
        }},
    })
    g.server = helpers.Server:new({
        alias = 'invader',
        workdir = g.tempdir,
        command = helpers.entrypoint('srv_basic'),
        cluster_cookie = g.cluster.cookie,
        http_port = 8082,
        advertise_port = 13302,
        instance_uuid = helpers.uuid('b', 'b', 1),
        replicaset_uuid = helpers.uuid('b'),
    })

    g.server:start()
    g.cluster:start()

    t.assert_error_msg_contains(
        'Two-phase commit is locked',
        helpers.Cluster.join_server, g.cluster, g.server
    )
    g.cluster:wait_until_healthy()
end
