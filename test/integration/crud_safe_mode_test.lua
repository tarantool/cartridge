local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        use_vshard = true,
        replicasets = {
            {
                alias = 'router',
                roles = {'vshard-router'},
                servers = 1,
            },
            {
                alias = 'storage',
                roles = {'vshard-storage'},
                servers = 2,
            },
        },
    })
    g.cluster:start()
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

g.after_each(function()
    for _, server in ipairs(g.cluster.servers) do
        server:exec(function()
            rawset(_G, '_crud', nil)
        end)
    end
end)

-- Mimics the storage API which crud.init_storage() exports.
local function stub_crud_storage(server, safe_mode)
    server:exec(function(safe_mode)
        local crud_storage = {}
        if safe_mode ~= nil then
            crud_storage.rebalance_safe_mode_status = function()
                return safe_mode
            end
        end
        rawset(_G, '_crud', crud_storage)
    end, {safe_mode})
end

local function crud_info()
    local resp = g.cluster.main_server:graphql({
        query = [[{
            servers {
                alias
                boxinfo {
                    crud {
                        safe_mode
                    }
                }
            }
        }]]
    })

    local ret = {}
    for _, server in ipairs(resp.data.servers) do
        ret[server.alias] = server.boxinfo.crud
    end
    return ret
end

function g.test_without_crud()
    t.assert_equals(crud_info(), {
        ['router-1'] = box.NULL,
        ['storage-1'] = box.NULL,
        ['storage-2'] = box.NULL,
    })
end

function g.test_with_crud()
    stub_crud_storage(g.cluster:server('storage-1'), true)
    stub_crud_storage(g.cluster:server('storage-2'), false)

    t.assert_equals(crud_info(), {
        ['router-1'] = box.NULL,
        ['storage-1'] = {safe_mode = true},
        ['storage-2'] = {safe_mode = false},
    })
end

function g.test_crud_without_safe_mode()
    stub_crud_storage(g.cluster:server('storage-1'), nil)

    t.assert_equals(crud_info(), {
        ['router-1'] = box.NULL,
        ['storage-1'] = {safe_mode = box.NULL},
        ['storage-2'] = box.NULL,
    })
end
