local fio = require('fio')
local log = require('log')
local fiber = require('fiber')
local errors = require('errors')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local function reload(srv)
    local ok, err = srv.net_box:eval([[
        return require("cartridge.roles").reload()
    ]])

    t.assert_equals({ok, err}, {true, nil})
end

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = '', -- helpers.random_cookie(),
        replicasets = {
            {alias = 'R', roles = {'vshard-router'}, servers = 1},
            {alias = 'SA', roles = {'vshard-storage'}, servers = 2},
            {alias = 'SB', roles = {'vshard-storage'}, servers = 2}
        },
        -- replicasets = {{
        --     alias = 'R',
        --     uuid = helpers.uuid('a'),
        --     roles = {'vshard-router'},
        --     servers = {{instance_uuid = helpers.uuid('a', 'a', 1)}},
        -- }, {
        --     alias = 'SA',
        --     uuid = helpers.uuid('f', 'a'),
        --     roles = {'vshard-storage'},
        --     servers = {
        --         {instance_uuid = helpers.uuid('f', 'a', 1)},
        --         {instance_uuid = helpers.uuid('f', 'a', 2)},
        --     },
        -- }, {
        --     alias = 'SB',
        --     uuid = helpers.uuid('e', 'b'),
        --     roles = {'vshard-storage'},
        --     servers = {
        --         {instance_uuid = helpers.uuid('e', 'b', 1)},
        --         {instance_uuid = helpers.uuid('e', 'b', 2)},
        --     },
        -- }},

    })
    g.cluster:start()

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

    g.R1 = assert(g.cluster:server('R-1'))
    g.SA1 = assert(g.cluster:server('SA-1'))
    g.SA2 = assert(g.cluster:server('SA-2'))

    g.insertions_passed = {}
    g.insertions_failed = {}
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

local function _insert(cnt, label)
    local ret, err = g.R1.net_box:eval([[
        local ret, err = package.loaded.vshard.router.callrw(...)
        if ret == nil then
            return nil, tostring(err)
        end
        return ret
    ]], {1, 'box.space.test:insert', {{1, cnt, label}}})

    if ret == nil then
        log.error('CNT %d: %s', cnt, err)
        table.insert(g.insertions_failed, {cnt = cnt, err = err})
    else
        table.insert(g.insertions_passed, ret)
    end
    return true
end

local highload_cnt = 0
local function highload_loop(label)
    fiber.name('test.highload')
    log.warn('Highload started ----------')
    while true do
        highload_cnt = highload_cnt + 1
        local ok, err = errors.pcall('E', _insert, highload_cnt, label)
        if ok == nil then
            log.error('CNT %d: %s', highload_cnt, err)
        end
        fiber.sleep(0.001)
    end
end

g.after_each(function()
    if g.highload_fiber ~= nil
    and g.highload_fiber:status() == 'suspended'
    then
        g.highload_fiber:cancel()
    end

    log.warn(
        'Total insertions: %d (%d good, %d failed)',
        highload_cnt, #g.insertions_passed, #g.insertions_failed
    )
    for _, e in ipairs(g.insertions_failed) do
        log.error('#%d: %s', e.cnt, e.err)
    end
end)

function g.test_router()
    g.highload_fiber = fiber.new(highload_loop, 'A')

    g.cluster:retrying({}, function()
        t.assert_equals(
            g.insertions_passed[#g.insertions_passed][3],
            'A', 'No workload for label A'
        )
    end)

    reload(g.R1)

    local cnt = #g.insertions_passed
    g.cluster:retrying({}, function()
        assert(#g.insertions_passed > cnt)
    end)

    g.highload_fiber:cancel()

    t.assert_equals(
        g.R1.net_box:call(
            'package.loaded.vshard.router.callrw',
            {1, 'box.space.test:select'}
        ),
        g.insertions_passed
    )

    -- t.assert_equals(g.insertions_failed, {})
end


function g.test_storage()
    g.highload_fiber = fiber.new(highload_loop, 'B')

    g.cluster:retrying({}, function()
        t.assert_equals(
            g.insertions_passed[#g.insertions_passed][3],
            'B', 'No workload for label B'
        )
    end)

    reload(g.SA1)
    -- require('fiber').sleep(1)
    -- do return end

    local cnt = #g.insertions_passed
    if not pcall(g.cluster.retrying, g.cluster, {timeout = 1}, function()
        helpers.assert_ge(#g.insertions_passed, cnt+1)
    end) then g.highload_fiber:cancel() fiber.sleep(10000) end

    g.highload_fiber:cancel()

    t.assert_equals(
        g.R1.net_box:call(
            'package.loaded.vshard.router.callrw',
            {1, 'box.space.test:select'}
        ),
        g.insertions_passed
    )

    t.assert_equals(g.insertions_failed, {})

end
