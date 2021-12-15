local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local utils = require('cartridge.utils')
local yaml = require('yaml')
local log = require('log')

g.before_all = function()
    local kuka = require('digest').urandom(6):hex()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = kuka,
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

    g.cluster2 = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = kuka,
        replicasets = {
            {
                alias = 'master',
                uuid = helpers.uuid('b'),
                roles = {},
                servers = {{
                    http_port = 8082,
                    advertise_port = 13302,
                    instance_uuid = helpers.uuid('b', 'b', 1)
                }},
            }
        },
    })

    g.cluster2:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
    g.cluster2:stop()
    fio.rmtree(g.cluster2.datadir)
end

function g.test_two_clusters()
    local res, err = g.cluster.main_server:graphql({query = [[
            mutation { join_server(uri: "127.0.0.1:13302") }
        ]],
        raise=false
    })
    t.assert_str_contains(res.errors[1].message, "Upload not found")
end