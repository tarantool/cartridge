local fio = require('fio')
local t = require('luatest')
local g = t.group()

local utils = require('cartridge.utils')
local helpers = require('test.helper')

g.before_each(function()
    g.tempdir = fio.tempdir()
    g.server = helpers.Server:new({
        alias = 'srv',
        workdir = g.tempdir,
        command = helpers.entrypoint('srv_basic'),
        instance_uuid = helpers.uuid('a', 'a', 1),
        replicaset_uuid = helpers.uuid('a'),
        cluster_cookie = helpers.random_cookie(),
        advertise_port = 13301,
        http_port = 8081,
    })
end)

g.after_each(function()
    g.server:stop()
    fio.rmtree(g.tempdir)
end)

function g.test_no_connect_quorum_warning()
    t.skip_if(not utils.version_is_at_least(2, 11, 10),
        'the deprecation warning is only suppressed since Tarantool 2.11.10')

    g.server:start()
    helpers.Server.join_cluster(g.server, g.server)

    local stderr = g.server.process.output_beautifier.stderr
    t.assert_not_str_contains(stderr, 'Deprecated option replication_connect_quorum')
end
