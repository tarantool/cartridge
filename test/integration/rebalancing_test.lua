local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        use_vshard = true,
        replicasets = {{
            alias = 'sA',
            uuid = helpers.uuid('a'),
            roles = {'myrole', 'vshard-router', 'vshard-storage'},
            servers = {{instance_uuid = helpers.uuid('a', 'a', 1)}},
        }, {
            alias = 'sB',
            uuid = helpers.uuid('b'),
            roles = {'myrole', 'vshard-router', 'vshard-storage'},
            servers = {{instance_uuid = helpers.uuid('b', 'b', 1)}},
        }},
    })
    g.cluster:start()
    g.sA1 = g.cluster:server('sA-1')
    g.sB1 = g.cluster:server('sB-1')

    local test_schema = {
        engine = 'memtx',
        is_local = false,
        temporary = false,
        format = {
            {name = 'bucket_id', type = 'unsigned', is_nullable = false},
            {name = 'record_id', type = 'unsigned', is_nullable = false},
        },
        indexes = {{
            name = 'pk', type = 'TREE', unique = true,
            parts = {{path = 'record_id', is_nullable = false, type = 'unsigned'}},
        },  {
            name = 'bucket_id', type = 'TREE', unique = false,
            parts = {{path = 'bucket_id', is_nullable = false, type = 'unsigned'}},
        }},
        sharding_key = {'record_id'},
    }
    g.cluster.main_server.net_box:call('cartridge_set_schema',
        {require('yaml').encode({spaces = {test = test_schema}})}
    )

    g.cluster.main_server.net_box:eval([[
        for i = 1, 3000 do
            vshard.router.callrw(
                i, 'box.space.test:insert',
                {{i, i, string.format('i%04d', i)}}
            )
        end
    ]])
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function set_weight(srv, weight)
    g.cluster.main_server:graphql({
        query = [[mutation ($uuid: String! $weight: Float!) {
            edit_replicaset(uuid: $uuid weight: $weight)
        }]],
        variables = {
            uuid = srv.replicaset_uuid,
            weight = weight,
        },
    })
end

local function set_roles(srv, roles)
    g.cluster.main_server:graphql({
        query = [[mutation ($uuid: String! $roles: [String!]) {
            edit_replicaset(uuid: $uuid roles: $roles)
        }]],
        variables = {
            uuid = srv.replicaset_uuid,
            roles = roles,
        },
    })
end

local function expel_sA1()
    return g.sB1:graphql({query = string.format(
        'mutation{ expel_server(uuid: %q) }',
        g.sA1.instance_uuid
    )})
end

local function get(srv, i)
    return srv.net_box:eval(
        'return require("vshard").router.callro(...)',
        {i, 'box.space.test:get', {i}}
    )
end

function g.test()
    t.assert_equals(g.sA1.net_box:call('box.space.test:len'), 1500)
    t.assert_equals(g.sB1.net_box:call('box.space.test:len'), 1500)

    -- Rebalancer runs on sA1
    g.sA1.net_box:eval([[assert(vshard.storage.internal.rebalancer_fiber ~= nil)]])
    g.sB1.net_box:eval([[assert(vshard.storage.internal.rebalancer_fiber == nil)]])

    -- Can't disable vshard-storage role with non-zero weight
    t.assert_error_msg_contains(
        "replicasets[aaaaaaaa-0000-0000-0000-000000000000]" ..
        " is a vshard-storage which can't be removed",
        set_roles, g.sA1, {}
    )

    -- It's prohibited to expel storage with non-zero weight
    t.assert_error_msg_contains(
        "replicasets[aaaaaaaa-0000-0000-0000-000000000000]" ..
        " is a vshard-storage which can't be removed",
        expel_sA1
    )

    g.sA1.net_box:call('vshard.storage.rebalancer_disable')
    set_weight(g.sA1, 0)

    -- Can't disable vshard-storage role until rebalancing finishes
    t.assert_error_msg_contains(
        "replicasets[aaaaaaaa-0000-0000-0000-000000000000]" ..
        " rebalancing isn't finished yet",
        set_roles, g.sA1, {}
    )

    -- It's prohibited to expel storage until rebalancing finishes
    t.assert_error_msg_equals(
        "replicasets[aaaaaaaa-0000-0000-0000-000000000000]" ..
        " rebalancing isn't finished yet",
        expel_sA1
    )

    g.sA1.net_box:call('vshard.storage.rebalancer_enable')
    helpers.retrying({}, function()
        g.sA1.net_box:call('vshard.storage.rebalancer_wakeup')

        t.assert_equals(g.sA1.net_box:call('vshard.storage.buckets_count'), 0)
        t.assert_equals(g.sB1.net_box:call('vshard.storage.buckets_count'), 3000)
        t.assert_equals(g.sA1.net_box:call('box.space.test:len'), 0)
        t.assert_equals(g.sB1.net_box:call('box.space.test:len'), 3000)
    end)

    set_roles(g.sA1, {'myrole'})

    local ok, err = get(g.sA1, 1500)
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        type = 'ShardingError',
        name = 'MISSING_MASTER',
        replicaset_uuid = g.sA1.replicaset_uuid,
        message = 'Master is not configured for' ..
            ' replicaset ' .. g.sA1.replicaset_uuid,
    })
    t.assert_equals(get(g.sB1, 1), {1, 1, 'i0001'})
    t.assert_equals(get(g.sB1, 3000), {3000, 3000, 'i3000'})

    helpers.retrying({}, function() g.sA1.net_box:eval([[
        for _, f in pairs(require('fiber').info()) do
            if f.name:startswith('vshard.') then
                error('Fiber ' .. f.name .. ' still alive', 0)
            end
        end
    ]]) end)

    -- sB1 remains the only storage, rebalancer should be there.
    g.sB1.net_box:eval([[
        assert(vshard.storage.internal.rebalancer_fiber ~= nil)
    ]])
    -- And not on sA1.
    g.sA1.net_box:eval([[
        assert(rawget(_G, 'vshard') == nil)
        assert(_G.__module_vshard_storage.rebalancer_fiber == nil)
        assert(not box.info.ro)
    ]])

    -- Check that re-enabling vshard works
    set_roles(g.sA1, {'myrole', 'vshard-router', 'vshard-storage'})
    set_weight(g.sA1, 2)

    helpers.retrying({}, function()
        t.assert_equals(g.sA1.net_box:call('vshard.storage.buckets_count'), 2000)
        t.assert_equals(g.sB1.net_box:call('vshard.storage.buckets_count'), 1000)
    end)

    t.assert_equals(g.sA1.net_box:call('vshard.router.bucket_count'), 3000)
    t.assert_equals(g.sB1.net_box:call('vshard.router.bucket_count'), 3000)
    t.assert_equals(g.sA1.net_box:call('box.space.test:len'), 2000)
    t.assert_equals(g.sB1.net_box:call('box.space.test:len'), 1000)

    t.assert_equals(get(g.sA1, 1), {1, 1, 'i0001'})
    t.assert_equals(get(g.sB1, 1), {1, 1, 'i0001'})
    t.assert_equals(get(g.sA1, 3000), {3000, 3000, 'i3000'})
    t.assert_equals(get(g.sB1, 3000), {3000, 3000, 'i3000'})
end
