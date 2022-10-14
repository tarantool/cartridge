local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = 'qwerty123',
        replicasets = { {
                alias = 'A',
                roles = {'vshard-router'},
                servers = 1,
            }, {
                alias = 'B',
                roles = {'vshard-storage'},
                servers = {
                    {
                        http_port = 8084,
                        advertise_port = 13304,
                    }, {
                        http_port = 8082,
                        advertise_port = 13302,
                    }, {
                        http_port = 8083,
                        advertise_port = 13303,
                    },
                },
                },
        }
    })
    g.cluster:start()
    g.B1 = assert(g.cluster:server('B-1'))
    g.B2 = assert(g.cluster:server('B-2'))
    g.B3 = assert(g.cluster:server('B-3'))
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_replication_in_right_order()
    for _, v in ipairs{g.B1, g.B2, g.B3} do
        t.assert_equals(v:exec(function()
            return box.cfg.replication
        end), {'admin:qwerty123@localhost:13302', 'admin:qwerty123@localhost:13303', 'admin:qwerty123@localhost:13304'})
    end
end
