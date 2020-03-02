local fio = require('fio')
local log = require('log')
local errno = require('errno')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.setup = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {'myrole'},
            servers = {{
                alias = 'master',
                instance_uuid = helpers.uuid('a', 'a', 1)
            }, {
                alias = 'slave',
                instance_uuid = helpers.uuid('a', 'a', 2)
            }},
        }},
    })

    g.cluster:start()
end

g.teardown = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
    if g.server ~= nil then
        g.server:stop()
        fio.rmtree(g.server.workdir)
    end
end

function g.test_rebootstrap()
    g.server = helpers.Server:new({
        workdir = g.cluster.datadir .. '/13303',
        alias = 'spare',
        command = g.cluster.server_command,
        replicaset_uuid = helpers.uuid('b'),
        instance_uuid = helpers.uuid('b', 'b', 1),
        http_port = 8083,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13303,
        env = {TARANTOOL_MEMTX_MEMORY = '1'},
    })

    g.server:start()
    t.helpers.retrying({timeout = 5}, function()
        g.server:graphql({query = '{}'})
    end)

    local err = t.assert_error(function() g.cluster:join_server(g.server) end)

    -- Retrying was added because of process can be alive (exists in process table)
    -- for a little time with Zombie state due to asynchroniuos libev child process waiting
    t.helpers.retrying({}, function()
        t.assert_not(g.server.process:is_alive())
    end)

    t.assert_equals(g.server.net_box:ping(), false)
    t.assert_equals(g.server.net_box.state, 'error')
    t.assert_str_contains(err, g.server.net_box.error)
    if g.server.net_box.error ~= 'Peer closed' then
        t.assert_equals(
            g.server.net_box.error,
            errno.strerror(errno.ECONNRESET)
        )
    end

    -- Heal the server and restart
    log.info('--------------------------------------------------------')
    g.server.env['TARANTOOL_MEMTX_MEMORY'] = nil
    g.server:start()
    g.cluster:wait_until_healthy()
end

local function test_rejoin(srv)
    g.cluster.main_server.net_box:eval([[
        box.schema.space.create('test')
        box.space.test:create_index('pk', {parts = {1, 'string'}})
        box.space.test:insert({'victim', ...})
    ]], {srv.alias})

    srv:stop()
    local workdir = srv.workdir
    for _, f in pairs(fio.glob(fio.pathjoin(workdir, '*.snap'))) do
        fio.unlink(f)
    end

    log.info('--------------------------------------------------------')
    srv:start()
    g.cluster:wait_until_healthy()

    t.assert_equals(
        srv.net_box:call('box.space.test:get', {'victim'}),
        {'victim', srv.alias}
    )
end

function g.test_rejoin_slave()
    test_rejoin(g.cluster:server('slave'))
end

function g.test_rejoin_master()
    test_rejoin(g.cluster:server('master'))
end
