local fio = require('fio')
local log = require('log')
local t = require('luatest')
local g = t.group('mismatch')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')
local utils = require('cartridge.utils')

g.setup = function()
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
                        advertise_port = 13301,
                    }
                },
            },
        },
    })
    g.cluster:start()
end

g.teardown = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_absent_config()
    g.cluster:stop()
    log.warn('Cluster stopped')

    fio.unlink(
        fio.pathjoin(g.cluster.main_server.workdir, 'config.yml')
    )
    log.warn('Config removed')

    log.info(g.cluster.main_server)
    g.cluster.main_server:start()
    g.cluster:retrying({}, function()
        g.cluster.main_server:connect_net_box()
    end)

    local state, err = g.cluster.main_server.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        return confapplier.get_state()
    ]])

    t.assert_equals(state, 'InitError')

    t.assert_equals(err.class_name, 'InitError')
    t.assert_equals(err.err,
        "Snapshot was found in " .. g.cluster.main_server.workdir ..
        ", but config.yml wasn't. Where did it go?"
    )
end


function g.test_absent_snapshot()
    g.cluster:stop()
    log.warn('Cluster stopped')

    local workdir = g.cluster.main_server.workdir
    for _, f in pairs(fio.glob(fio.pathjoin(workdir, '*.snap'))) do
        fio.unlink(f)
    end
    log.warn('Snapshots removed')

    log.info(g.cluster.main_server)
    g.cluster.main_server:start()
    g.cluster:retrying({}, function()
        g.cluster.main_server:connect_net_box()
    end)

    local state, err = g.cluster.main_server.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        return confapplier.get_state()
    ]])

    t.assert_equals(state, 'BootError')

    t.assert_equals(err.class_name, 'BootError')
    t.assert_equals(err.err,
        "Snapshot not found in " .. g.cluster.main_server.workdir ..
        ", can't recover. Did previous bootstrap attempt fail?"
    )
end


function g.test_invalid_config()
    g.cluster:stop()
    log.warn('Cluster stopped')


    utils.file_write(
        fio.pathjoin(g.cluster.main_server.workdir, 'config.yml'),
        [[
        topology:
            replicasets: {}
            servers: {}
        vshard:
            bootstrapped: false
            bucket_count: 3000
        ]]
    )

    log.warn('Config spoiled')

    log.info(g.cluster.main_server)
    g.cluster.main_server:start()
    g.cluster:retrying({}, function()
        g.cluster.main_server:connect_net_box()
    end)

    local state, err = g.cluster.main_server.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        return confapplier.get_state()
    ]])

    t.assert_equals(state, 'BootError')

    t.assert_equals(err.class_name, 'BootError')
    t.assert_equals(err.err,
        "Server " .. g.cluster.main_server.instance_uuid ..
        " not in clusterwide config, no idea what to do now"
    )
end
