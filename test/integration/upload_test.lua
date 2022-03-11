local t = require('luatest')
local g = t.group()

local fio = require('fio')
local fiber = require('fiber')
local helpers = require('test.helper')

g.before_all(function()
    g.datadir = fio.tempdir()
    g.upload_path_1 = fio.pathjoin(g.datadir, 'upload-1')
    g.upload_path_2 = fio.pathjoin(g.datadir, 'upload-2')

    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {{
            alias = 'main',
            uuid = helpers.uuid('a'),
            roles = {},
            servers = {
                -- first upload group: s1 and s2
                {env = {TARANTOOL_UPLOAD_PREFIX = g.upload_path_1}},
                {env = {TARANTOOL_UPLOAD_PREFIX = g.upload_path_1}},
                -- second upload group: s3
                {env = {TARANTOOL_UPLOAD_PREFIX = g.upload_path_2}},
            },
        }},
    })
    g.cluster:start()

    g.s1 = g.cluster:server('main-1')
    g.s2 = g.cluster:server('main-2')
    g.s3 = g.cluster:server('main-3')

    -- This makes g.s1 to establish all pool connections.
    -- Without it the first begining_failure test (with a SIGSTOP) is
    -- slower and usually fails because the error message varies.
    helpers.list_cluster_issues(g.s1)
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_begining_failure()
    g.s2.process:kill('STOP')

    local future = g.s1:call(
        'package.loaded.cartridge.config_patch_clusterwide',
        {{['todo_list.txt'] = 'gotta go fast'}},
        {is_async = true}
    )

    t.helpers.retrying({}, function()
        t.assert(fio.listdir(g.upload_path_1)[1])
        t.assert(fio.listdir(g.upload_path_2)[1])
    end)

    local res, err = unpack(future:wait_result())
    t.assert_equals(res, nil)
    t.assert(helpers.is_timeout_error(err.err))

    -- prefix should be cleaned up even if upload_begin fails
    t.assert_equals(fio.listdir(g.upload_path_1), {})
    t.assert_equals(fio.listdir(g.upload_path_2), {})

    g.s2.process:kill('CONT')
    -- give the instance some time to wake up after stop
    fiber.sleep(0.3)

    t.assert_equals(fio.listdir(g.upload_path_1), {})
    t.assert_equals(fio.listdir(g.upload_path_2), {})
end

g.after_test('test_begining_failure', function()
    g.s2.process:kill('CONT')
end)

g.before_test('test_transmission_failure', function()
    g.s3:eval([[
        _G.upload_transmit_original = _G.__cartridge_upload_transmit
        _G.__cartridge_upload_transmit = function()
            require('fiber').sleep(0.3)
            error('Artificial transmission failure', 0)
        end
    ]])
end)

function g.test_transmission_failure()
    local future = g.s1:call(
        'package.loaded.cartridge.config_patch_clusterwide',
        {{['todo_list.txt'] = 'gotta go faster'}},
        {is_async = true}
    )

    t.helpers.retrying({}, function()
        t.assert(fio.listdir(g.upload_path_1)[1])
        t.assert(fio.listdir(g.upload_path_2)[1])
    end)

    local res, err = unpack(future:wait_result())
    t.assert_equals(res, nil)
    t.assert_covers(err, {
        class_name = 'NetboxCallError',
        err = '"localhost:13303": Artificial transmission failure',
    })

    -- prefix should be cleaned up even if upload_transmit fails
    t.assert_equals(fio.listdir(g.upload_path_1), {})
    t.assert_equals(fio.listdir(g.upload_path_2), {})
end

g.after_test('test_transmission_failure', function()
    -- Revert all hacks
    g.s3:eval([[
        _G.__cartridge_upload_transmit = _G.upload_transmit_original
    ]])
end)

g.before_test('test_finish_failure', function()
    g.s1:eval([[
        local twophase_vars = require('cartridge.vars').new('cartridge.twophase')
        twophase_vars.options.netbox_call_timeout = 0.1
        _G.upload_finish_original = _G.__cartridge_upload_finish
        _G.__cartridge_upload_finish = function()
            require('fiber').sleep(0.3)
            return _G.upload_finish_original
        end
    ]])
end)

function g.test_finish_failure()
    local future = g.s1:call(
        'package.loaded.cartridge.config_patch_clusterwide',
        {{['todo_list.txt'] =
            'The only problem with ' ..
            'being faster than light is ' ..
            'that you can only live in darkness.'
        }},
        {is_async = true}
    )

    t.helpers.retrying({}, function()
        t.assert(fio.listdir(g.upload_path_1)[1])
        t.assert(fio.listdir(g.upload_path_2)[1])
    end)

    local res, err = unpack(future:wait_result())
    t.assert_equals(res, nil)
    t.assert_covers(err, {
        class_name = 'Prepare2pcError',
        err = '"localhost:13301": Upload not found, see earlier logs for the details',
    })

    -- prefix should be cleaned up even if upload_transmit fails
    t.assert_equals(fio.listdir(g.upload_path_1), {})
    t.assert_equals(fio.listdir(g.upload_path_2), {})
end

g.after_test('test_finish_failure', function()
    -- Revert all hacks
    g.s1:eval([[
        local twophase_vars = require('cartridge.vars').new('cartridge.twophase')
        twophase_vars.options.netbox_call_timeout = 0.1
        _G.__cartridge_upload_finish = _G.upload_finish_original
    ]])
end)
