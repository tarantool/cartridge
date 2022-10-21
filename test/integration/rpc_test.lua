local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
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
                        labels = {{name = 'spb', value = 'dc'}}
                    },{
                        alias = 'B2',
                        instance_uuid = helpers.uuid('b', 'b', 2),
                        advertise_port = 13303,
                        http_port = 8083,
                        labels = {{name = 'spb', value = 'dc'}, {name = 'meta', value = 'runner'}}
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
    local res, err = server:eval([[
        local rpc = require('cartridge.rpc')
        return rpc.call(...)
    ]], {role_name, fn_name, args, kv_args})
    return res, err
end

function g.test_api()
    local A1 = g.cluster:server('A1')
    local B1 = g.cluster:server('B1')

    local res, err = rpc_call(A1, 'myrole', 'get_state')
    t.assert_not(err)
    t.assert_equals(res, 'initialized')

    local res, err = rpc_call(A1, 'myrole',
        'fn_undefined', nil,
        {uri = "127.0.0.1:13303"}
    )
    t.assert_not(res)
    t.assert_covers(err, {
        class_name = 'RemoteCallError',
        err =  '"127.0.0.1:13303": Role "myrole" has no method "fn_undefined"'
    })

    local res, err = rpc_call(A1, 'unknown-role', 'fn_undefined')
    t.assert_not(res)
    t.assert_covers(err, {
        class_name = 'RemoteCallError',
        err = 'No remotes with role "unknown-role" available'
    })

    -- restrict connections to vshard-router
    A1:call('box.cfg', {{listen = box.NULL}})
    B1:eval([[
        local pool = require('cartridge.pool')
        pool.connect(...):close()
        local conn = pool.connect(...)
        assert(conn:wait_connected() == false)
    ]], {A1.advertise_uri, {wait_connected = false}})

    local res, err = rpc_call(B1, 'vshard-router', 'bootstrap')
    t.assert_not(res)
    t.assert_covers(err, {
        class_name = 'RemoteCallError',
    })
    t.assert_str_matches(err.err, '"localhost:13301":.*Connection refused')
end

g.after_test('test_api', function()
    -- restore box listen
    local A1 = g.cluster:server('A1')
    A1:call('box.cfg', {{listen = A1.net_box_port}})
end)

function g.test_errors()
    local res, err = rpc_call(
        g.cluster:server('A1'), 'myrole', 'throw', {'Boo'}, {leader_only = true}
    )
    t.assert_not(res)
    t.assert_covers(err, {
        class_name = 'RemoteCallError',
        err = '"localhost:13302": Boo',
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
        srv:eval([[
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
    t.assert_equals(res.peer, B2:call('box.session.peer'))

    -- Test opts.leader_only and opts.prefer_local
    --------------------------------------------------------------------

    local res, err = rpc_call(B1,
        'myrole', 'get_session', nil,
        {prefer_local = false, leader_only = true}
    )
    t.assert_not(err)
    t.assert_equals(res.uuid, B1.instance_uuid)
    t.assert_not_equals(res.peer, B1:call('box.session.peer'))

    -- Test opts.labels with one label
    --------------------------------------------------------------------
    local res, err = rpc_call(B1,
        'myrole', 'get_session', nil,
        {labels = {['meta'] = 'runner'}}
    )
    t.assert_not(err)
    t.assert_equals(res.uuid, B2.instance_uuid)

    -- Test opts.labels with two labels
    --------------------------------------------------------------------
    local res, err = rpc_call(B1,
        'myrole', 'get_session', nil,
        {labels = {['spb'] = 'dc', ['meta'] = 'runner'}}
    )
    t.assert_not(err)
    t.assert_equals(res.uuid, B2.instance_uuid)

    -- Test opts.leader_only and opts.labels
    --------------------------------------------------------------------
    local res, err = rpc_call(B2,
        'myrole', 'get_session', nil,
        {labels = {['spb'] = 'dc'}, leader_only = true}
    )
    t.assert_not(err)
    t.assert_equals(res.master, true)
    t.assert_equals(res.uuid, B1.instance_uuid)

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
    t.assert_not_equals(res.peer, B2:call('box.session.peer'))

    local res, err = rpc_call(B2,
        'myrole', 'void', nil,
        {uri = 'localhost:0'}
    )
    t.assert_not(res)
    t.assert_str_matches(err.err, '"localhost:0":.*')

    local res, err = rpc_call(B2,
        'myrole', 'void', nil,
        {uri = 'localhost:9'}
    )
    t.assert_not(res)
    t.assert_str_matches(err.err, '"localhost:9":.*')

    t.assert_error_msg_contains(
        'bad argument opts.uri to rpc_call' ..
        ' (conflicts with opts.leader_only=true or opts.labels={...})',
        rpc_call, B2,
        'myrole', 'void', nil,
        {uri = B2.advertise_uri, leader_only = true}
    )

    t.assert_error_msg_contains(
        'bad argument opts.uri to rpc_call' ..
        ' (conflicts with opts.leader_only=true or opts.labels={...})',
        rpc_call, B2,
        'myrole', 'void', nil,
        {uri = B2.advertise_uri, labels = {}}
    )
end

function g.test_push()
    local function rpc_call(server, role_name, fn_name, args, kv_args)
        local res, err = server:eval([[
            local role_name, fn_name, args, kv_args = ...
            local rpc = require('cartridge.rpc')
            local result = {}
            local function on_push(ctx, data)
                result.ctx = ctx
                result.data = data
            end
            kv_args.on_push = on_push
            kv_args.on_push_ctx = 'context'
            local ok, err = rpc.call(role_name, fn_name, args, kv_args)
            if not ok then
                return nil, err
            end
            return result
        ]], {role_name, fn_name, args, kv_args})
        return res, err
    end

    local B2 = g.cluster:server('B2')
    local res, err = rpc_call(
        B2, 'myrole', 'push', {1}, {prefer_local=false}
    )

    t.assert_equals(err, nil)
    t.assert_equals(type(res), 'table')
    t.assert_equals(res.ctx, 'context')
    t.assert_equals(res.data, 2)

    t.assert_error_msg_contains(
        'bad argument opts.on_push/opts.on_push_ctx to rpc_call' ..
        ' (allowed to be used only with opts.prefer_local=false)',
        rpc_call, B2,
        'myrole', 'push', {1},
        {prefer_local = true}
    )
end
