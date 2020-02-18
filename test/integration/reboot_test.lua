local fio = require('fio')
local log = require('log')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local utils = require('cartridge.utils')

g.setup = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {
                    {
                        alias = 'master',
                        instance_uuid = helpers.uuid('a', 'a', 1),
                        advertise_port = 13301,
                    }
                },
            },
        },
    })
    g.cluster:start()
end

g.teardown = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_oldstyle_config()
    g.cluster:stop()

    fio.rmtree(
        fio.pathjoin(g.cluster.main_server.workdir, 'config')
    )

    utils.file_write(
        fio.pathjoin(g.cluster.main_server.workdir, 'config.yml'),
        [[
        auth:
            enabled: false
            cookie_max_age: 2592000
            cookie_renew_age: 86400
        topology:
            replicasets:
                aaaaaaaa-0000-0000-0000-000000000000:
                    weight: 1
                    master:
                        - aaaaaaaa-aaaa-0000-0000-000000000001
                    alias: unnamed
                    roles:
                        myrole: true
                        vshard-router: true
                        vshard-storage: true
                    vshard_group: default
            servers:
                aaaaaaaa-aaaa-0000-0000-000000000001:
                    replicaset_uuid: aaaaaaaa-0000-0000-0000-000000000000
                    uri: localhost:13301
            failover: false
        vshard:
            bootstrapped: false
            bucket_count: 3000
        ]]
    )
    g.cluster:start()


    g.cluster.main_server.net_box:eval([[
        local vshard = require('vshard')
        local cartridge = require('cartridge')
        local router_role = assert(cartridge.service_get('vshard-router'))

        assert(router_role.get() == vshard.router.static, "Default router is initialized")
    ]])
end

function g.test_absent_config()
    g.cluster:stop()
    log.warn('Cluster stopped')

    fio.rmtree(
        fio.pathjoin(g.cluster.main_server.workdir, 'config')
    )
    log.warn('Config removed')

    local srv = g.cluster.main_server
    srv:start()

    local expected_err =
        "Snapshot was found in " .. g.cluster.main_server.workdir ..
        ", but config.yml wasn't. Where did it go?"

    g.cluster:retrying({}, function()
        srv:connect_net_box()
        local state, err = srv.net_box:eval([[
            local confapplier = require('cartridge.confapplier')
            return confapplier.get_state()
        ]])

        t.assert_equals(state, 'InitError')
        t.assert_equals(err.class_name, 'InitError')
        t.assert_equals(err.err,
            "Snapshot was found in " .. g.cluster.main_server.workdir ..
            ", but config.yml wasn't. Where did it go?"
        )
    end)

    local resp = srv:graphql({
        query = [[{ cluster{ self { state error uuid } } }]]
    })
    t.assert_equals(resp.data.cluster.self, {
        error = expected_err,
        state = 'InitError',
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

function g.test_absent_snapshot()
    g.cluster:stop()
    log.warn('Cluster stopped')

    local workdir = g.cluster.main_server.workdir
    for _, f in pairs(fio.glob(fio.pathjoin(workdir, '*.snap'))) do
        fio.unlink(f)
    end
    log.warn('Snapshots removed')

    g.cluster.main_server:start()
    g.cluster:retrying({}, function()
        g.cluster.main_server:connect_net_box()
    end)
    g.cluster:wait_until_healthy()

    local state, err = g.cluster.main_server.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        return confapplier.get_state()
    ]])

    t.assert_equals(state, 'RolesConfigured')
    t.assert_equals(err, box.NULL)
end


function g.test_invalid_config()
    g.cluster:stop()
    log.warn('Cluster stopped')

    utils.file_write(
        fio.pathjoin(g.cluster.main_server.workdir, 'config/topology.yml'),
        [[
            replicasets: {}
            servers: {}
        ]]
    )

    log.warn('Config spoiled')

    g.cluster.main_server:start()
    g.cluster:retrying({}, function()
        -- wait when BootstrappingBox finishes
        local srv = g.cluster.main_server
        t.assert_equals(
            srv:graphql({query = [[{cluster{self{uuid}}}]]}).data.cluster,
            {self = {uuid = srv.instance_uuid}}
        )
        srv:connect_net_box()
    end)

    local state, err = g.cluster.main_server.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        return confapplier.get_state()
    ]])

    t.assert_equals(state, 'BootError')

    t.assert_equals(err.class_name, 'BootError')
    t.assert_equals(err.err,
        "Server " .. g.cluster.main_server.instance_uuid ..
        " not in clusterwide config, no idea what to do now"
    )
end
