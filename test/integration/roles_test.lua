local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {
                    {instance_uuid = helpers.uuid('a', 1), alias = 'master'},
                },
            },
        },
    })
    g.cluster:start()
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

g.test_get_enabled_roles_without_args = function()
    local roles_list = g.cluster.main_server.net_box:eval([[
        local roles = require('cartridge.roles')
        return roles.get_enabled_roles()
    ]])

    t.assert_equals(roles_list, {
        ['ddl-manager'] = true,
        ['myrole-permanent'] = true
    })
end

g.test_get_enabled_roles_with_dependencies = function()
    local roles_list = g.cluster.main_server.net_box:eval([[
        local roles = require('cartridge.roles')
        return roles.get_enabled_roles({'myrole'})
    ]])

    t.assert_equals(roles_list, {
        ['ddl-manager'] = true,
        ['myrole-permanent'] = true,
        ['myrole'] = true,
        ['myrole-hidden'] = true,
        ['myrole-dependency'] = true,
    })

    roles_list = g.cluster.main_server.net_box:eval([[
        local roles = require('cartridge.roles')
        return roles.get_enabled_roles({myrole = true})
    ]])

    t.assert_equals(roles_list, {
        ['ddl-manager'] = true,
        ['myrole-permanent'] = true,
        ['myrole'] = true,
        ['myrole-hidden'] = true,
        ['myrole-dependency'] = true,
    })
end
