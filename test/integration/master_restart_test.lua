local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_each(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {
                    {
                        alias = 'master',
                        instance_uuid = helpers.uuid('a', 'a', 1),
                        -- advertise_port = 13301,
                    },
                    {
                        alias = 'replica',
                        instance_uuid = helpers.uuid('a', 'a', 2),
                        -- advertise_port = 13301,
                    }
                },
            },
        },
    })
    g.cluster:start()
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_master_restart_with_missing_xlog()
    g.cluster:server('master').net_box:eval([[
        -- create space
        box.schema.create_space('test')
        box.space.test:create_index('primary')
        box.space.test:insert{1}

        box.snapshot()

        -- that transaction now stored in memory and xlog
        box.begin()
        box.space.test:insert{2}
        box.space.test:insert{3}
        box.commit()
    ]])

    -- check that data replicated
    local content = g.cluster:server('replica').net_box:eval([[
        return box.space.test:select()
    ]])
    t.assert_equals(content, {{1}, {2}, {3}})

    -- stop master and remove xlogs
    g.cluster:server('master'):stop()
    for _, name in ipairs(fio.glob(g.cluster:server('master').workdir .. '/*.xlog')) do
        t.assert(fio.unlink(name))
    end
    g.cluster:server('master'):start()

    -- check that data still on replica
    local content = g.cluster:server('replica').net_box:eval([[
        return box.space.test:select()
    ]])
    t.assert_equals(content, {{1}, {2}, {3}})

    local info_replication = g.cluster:server('master').net_box:eval([[
        return box.info.replication
    ]])

    -- check that data restored on master
    local content = g.cluster:server('master').net_box:eval([[
        return box.space.test:select()
    ]])
    t.assert_equals(content, {{1}, {2}, {3}}, info_replication[2].upstream.message)
end
