local fio = require('fio')
local t = require('luatest')
local g = t.group('roles_test')

local test_helper = require('test.helper')

local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.datadir = fio.tempdir()
    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        use_vshard = false,
        server_command = test_helper.server_command,
        replicasets = {
            {
                alias = 'main',
                uuid = helpers.uuid('a'),
                roles = {'myrole'},
                servers = {
                    {instance_uuid = helpers.uuid('a', 'a', 1)},
                },
            },
        },
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.datadir)
    g.cluster = nil
    g.datadir = nil
end

function g.test_graphql_known_roles()
    local response = g.cluster.main_server:graphql({
        query = [[{
            cluster {
                known_roles { name dependencies }
            }
        }]],
    })

    t.assert_equals(response.data.cluster.known_roles, {
        {name = 'vshard-storage', dependencies = {}},
        {name = 'vshard-router', dependencies = {}},
        {name = 'myrole-dependency', dependencies = {}},
        {name = 'myrole', dependencies = {'myrole-dependency'}},
    })
end

local function get_config_roles()
    return g.cluster.main_server.net_box:eval([[
        local uuid = ...
        local cartridge = require('cartridge')
        local topology = cartridge.config_get_readonly('topology')
        return topology.replicasets[uuid].roles
    ]], {g.cluster.main_server.replicaset_uuid})
end

local function set_config_roles(roles)
    -- disable dependencies and permanent roles
    -- to make sure they are still enabled
    -- so it doesn't affect GraphQL and RPC
    local ok, err = g.cluster.main_server.net_box:eval([[
        local uuid, roles = ...
        local cartridge = require('cartridge')
        local topology = cartridge.config_get_deepcopy('topology')
        topology.replicasets[uuid].roles = roles
        return cartridge.config_patch_clusterwide({topology = topology})
    ]], {g.cluster.main_server.replicaset_uuid, roles})
    t.assert_equals(err, box.NULL)
    t.assert_equals(ok, true)
end

local function get_graphql_roles()
    local response = g.cluster.main_server:graphql({
        query = [[
            query(
                $uuid: String!
            ){
                replicasets(uuid: $uuid) {
                    roles
                }
            }
        ]],
        variables = {
            uuid = g.cluster.main_server.replicaset_uuid,
        }
    })

    return response.data.replicasets[1].roles
end

local function set_graphql_roles(roles)
    local response = g.cluster.main_server:graphql({
        query = [[
            mutation(
                $uuid: String!
                $roles: [String!]!
            ){
                edit_replicaset(
                    uuid: $uuid
                    roles: $roles
                )
            }
        ]],
        variables = {
            uuid = g.cluster.main_server.replicaset_uuid,
            roles = roles,
        }
    })
    t.assert_equals(response.data.edit_replicaset, true)
end

function g.test_rpc()
    set_config_roles({['myrole'] = true})

    local function soundcheck(role_name, fn_name, expected)
        local ret, err = g.cluster.main_server.net_box:eval([[
            local cartridge = require('cartridge')
            return cartridge.rpc_call(...)
        ]], {role_name, fn_name, nil})
        t.assert_equals(err, nil)
        t.assert_equals(ret, expected)
    end

    soundcheck('myrole',            'dog_goes', 'woof')
    soundcheck('myrole-dependency', 'cat_goes', 'meow')
    soundcheck('myrole-permanent',  'cow_goes', 'moo')
    soundcheck('myrole-hidden',     'what_does_the_fox_say',
        g.cluster.main_server.instance_uuid
    )
end

-------------------------------------------------------------------------------
-- Set roles via patch_clusterwide
-- check roles via GraphQL

function g.test_config_enable_none()
    set_config_roles({})
    t.assert_equals(
        get_graphql_roles(),
        {}
    )
end

function g.test_config_enable_myrole()
    set_config_roles({['myrole'] = true})
    t.assert_equals(
        get_graphql_roles(),
        {'myrole-dependency', 'myrole'}
    )
end

function g.test_config_enable_hidden()
    set_config_roles({['myrole-hidden'] = true})
    t.assert_equals(
        get_graphql_roles(),
        {}
    )
end

function g.test_config_enable_permanent()
    set_config_roles({['myrole-permanent'] = true})
    t.assert_equals(
        get_graphql_roles(),
        {}
    )
end

-------------------------------------------------------------------------------
-- Set roles via GraphQL
-- check roles in clusterwide config

function g.test_graphql_enable_none()
    set_config_roles({})
    set_graphql_roles({})
    t.assert_equals(
        get_config_roles(),
        {['myrole-permanent'] = true}
    )
end

function g.test_graphql_enable_myrole()
    set_config_roles({})
    set_graphql_roles({'myrole'})
    t.assert_equals(
        get_config_roles(),
        {
            ['myrole-dependency'] = true,
            ['myrole-permanent'] = true,
            ['myrole-hidden'] = true,
            ['myrole'] = true,
        }
    )
end

function g.test_graphql_enable_hidden()
    set_config_roles({})
    set_graphql_roles({'myrole-hidden'})
    t.assert_equals(
        get_config_roles(),
        {
            ['myrole-permanent'] = true,
            ['myrole-hidden'] = true,
        }
    )
end

function g.test_graphql_enable_permanent()
    set_config_roles({})
    set_graphql_roles({'myrole-permanent'})
    t.assert_equals(
        get_config_roles(),
        {
            ['myrole-permanent'] = true,
        }
    )
end
