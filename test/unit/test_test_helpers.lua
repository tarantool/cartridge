#!/usr/bin/env tarantool

local fio = require('fio')

local tap = require('tap')
local test = tap.test('cluster.test_helpers')

local ROOT = fio.dirname(fio.abspath(package.search('cluster')))
local datadir = fio.pathjoin(ROOT, 'dev', 'db_test')
fio.rmtree(datadir)

local Cluster = require('cluster.test_helpers.cluster')
local helpers = require('cluster.test_helpers')

local cluster = Cluster:new({
    datadir = datadir,
    use_vshard = true,
    server_command = fio.pathjoin(ROOT, 'test/unit/instance.lua'),
    cookie = 'test-cluster-cookie',
    base_http_port = 8080,
    base_advertise_port = 33000,
    replicasets = {
        {
            alias = 'myrole',
            uuid = helpers.uuid('a'),
            roles = {'myrole'},
            servers = {
                {instance_uuid = helpers.uuid('a', 'a', 1)},
                {instance_uuid = helpers.uuid('a', 'a', 2)},
            }
        },
        {
            alias = 'vshard',
            uuid = helpers.uuid('b'),
            roles = {'vshard-router', 'vshard-storage'},
            servers = {
                {instance_uuid = helpers.uuid('b', 'b', 1)},
                {instance_uuid = helpers.uuid('b', 'b', 2)},
            }
        }
    },
})

test:plan(4 + 1)

local ok, err = pcall(function()
    cluster:start()
    for i, server in ipairs(cluster.servers) do
        test:isnumber(server.process.pid, 'Server ' .. i .. ' started')
    end
end)
if not test:ok(ok, 'Cluster started') then
    test:diag(err)
end
cluster:stop()

os.exit(test:check() and 0 or 1)
