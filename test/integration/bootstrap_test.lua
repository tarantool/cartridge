local fio = require('fio')
local log = require('log')
local errno = require('errno')
local t = require('luatest')
local g = t.group('bootstrap')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.teardown = function()
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
end

function g.test_cookie_change()
    g.tempdir = fio.tempdir()
    g.cluster = helpers.Cluster:new({
        datadir = g.tempdir,
        server_command = test_helper.server_command,
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

    local cookie = master.net_box:eval([[
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
    -- Test checks that attempt to join it boesn't break anything

    g.tempdir = fio.tempdir()
    g.cluster = helpers.Cluster:new({
        datadir = g.tempdir,
        server_command = test_helper.server_command,
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
        command = test_helper.server_command,
        cluster_cookie = g.cluster.cookie,
        http_port = 8082,
        advertise_port = 13302,
        instance_uuid = helpers.uuid('b', 'b', 1),
        replicaset_uuid = helpers.uuid('b'),
    })

    g.server:start()
    g.cluster:start()

    t.assert_error_msg_contains(
        g.tempdir .. '/config.prepare: ',
        helpers.Cluster.join_server, g.cluster, g.server
    )
    g.cluster:wait_until_healthy()
end

function g.test_boot_error()
    g.tempdir = fio.tempdir()
    g.cluster = helpers.Cluster:new({
        datadir = g.tempdir,
        server_command = test_helper.server_command,
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'myrole'},
                servers = {
                    {
                        workdir = g.tempdir,
                        alias = 'master',
                        instance_uuid = helpers.uuid('a', 'a', 1),
                        advertise_port = 13301,
                        env = {TARANTOOL_MEMTX_MEMORY = '1'},
                    }
                },
            },
        },
    })
    pcall(helpers.Cluster.start, g.cluster)

    local srv = g.cluster.main_server
    t.assert_equals(srv.net_box:ping(), false)
    t.assert_equals(srv.net_box.state, 'error')
    if srv.net_box.error ~= 'Peer closed' then
        t.assert_equals(srv.net_box.error, errno.strerror(errno.ECONNRESET))
    end

    srv.env['TARANTOOL_MEMTX_MEMORY'] = nil
    srv.net_box = nil
    srv:start()
    g.cluster:retrying({}, function() srv:connect_net_box() end)

    local state, err = srv.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        return confapplier.get_state()
    ]])

    t.assert_equals(state, 'BootError')

    local expected_err =
        "Snapshot not found in " .. srv.workdir ..
        ", can't recover. Did previous bootstrap attempt fail?"
    t.assert_equals(err.class_name, 'BootError')
    t.assert_equals(err.err, expected_err)

    local resp = g.cluster.main_server:graphql({
        query = [[{ cluster{ self { state error uuid } } }]]
    })
    t.assert_equals(resp.data.cluster.self, {
        error = expected_err,
        state = 'BootError',
        uuid = box.NULL,
    })
    t.assert_error_msg_equals(
        expected_err,
        helpers.Server.graphql, g.cluster.main_server, ({
            query = [[{ servers {} }]]
        })
    )
    t.assert_error_msg_equals(
        expected_err,
        helpers.Server.graphql, g.cluster.main_server, ({
            query = [[{ replicasets {} }]]
        })
    )
end
