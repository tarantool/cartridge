local fio = require('fio')
local t = require('luatest')
local g = t.group('compatibility')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')
local utils = require('cartridge.utils')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
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

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_oldstyle_config()
    g.cluster:stop()

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

    -- master:stop()
    -- master:start()

    -- t.helpers.retrying({timeout = 5}, function()
    --     master:graphql({query = '{}'})
    -- end)
end
