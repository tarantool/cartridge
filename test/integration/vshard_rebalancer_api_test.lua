local fio = require('fio')
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
                alias = 'A',
                roles = {'vshard-router', 'vshard-storage'},
                servers = 2
            },
        },
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
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
    t.assert_items_equals(resp['data']['servers'], {
        {
            uri = 'localhost:13301',
            boxinfo = {
                vshard_storage = {
                    rebalancer_enabled = true
                }
            }
        },
        {
            uri = 'localhost:13302',
            boxinfo = {
                vshard_storage = {
                    rebalancer_enabled = false
                }
            }
        }
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
    t.assert_items_equals(resp['data']['servers'], {
        {
            uri = 'localhost:13301',
            boxinfo = {
                vshard_storage = {
                    rebalancer_enabled = true
                }
            }
        },
        {
            uri = 'localhost:13302',
            boxinfo = {
                vshard_storage = {
                    rebalancer_enabled = false
                }
            }
        }
    })
end

g.after_test('test_rebalancer_server_level', function()
    local server = g.cluster:server('A-1')
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
