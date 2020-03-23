local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local utils = require('cartridge.utils')
local yaml = require('yaml')
local log = require('log')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {
            {
                alias = 'master',
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {{
                    http_port = 8081,
                    advertise_port = 13301,
                    instance_uuid = helpers.uuid('a', 'a', 1)
                }},
            }
        },
    })

    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_api()
    local res = g.cluster.main_server:graphql({query = [[{
            cluster {
                known_roles { name dependencies }
            }
        }]]
    })

    t.assert_equals(res['data']['cluster']['known_roles'], {
        {['name'] = 'failover-coordinator', ['dependencies'] = {}},
        {['name'] = 'vshard-storage', ['dependencies'] = {}},
        {['name'] = 'vshard-router', ['dependencies'] = {}},
        {['name'] = 'myrole-dependency', ['dependencies'] = {}},
        {['name'] = 'myrole', ['dependencies'] = {'myrole-dependency'}}
    })
end

function g.test_myrole()
    g.cluster.main_server:graphql({query = [[
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-0000-0000-000000000000"
                roles: ["myrole"]
            )
        }]]
    })

    g.cluster.main_server.net_box:eval([[
        local service_registry = require('cartridge.service-registry')
        assert(service_registry.get('myrole') ~= nil)
    ]])

    g.cluster.main_server.net_box:eval([[
        assert(package.loaded['mymodule'].get_state() == 'initialized')
    ]])

    local res = g.cluster.main_server:graphql({query = [[{
        replicasets(uuid: "aaaaaaaa-0000-0000-0000-000000000000") {
            roles
        }}]]
    })

    t.assert_equals(
        res['data']['replicasets'][1]['roles'],
        {'myrole-dependency', 'myrole'}
    )

    g.cluster.main_server:graphql({query = [[
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-0000-0000-000000000000"
                roles: []
            )
        }]]
    })

    g.cluster.main_server.net_box:eval([[
        local service_registry = require('cartridge.service-registry')
        assert(service_registry.get('myrole') == nil)
    ]])

    g.cluster.main_server.net_box:eval([[
        assert(package.loaded['mymodule'].get_state() == 'stopped')
    ]])
end

function g.test_dependencies()
    g.cluster.main_server:graphql({query = [[
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-0000-0000-000000000000"
                roles: ["myrole"]
            )
        }]]
    })

    g.cluster.main_server.net_box:eval([[
        local service_registry = require('cartridge.service-registry')
        assert(service_registry.get('myrole-dependency') ~= nil)
    ]])
end



function g.test_rename()
    -- The test simulates a situation when the role is renamed in code,
    -- and the server is launced with old name in config.

    g.cluster.main_server:graphql({query = [[
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-0000-0000-000000000000"
                roles: ["myrole"]
            )
        }
    ]]})

    g.cluster:stop()

    local topology_cfg_path = fio.pathjoin(
        g.cluster.main_server.workdir, 'config/topology.yml'
    )
    local data = utils.file_read(topology_cfg_path)
    local topology_cfg = yaml.decode(data)
    local replicasets = topology_cfg['replicasets']
    local replicaset = replicasets[helpers.uuid('a')]
    replicaset['roles'] = {['myrole-oldname'] = true}
    local data = yaml.encode(topology_cfg)
    utils.file_write(topology_cfg_path, data)
    log.info('Config hacked: ' .. topology_cfg_path)

    g.cluster:start()

    -- Presence of old role in config doesn't affect mutations
    g.cluster.main_server:graphql({query = [[
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-0000-0000-000000000000"
                roles: ["myrole", "myrole-oldname"]
            )
        }
    ]]})

    -- Old name isn't displayed it webui
    local res =  g.cluster.main_server:graphql({query = [[
        {
            replicasets(uuid: "aaaaaaaa-0000-0000-0000-000000000000") {
                roles
            }
        }
    ]]})
    t.assert_equals(res['data']['replicasets'][1]['roles'], {'myrole-dependency', 'myrole'})

    -- Role with old name can be disabled
    g.cluster.main_server:graphql({query = [[
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-0000-0000-000000000000"
                roles: []
            )
        }
    ]]})

    -- old role name can not be enabled back
    local invalid_old_role_enabled = function()
        g.cluster.main_server:graphql({query = [[
            mutation {
                edit_replicaset(
                    uuid: "aaaaaaaa-0000-0000-0000-000000000000"
                    roles: ["myrole-oldname"]
                )
            }
        ]]})
    end
    t.assert_error_msg_contains(
        'replicasets[aaaaaaaa-0000-0000-0000-000000000000] can not enable unknown role "myrole-oldname"',
        invalid_old_role_enabled
    )
end
