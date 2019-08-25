#!/usr/bin/env tarantool

local fio = require('fio')
local yaml = require('yaml')

local t = require('luatest')
local g = t.group('test_helpers')

local ROOT = fio.dirname(fio.abspath(package.search('cartridge')))
local datadir = fio.pathjoin(ROOT, 'dev', 'db_test')
fio.rmtree(datadir)

local Cluster = require('cartridge.test-helpers.cluster')
local helpers = require('cartridge.test-helpers')

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
            }
        }
    },
})


g.test_cluster_helper = function()
    cluster:start()
    for i, server in ipairs(cluster.servers) do
        t.assert_equals(type(server.process.pid), 'number', 'Server ' .. i .. ' not started')
    end

    cluster:upload_config({some_section = 'some_value'})
    t.assert_equals(cluster:download_config(), {some_section = 'some_value'})

    cluster:upload_config(yaml.encode({another_section = 'some_value2'}))
    t.assert_equals(cluster:download_config(), {another_section = 'some_value2'})
    cluster:stop()
end
