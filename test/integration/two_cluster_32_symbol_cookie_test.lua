local fio = require('fio')
local digest = require('digest')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    local cookie = digest.urandom(16):hex()

    g.cluster1 = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = cookie..'a',
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
        env = {
            TARANTOOL_SET_COOKIE_HASH_MEMBERSHIP = 'true',
        }
    })

    g.cluster1:start()

    g.cluster2 = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = cookie..'b',
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
        env = {
            TARANTOOL_SET_COOKIE_HASH_MEMBERSHIP = 'true',
        }
    })

    g.cluster2.servers[1]:start()
    -- this instance is seen by the first cluster
    -- because of membership encryption key
    -- ignores keys with lenght > 32 symbols
    -- setting TARANTOOL_SET_COOKIE_HASH_MEMBERSHIP to true
    -- fixes this bug
end

g.after_all = function()
    g.cluster1:stop()
    fio.rmtree(g.cluster1.datadir)
    g.cluster2:stop()
    fio.rmtree(g.cluster2.datadir)
end

function g.test_two_clusters()
    local res = g.cluster1.main_server:exec(function()
        local members = require('membership').members()
        return members['localhost:13302']
    end)
    t.assert_not(res)
end
