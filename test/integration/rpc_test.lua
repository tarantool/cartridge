local fio = require('fio')
local t = require('luatest')
local g = t.group('rpc')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        cookie = 'test-cluster-cookie',

        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {},
                servers = {{
                    alias = 'A1',
                    instance_uuid = helpers.uuid('a', 'a', 1),
                    advertise_port = 13301,
                    http_port = 8081,
                }}
            }, {
                uuid = helpers.uuid('b'),
                roles = {'myrole'},
                servers = {
                    {
                        alias = 'B1',
                        instance_uuid = helpers.uuid('b', 'b', 1),
                        advertise_port = 13302,
                        http_port = 8082,
                    },{
                        alias = 'B2',
                        instance_uuid = helpers.uuid('b', 'b', 2),
                        advertise_port = 13303,
                        http_port = 8083,
                    }
                }
            }
        }
    })
    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end


local function rpc_call(server, role_name, fn_name, args, kv_args)
    local res, err = server.net_box:eval([[
        local rpc = require('cartridge.rpc')
        return rpc.call(...)
    ]], {role_name, fn_name, args, kv_args})
    return res, err
end

function g.test_api()
    local server = g.cluster:server('A1')

    local res, err = rpc_call(server, 'myrole', 'get_state')
    t.assert_not(err)
    t.assert_equals(res, 'initialized')

    local res, err = rpc_call(server, 'myrole', 'fn_undefined')
    t.assert_not(res)
    t.assert_equals(err.err, 'Role "myrole" has no method "fn_undefined"')

    local res, err = rpc_call(server, 'unknown-role', 'fn_undefined')
    t.assert_not(res)
    t.assert_equals(err.err, 'No remotes with role "unknown-role" available')
end

function g.test_errors()
    local res, err = rpc_call(
        g.cluster:server('A1'), 'myrole', 'throw', {'Boo'}, {leader_only = true}
    )
    t.assert_not(res)
    t.assert_equals(err.err, 'Boo')
    t.assert_equals(err.class_name, 'RemoteCallError')
    t.assert_str_icontains(err.str, 'during net.box call to localhost:13302')

    local res, err = rpc_call(
        g.cluster:server('B1'), 'myrole', 'throw', {'Moo'}, {leader_only=true}
    )
    t.assert_not(res)
    t.assert_equals(err.err, 'Moo')
    t.assert_equals(err.class_name, 'RemoteCallError')
    t.assert_not_str_icontains(err.str, 'during net.box call')
end

function g.test_routing()
    local res, err = rpc_call(
        g.cluster:server('B2'), 'myrole', 'is_master', nil, {leader_only=true}
    )
    t.assert_not(err)
    t.assert_equals(res, true)
end
