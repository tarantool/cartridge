local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_vshardless'),
        cookie = helpers.random_cookie(),
        use_vshard = false,
        replicasets = {{
            alias = 'main',
            roles = {},
            servers = 1,
        }},
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_edit_replicaset()
    local replica_uuid = g.cluster.replicasets[1].uuid

    local edit_replicaset = function(roles)
        g.cluster.main_server:graphql({
            query = [[
                mutation(
                    $uuid: String!
                    $roles: [String!]!
                ) {
                    edit_replicaset(
                        uuid: $uuid
                        roles: $roles
                    )
                }
            ]],
            variables = {
                uuid = replica_uuid, roles = roles
            }
        })
    end

    t.assert_error_msg_contains(
        string.format(
            'replicasets[%s] can not enable unknown role "vshard-router"',
            replica_uuid
        ), edit_replicaset, {'vshard-router'}
    )

    t.assert_error_msg_contains(
        string.format(
            'replicasets[%s] can not enable unknown role "vshard-storage"',
            replica_uuid
        ), edit_replicaset, {'vshard-storage'}
    )
end

function g.test_package_loaded()
    g.cluster.main_server:eval([[
        assert( package.loaded['cartridge.roles.vshard-router'] == nil )
        assert( package.loaded['cartridge.roles.vshard-storage'] == nil )
    ]])
end

function g.test_config()
    local server_conn = g.cluster.main_server.net_box
    local resp = server_conn:eval([[
        local cartridge = require('cartridge')
        return cartridge.config_get_readonly('vshard_groups')
    ]])

    t.assert_equals(resp, {})

    local resp = server_conn:eval([[
        local cartridge = require('cartridge')
        return cartridge.config_get_readonly('vshard_groups')
    ]])
    t.assert_equals(resp, {})
end

function g.test_api()
    local resp = g.cluster.main_server:graphql({
        query = [[{
            cluster {
                can_bootstrap_vshard
                vshard_bucket_count
                vshard_known_groups
                vshard_groups {
                    name
                    bucket_count
                    bootstrapped
                }
            }
            servers {
                uuid
                boxinfo {
                    general {instance_uuid}
                    vshard_router { buckets_unreachable }
                    vshard_storage { buckets_total }
                }
            }
        }]]
    })

    t.assert_equals(resp['data']['cluster'], {
        can_bootstrap_vshard = false,
        vshard_bucket_count = 0,
        vshard_known_groups = {},
        vshard_groups = {},
    })
    t.assert_equals(resp['data']['servers'], {{
        uuid = g.cluster.main_server.instance_uuid,
        boxinfo = {
            general = {instance_uuid = g.cluster.main_server.instance_uuid},
            vshard_router = box.NULL,
            vshard_storage = box.NULL,
        }
    }})

    local _, err = g.cluster.main_server:call(
        'package.loaded.cartridge.admin_bootstrap_vshard'
    )

    t.assert_covers(err, {
        class_name = 'RemoteCallError',
        err = 'No remotes with role "vshard-router" available',
    })
end
