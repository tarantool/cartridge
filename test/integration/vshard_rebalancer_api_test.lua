local fio = require('fio')
local fun = require('fun')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        use_vshard = true,
        replicasets = {
            {
                alias = 'router',
                roles = {'vshard-router'},
                servers = 1,
            },
            {
                alias = 'A',
                roles = {'vshard-storage'},
                servers = 2,
            },
            {
                alias = 'B',
                roles = {'vshard-storage'},
                servers = 2,
            },
        },
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function rebalancer_enabled(g)
    local resp = g.cluster.main_server:graphql({
        query = [[{
            servers {
                uri
                boxinfo {
                    vshard_storage {
                        rebalancer_enabled
                    }
                }
            }
        }
    ]]})

    table.sort(resp['data']['servers'], function(a, b) return a.uri < b.uri end)
    return fun.iter(resp['data']['servers']):filter(function(v)
        return v.boxinfo.vshard_storage ~= nil
    end):reduce(function(acc, v)
        acc[v.uri] = v.boxinfo.vshard_storage.rebalancer_enabled
        return acc
    end, {})
end

g.test_rebalancer_replicaset_level = function()
    local server = g.cluster:server('A-1')

    g.cluster.main_server:graphql({
        query = [[
            mutation($replicasets: [EditReplicasetInput]) {
                cluster {
                    edit_topology(replicasets: $replicasets) {
                        replicasets {
                            uuid
                        }
                    }
                }
            }
        ]],
        variables = {
            replicasets = {{
                uuid = server.replicaset_uuid,
                rebalancer = true,
            }}
        }
    })

    t.assert_equals(rebalancer_enabled(g), {
        -- uri, rebalancer_enabled
        ['localhost:13302'] = true,
        ['localhost:13303'] = false,
        ['localhost:13304'] = false,
        ['localhost:13305'] = false,
    })
end

g.after_test('test_rebalancer_replicaset_level', function()
    local server = g.cluster:server('A-1')
    local resp = g.cluster.main_server:graphql({
        query = [[
            mutation($replicasets: [EditReplicasetInput]) {
                cluster {
                    edit_topology(replicasets: $replicasets) {
                        replicasets {
                            uuid
                            rebalancer
                        }
                    }
                }
            }
        ]],
        variables = {
            replicasets = {{
                uuid = server.replicaset_uuid,
                rebalancer = box.NULL,
            }}
        }
    })
    t.assert_equals(resp['data']['cluster']['edit_topology']['replicasets'], {
        {
            uuid = server.replicaset_uuid,
            rebalancer = box.NULL,
        }
    })
end)

g.test_rebalancer_server_level = function()
    local server = g.cluster:server('A-2')
    g.cluster.main_server:graphql({query = [[
        mutation($servers: [EditServerInput]) {
            cluster {
                edit_topology(servers: $servers){
                    servers {uuid}
                }
            }
        }
    ]], variables = {
        servers = {
            {uuid = server.instance_uuid, rebalancer = true},
        }
    }})

    t.assert_equals(rebalancer_enabled(g), {
        -- uri, rebalancer_enabled
        ['localhost:13302'] = false,
        ['localhost:13303'] = true,
        ['localhost:13304'] = false,
        ['localhost:13305'] = false,
    })
end

g.after_test('test_rebalancer_server_level', function()
    local server = g.cluster:server('A-2')
    local resp = g.cluster.main_server:graphql({query = [[
        mutation($servers: [EditServerInput]) {
            cluster {
                edit_topology(servers: $servers){
                    servers {
                        uuid
                        rebalancer
                    }
                }
            }
        }
    ]], variables = {
        servers = {
            {uuid = server.instance_uuid, rebalancer = box.NULL},
        }
    }})
    t.assert_equals(resp['data']['cluster']['edit_topology']['servers'], {
        {
            uuid = server.instance_uuid,
            rebalancer = box.NULL,
        }
    })
end)

local test_cases = {
    same_replicaset = {'A-1', 'A-2'},
    different_replicasets = {'A-1', 'B-1'},
}

for test_name, test_data in pairs(test_cases) do
    g['test_rebalancer_multiple_servers_error_' .. test_name] = function()
        local server1 = g.cluster:server(test_data[1])
        local server2 = g.cluster:server(test_data[2])
        local resp = g.cluster.main_server:graphql({query = [[
                mutation($servers: [EditServerInput]) {
                    cluster {
                        edit_topology(servers: $servers){
                            servers {
                                uuid
                                rebalancer
                            }
                        }
                    }
                }
            ]], variables = {
                servers = {
                    {uuid = server1.instance_uuid, rebalancer = true},
                    {uuid = server2.instance_uuid, rebalancer = true},
                }
            },
            raise = false,
        })
        t.assert_equals(resp.errors[1].message, 'Several rebalancer flags found in config')
    end
end

g.test_rebalancer_multiple_replicasets_error = function()
    local server1 = g.cluster:server('A-1')
    local server2 = g.cluster:server('B-1')
    local resp = g.cluster.main_server:graphql({
        query = [[
            mutation($replicasets: [EditReplicasetInput]) {
                cluster {
                    edit_topology(replicasets: $replicasets) {
                        replicasets {
                            uuid
                        }
                    }
                }
            }
        ]],
        variables = {
            replicasets = {{
                uuid = server1.replicaset_uuid,
                rebalancer = true,
            }, {
                uuid = server2.replicaset_uuid,
                rebalancer = true,
            }},
        },
        raise = false,
    })
    t.assert_equals(resp.errors[1].message, 'Several rebalancer flags found in config')
end

g.test_rebalancer_multiple_replicasets_and_server_error = function()
    local server1 = g.cluster:server('A-1')
    local res = g.cluster.main_server:graphql({
        query = [[
            mutation($replicasets: [EditReplicasetInput], $servers: [EditServerInput]) {
                cluster {
                    edit_topology(replicasets: $replicasets, servers: $servers) {
                        replicasets {
                            uuid
                        }
                    }
                }
            }
        ]],
        variables = {
            replicasets = {{
                uuid = server1.replicaset_uuid,
                rebalancer = true,
            }},
            servers = {
                {uuid = server1.instance_uuid, rebalancer = true},
            }
        },
        raise = false,
    })
    t.assert_equals(res.errors[1].message, 'Several rebalancer flags found in config')
end
