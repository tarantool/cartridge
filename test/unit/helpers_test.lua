#!/usr/bin/env tarantool

local t = require('luatest')
local g = t.group()

local fio = require('fio')
local yaml = require('yaml')
local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = 'test-cluster-cookie',
        base_http_port = 8080,
        base_advertise_port = 13300,
        replicasets = {
            {
                alias = 'vshard',
                uuid = helpers.uuid('b'),
                roles = {'vshard-router', 'vshard-storage'},
                servers = {
                    {instance_uuid = helpers.uuid('b', 'b', 1)},
                }
            },
            {
                alias = 'myrole',
                uuid = helpers.uuid('a'),
                roles = {'myrole'},
                servers = {
                    {instance_uuid = helpers.uuid('a', 'a', 1)},
                    {instance_uuid = helpers.uuid('a', 'a', 2)},
                }
            },
        },
    })

    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_cluster_helper()
    for i, server in ipairs(g.cluster.servers) do
        t.assert_equals(type(server.process.pid), 'number', 'Server ' .. i .. ' not started')
    end

    g.cluster:upload_config({some_section = 'some_value'})
    t.assert_equals(g.cluster:download_config(), {some_section = 'some_value'})

    g.cluster:upload_config(yaml.encode({another_section = 'some_value2'}))
    t.assert_equals(g.cluster:download_config(), {another_section = 'some_value2'})
end
