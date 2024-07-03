local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {{
            alias = 'router',
            roles = {'vshard-router'},
            servers = 1,
        }, {
            alias = 'A',
            roles = {'vshard-storage'},
            servers = 2,
        }, {
            alias = 'B',
            roles = {'vshard-storage'},
            servers = 1,
        }},
        env = {
            TARANTOOL_ADD_VSHARD_ROUTER_ALERTS_TO_ISSUES = 'true',
        },
    })
    g.cluster:start()

    g.to_be_expelled = g.cluster:server('B-1')
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_expel()
    g.cluster:wait_until_healthy()

    g.to_be_expelled:stop()

    g.cluster.main_server:exec(function(uuid)
        package.loaded.cartridge.admin_disable_servers({uuid})
    end, {g.to_be_expelled.instance_uuid})

    g.cluster.main_server:setup_replicaset({
        weight = 0,
        uuid = g.to_be_expelled.replicaset_uuid,
    })

    t.helpers.retrying({}, function()
        t.assert_equals(
            helpers.list_cluster_issues(g.cluster.main_server),
            {{
                level = "warning",
                topic = "vshard",
                message = "1500 buckets are not discovered",
                instance_uuid = g.cluster.main_server.instance_uuid,
                replicaset_uuid = g.cluster.main_server.replicaset_uuid,
            }}
        )
    end)

    local _, err = g.cluster.main_server:call('package.loaded.cartridge.admin_edit_topology',
        {{servers = {{uuid = g.to_be_expelled.instance_uuid, expelled = true}}}})

    t.assert_str_contains(
        err.err,
        'Please make sure that all buckets are safe before making any changes'
    )

    -- return g.to_be_expelled back to proceed the expel
    g.to_be_expelled:start()

    g.cluster:wait_until_healthy()

    -- enable server before expelling
    g.cluster.main_server:exec(function(uuid)
        package.loaded.cartridge.admin_enable_servers({uuid})
    end, {g.to_be_expelled.instance_uuid})

    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.cluster.main_server), {})
    end)

    t.helpers.retrying({timeout = 10}, function()
        local count = g.to_be_expelled:exec(function()
            return _G.vshard.storage.buckets_count()
        end)
        t.assert_equals(count, 0)
    end)

    -- expel it again
    local _, err = g.cluster.main_server:call('package.loaded.cartridge.admin_edit_topology',
        {{servers = {{uuid = g.to_be_expelled.instance_uuid, expelled = true}}}})

    t.assert_not(err)
end
