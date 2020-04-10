local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local errno = require('errno')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
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
    t.assert_covers(err, {
        class_name = 'RemoteCallError',
        err =  'Role "myrole" has no method "fn_undefined"'
    })

    local res, err = rpc_call(server, 'unknown-role', 'fn_undefined')
    t.assert_not(res)
    t.assert_covers(err, {
        class_name = 'RemoteCallError',
        err = 'No remotes with role "unknown-role" available'
    })
end

function g.test_errors()
    local res, err = rpc_call(
        g.cluster:server('A1'), 'myrole', 'throw', {'Boo'}, {leader_only = true}
    )
    t.assert_not(res)
    t.assert_covers(err, {
        class_name = 'RemoteCallError',
        err = 'Boo',
    })
    t.assert_str_contains(err.stack, 'during net.box call to localhost:13302')

    local res, err = rpc_call(
        g.cluster:server('B1'), 'myrole', 'throw', {'Moo'}, {leader_only=true}
    )
    t.assert_not(res)
    t.assert_covers(err, {
        class_name = 'RemoteCallError',
        err = 'Moo'
    })
    t.assert_not_str_contains(err.stack, 'during net.box call')
end

function g.test_routing()
    local B1 = g.cluster:server('B1')
    local B2 = g.cluster:server('B2')
    for _, srv in pairs({B1, B2}) do
        -- inject new role method `get_session`
        srv.net_box:eval([[
            local myrole = require('mymodule')
            function myrole.get_session()
                return {
                    uuid = box.info.uuid,
                    peer = box.session.peer() or box.NULL,
                    master = myrole.is_master(),
                }
            end
        ]])
    end

    -- Test opts.prefer_local
    --------------------------------------------------------------------
    local res, err = rpc_call(B2,
        'myrole', 'get_session', nil,
        {--[[ implies prefer_local = true ]]}
    )
    t.assert_not(err)
    t.assert_equals(res.uuid, B2.instance_uuid)
    t.assert_equals(res.peer, B2.net_box:call('box.session.peer'))

    -- Test opts.leader_only and opts.prefer_local
    --------------------------------------------------------------------

    local res, err = rpc_call(B1,
        'myrole', 'get_session', nil,
        {prefer_local = false, leader_only = true}
    )
    t.assert_not(err)
    t.assert_equals(res.uuid, B1.instance_uuid)
    t.assert_not_equals(res.peer, B1.net_box:call('box.session.peer'))

    -- Test opts.leader_only
    --------------------------------------------------------------------
    local res, err = rpc_call(B2,
        'myrole', 'get_session', nil,
        {leader_only = true}
    )
    t.assert_not(err)
    t.assert_equals(res.master, true)
    t.assert_equals(res.uuid, B1.instance_uuid)

    -- Test opts.uri
    --------------------------------------------------------------------
    local res, err = rpc_call(B2,
        'myrole', 'get_session', nil,
        {uri = B1.advertise_uri}
    )
    t.assert_not(err)
    t.assert_equals(res.uuid, B1.instance_uuid)

    local res, err = rpc_call(B2,
        'myrole', 'get_session', nil,
        {uri = B2.advertise_uri, --[[ implies prefer_local = false ]]}
    )
    t.assert_not(err)
    t.assert_equals(res.uuid, B2.instance_uuid)
    t.assert_not_equals(res.peer, B2.net_box:call('box.session.peer'))

    local res, err = rpc_call(B2,
        'myrole', 'void', nil,
        {uri = 'localhost:0'}
    )
    t.assert_not(res)
    t.assert_items_include(
        {
            '"localhost:0": ' .. errno.strerror(errno.ECONNREFUSED),
            '"localhost:0": ' .. errno.strerror(errno.ENETUNREACH),
            '"localhost:0": ' .. errno.strerror(errno.EADDRNOTAVAIL),
        }, {err.err}
    )

    local res, err = rpc_call(B2,
        'myrole', 'void', nil,
        {uri = 'localhost:9'}
    )
    t.assert_not(res)
    t.assert_items_include(
        {
            '"localhost:9": ' .. errno.strerror(errno.ECONNREFUSED),
            '"localhost:9": ' .. errno.strerror(errno.ENETUNREACH),
        }, {err.err}
    )

    t.assert_error_msg_contains(
        'bad argument opts.uri to rpc_call' ..
        ' (conflicts with opts.leader_only=true)',
        rpc_call, B2,
        'myrole', 'void', nil,
        {uri = B2.advertise_uri, leader_only = true}
    )
end
