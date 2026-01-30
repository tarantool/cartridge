#!/usr/bin/env tarantool

local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_each(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {
            {
                alias = 'router',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = 1,
            },
            {
                alias = 'storage',
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                servers = 1,
            },
        },
    })
    g.cluster:start()
end)

g.after_each(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_custom_bootstrap_timeout()
    local router = g.cluster:server('router-1')
    
    -- Test that custom timeout is respected by checking vars
    local timeout = router:eval([[
        local vshard_router = require('cartridge.roles.vshard-router')
        local vars = require('cartridge.vars').new('cartridge.roles.vshard-router')
        return vars.bootstrap_timeout
    ]])
    
    -- Default should be 10
    t.assert_equals(timeout, 10)
    
    -- Bootstrap should work with default timeout
    local ok, err = router:graphql({
        query = [[
            mutation {
                bootstrap_vshard
            }
        ]]
    })
    t.assert_equals(err, nil)
end

function g.test_custom_timeout_with_env()
    -- Stop the cluster to restart with custom timeout
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
    
    -- Create cluster with custom bootstrap timeout
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        env = {
            TARANTOOL_VSHARD_BOOTSTRAP_TIMEOUT = '30',
        },
        replicasets = {
            {
                alias = 'router',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = 1,
            },
            {
                alias = 'storage',
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                servers = 1,
            },
        },
    })
    g.cluster:start()
    
    local router = g.cluster:server('router-1')
    
    -- Verify custom timeout is set
    local timeout = router:eval([[
        local vars = require('cartridge.vars').new('cartridge.roles.vshard-router')
        return vars.bootstrap_timeout
    ]])
    
    t.assert_equals(timeout, 30)
end

function g.test_invalid_timeout_values()
    -- Stop the cluster to test with invalid values
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
    
    -- Test with negative timeout (should fail)
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        env = {
            TARANTOOL_VSHARD_BOOTSTRAP_TIMEOUT = '-1',
        },
        replicasets = {
            {
                alias = 'router',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = 1,
            },
        },
    })
    
    -- Server should fail to start with invalid timeout
    t.assert_error_msg_contains(
        'vshard_bootstrap_timeout must be a finite positive number greater than 0',
        function() g.cluster:start() end
    )
    
    -- Clean up
    fio.rmtree(g.cluster.datadir)
    
    -- Test with zero timeout (should fail)
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        env = {
            TARANTOOL_VSHARD_BOOTSTRAP_TIMEOUT = '0',
        },
        replicasets = {
            {
                alias = 'router',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = 1,
            },
        },
    })
    
    t.assert_error_msg_contains(
        'vshard_bootstrap_timeout must be a finite positive number greater than 0',
        function() g.cluster:start() end
    )
    
    -- Clean up
    fio.rmtree(g.cluster.datadir)
    
    -- Test with infinity timeout (should fail)
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        env = {
            TARANTOOL_VSHARD_BOOTSTRAP_TIMEOUT = 'inf',
        },
        replicasets = {
            {
                alias = 'router',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = 1,
            },
        },
    })
    
    t.assert_error_msg_contains(
        'vshard_bootstrap_timeout must be a finite positive number greater than 0',
        function() g.cluster:start() end
    )
end
