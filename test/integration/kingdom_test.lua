local fio = require('fio')
local uuid = require('uuid')
local netbox = require('net.box')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_each(function()
    g.datadir = fio.tempdir()
    local password = require('digest').urandom(6):hex()

    fio.mktree(fio.pathjoin(g.datadir, 'kingdom'))
    g.kingdom = require('luatest.server'):new({
        command = fio.pathjoin(helpers.project_root, 'kingdom.lua'),
        workdir = fio.pathjoin(g.datadir),
        net_box_port = 13301,
        net_box_credentials = {
            user = 'client',
            password = password,
        },
        env = {
            TARANTOOL_PASSWORD = password,
            TARANTOOL_LOCK_DELAY = 40,
        },
    })
    g.kingdom:start()
    helpers.retrying({}, function()
        g.kingdom:connect_net_box()
    end)
end)

g.after_each(function()
    g.kingdom:stop()
    fio.rmtree(g.datadir)
end)

local function connect(srv)
    return netbox.connect(srv.net_box_port, srv.net_box_credentials)
end

function g.test_locks()
    local c1 = connect(g.kingdom)
    local c2 = connect(g.kingdom)
    local kid = uuid.str()

    t.assert_equals(
        c1:call('acquire_lock', {kid, 'localhost:9'}),
        true
    )
    t.assert_equals(
        c1:call('get_coordinator'),
        {uuid = kid, uri = 'localhost:9'}
    )

    t.assert_equals(
        c2:call('acquire_lock', {uuid.str(), 'localhost:11'}),
        false
    )
    t.assert_equals(
        {c2:call('set_leaders', {{'A', 'a1'}})},
        {box.NULL, 'You are not holding the lock'}
    )
    t.assert_equals(
        c2:call('get_coordinator'),
        {uuid = kid, uri = 'localhost:9'}
    )

    c1:close()
    local kid = uuid.str()
    helpers.retrying({}, function()
        t.assert_equals(c2:call('get_coordinator'), box.NULL)
    end)

    t.assert_equals(
        c2:call('acquire_lock', {kid, 'localhost:11'}),
        true
    )
    t.assert_equals(
        c2:call('get_coordinator'),
        {uuid = kid, uri = 'localhost:11'}
    )
end

function g.test_appointments()
    local c = connect(g.kingdom)
    local kid = uuid.str()
    t.assert_equals(
        c:call('acquire_lock', {kid, 'localhost:9'}),
        true
    )

    t.assert_equals(
        c:call('set_leaders', {{{'A', 'a1'}, {'B', 'b1'}}}),
        true
    )

    t.assert_equals(
        c:call('get_leaders'),
        {A = 'a1', B = 'b1'}
    )

    t.assert_error_msg_equals(
        "Duplicate key exists in unique index 'ordinal'" ..
        " in space 'leader_audit'",
        c.call, c, 'set_leaders', {{{'A', 'a2'}, {'A', 'a3'}}}
    )
end

function g.test_longpolling()
    local c1 = connect(g.kingdom)
    local kid = uuid.str()
    t.assert_equals(
        c1:call('acquire_lock', {kid, 'localhost:9'}),
        true
    )
    c1:call('set_leaders', {{{'A', 'a1'}, {'B', 'b1'}}})

    local c2 = connect(g.kingdom)
    t.assert_equals(c2:call('longpoll'), {A = 'a1', B = 'b1'})
    local future = c2:call('longpoll', {0.2}, {is_async = true})
    c1:call('set_leaders', {{{'A', 'a2'}}})

    local ret, err = future:wait_result(0.1) -- err is cdata
    t.assert_equals({ret, tostring(err)}, { {{A = 'a2'}}, 'nil' })

    local future = c2:call('longpoll', {0.2}, {is_async = true})
    local ret, err = future:wait_result(0.1) -- err is cdata
    t.assert_equals({ret, tostring(err)}, {nil, 'Timeout exceeded'})

    local ret, err = future:wait_result(0.2)  -- err is cdata
    t.assert_equals({ret, tostring(err)}, { {{}}, 'nil' })
end

function g.test_passwd()
    local new_password = require('digest').urandom(6):hex()

    g.kingdom:stop()
    g.kingdom.env.TARANTOOL_PASSWORD = new_password
    g.kingdom.net_box_credentials.password = new_password
    g.kingdom:start()
    helpers.retrying({}, function()
        g.kingdom:connect_net_box()
    end)

    t.assert_equals(g.kingdom.net_box:call('get_lock_delay'), 40)
end
