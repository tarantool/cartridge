local fio = require('fio')
local t = require('luatest')
local g = t.group()

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

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
                        http_port = 8081,
                        advertise_port = 13301,
                        labels = {{name = "dc", value = "msk"}}
                    }, {
                        alias = 'slave',
                        instance_uuid = helpers.uuid('a', 'a', 2),
                        http_port = 8082,
                        advertise_port = 13302,
                    }
                },
            },
        },
    })
    g.cluster:start()

    g.server = helpers.Server:new({
        workdir = fio.pathjoin(g.cluster.datadir, 'spare'),
        alias = 'spare',
        command = test_helper.server_command,
        replicaset_uuid = helpers.uuid('d'),
        instance_uuid = helpers.uuid('d', 'd', 1),
        http_port = 8083,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13303,
    })

    g.server:start()
    t.helpers.retrying({timeout = 5}, function()
        g.server:graphql({query = [[
            mutation{ probe_server(uri:"localhost:13301") }
        ]]})
    end)
end

g.after_all = function()
    g.cluster:stop()
    g.server:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_servers_labels()
    local request = [[{
        servers {
            uri
            labels { name value }
        }
    }]]

    local assert_labels = function(servers, dc_expected)
        t.assert_equals({
                ['uri'] =  'localhost:13301',
                ['labels'] = {{['name'] ='dc', ['value'] = dc_expected}}
            },
            test_helper.table_find_by_attr(servers, 'uri', 'localhost:13301')
        )
        t.assert_equals({
                ['uri'] =  'localhost:13302',
                ['labels'] = {},
            },
            test_helper.table_find_by_attr(servers, 'uri', 'localhost:13302')
        )
        t.assert_equals({
                ['uri'] =  'localhost:13303',
                ['labels'] = box.NULL
            },
            test_helper.table_find_by_attr(servers, 'uri', 'localhost:13303')
        )
    end

    local res = g.cluster.main_server:graphql({query = request})
    assert_labels(res['data']['servers'], 'msk')

    -- Edit labels
    local res = g.cluster.main_server:graphql({query = [[
        mutation {
            edit_server(
                uuid: "aaaaaaaa-aaaa-0000-0000-000000000001"
                labels: [{name: "dc", value: "spb"}]
            )
        }
    ]]})
    t.assert_equals(res['data']['edit_server'], true)

    -- Query labels once again
    local res = g.cluster.main_server:graphql({query = request})
    assert_labels(res['data']['servers'], 'spb')
end

function g.test_replicaset_labels()
    local res = g.cluster.main_server:graphql({query = [[{
        replicasets {
            servers {
                uri
                labels { name value }
            }
        }
    }]]})

    local replicasets = res['data']['replicasets']
    t.assert_equals(#replicasets, 1)
    local servers = replicasets[1].servers
    t.assert_equals(#servers, 2)


    local master = servers[1]
    t.assert_not_equals(master['labels'], nil)
    t.assert_equals(#master['labels'], 1)

    local slave = servers[2]
    t.assert_not_equals(slave['labels'], nil)
    t.assert_equals(#slave['labels'], 0)
end
