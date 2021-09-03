local t = require('luatest')
local h = require('test.helper')
local g = t.group()

local fio = require('fio')

g.before_each(function()
    g.cluster = h.Cluster:new({
        datadir = fio.tempdir(),
        server_command = h.entrypoint('srv_basic'),
        cookie = h.random_cookie(),
        replicasets = {
            {
                roles = {},
                servers = {
                    { alias = 'master' },
                    { alias = 'replica' },
                },
            },
        },
    })
    g.cluster:start()
    g.master = g.cluster:server('master')
    g.replica = g.cluster:server('replica')
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_master_restart_with_missing_xlog()
    g.master.net_box:eval([[
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
    t.helpers.retrying({}, function()
        local content = g.replica.net_box:eval([[
            return box.space.test:select()
        ]])
        t.assert_equals(content, {{1}, {2}, {3}})
    end)

    -- stop master and remove xlogs
    g.master:stop()
    for _, name in ipairs(fio.glob(g.master.workdir .. '/*.xlog')) do
        t.assert(fio.unlink(name))
    end
    g.master:start()

    -- check that data still on replica
    local content = g.replica.net_box:eval([[
        return box.space.test:select()
    ]])
    t.assert_equals(content, {{1}, {2}, {3}})

    t.helpers.retrying({}, function()
        local info_replication = g.master.net_box:eval([[
            return box.info.replication
        ]])

        -- check that data restored on master
        local content = g.master.net_box:eval([[
            return box.space.test:select()
        ]])
        t.assert_equals(content, {{1}, {2}, {3}}, info_replication[2].upstream.message)
    end)
end
