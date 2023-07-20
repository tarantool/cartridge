local fio = require('fio')

local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')


local function init_remote_funcs(servers, fn_names, fn_body)
    for _, server in pairs(servers) do
        for _, fn_name in ipairs(fn_names) do
            local eval_str = ('%s = %s'):format(fn_name, fn_body)
            server:eval(eval_str)
        end
    end
end

local function cleanup_log_data()
    g.s1:eval([[
        _G.__log_warn = {}
        _G.__log_error = {}
    ]])
end

local function call_twophase(server, arg)
    return server:eval([[
        local twophase = require('cartridge.twophase')
        return twophase.twophase_commit(...)
    ]], {arg})
end


g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_loghack'),
        cookie = helpers.random_cookie(),
        replicasets = {{
            alias = 'main',
            roles = {},
            servers = 2
        }}
    })
    g.cluster:start()

    g.s1 = g.cluster:server('main-1')
    g.s2 = g.cluster:server('main-2')

    g.two_phase_funcs = {'_G.__prepare', '_G.__abort', '_G.__commit'}
    g.simple_stage_func_good = [[function(data) return true end]]
    g.simple_stage_func_bad = [[function()
        return nil, require('errors').new('Err', 'Error occured')
    end]]
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

g.before_each(function()
    init_remote_funcs(g.cluster.servers, g.two_phase_funcs, g.simple_stage_func_good)
    cleanup_log_data()
end)


function g.test_errors()
    t.assert_error_msg_contains(
        'bad argument opts.fn_abort to nil' ..
        ' (string expected, got nil)',
        call_twophase, g.s1, {
            uri_list = {},
            fn_prepare = '_G.undefined',
            fn_commit = '_G.undefined',
            fn_abort = nil,
        }
    )

    t.assert_error_msg_contains(
        'bad argument opts.fn_commit to nil' ..
        ' (string expected, got nil)',
        call_twophase, g.s1, {
            uri_list = {},
            fn_prepare = '_G.undefined',
            fn_commit = nil,
            fn_abort = '_G.undefined',
        }
    )

    t.assert_error_msg_contains(
        'bad argument opts.fn_prepare to nil' ..
        ' (string expected, got nil)',
        call_twophase, g.s1, {
            uri_list = {},
            fn_prepare = nil,
            fn_commit = '_G.undefined',
            fn_abort = '_G.undefined',
        }
    )

    t.assert_error_msg_contains(
        'bad argument opts.uri_list to twophase_commit' ..
        ' (contiguous array of strings expected)',
        call_twophase, g.s1, {
            uri_list = {k = 'v'},
            fn_prepare = '_G.undefined',
            fn_commit = '_G.undefined',
            fn_abort = '_G.undefined',
        }
    )

    t.assert_error_msg_contains(
        'bad argument opts.uri_list to twophase_commit' ..
        ' (duplicates are prohibited)',
        call_twophase, g.s1, {
            uri_list = {'localhost:13301', 'localhost:13301'},
            fn_prepare = '_G.undefined',
            fn_commit = '_G.undefined',
            fn_abort = '_G.undefined',
        }
    )

    local ok, err = call_twophase(g.s1, {
        uri_list = {'localhost:13301'},
        fn_prepare = '_G.undefined',
        fn_commit = '_G.undefined',
        fn_abort = '_G.undefined',
    })
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'NetboxCallError',
        err = [["localhost:13301": Procedure '_G.undefined' is not defined]],
    })
end

function g.test_success()
    local ok, err = call_twophase(g.s1, {
        uri_list = {'localhost:13302'},
        fn_prepare = '_G.__prepare',
        fn_commit = '_G.__commit',
        fn_abort = '_G.__abort',
        upload_data = {'xyz'},
    })
    t.assert_equals({ok, err}, {true, nil})
    t.assert_equals(g.s1:eval('return _G.__log_error'), {})
    t.assert_equals(g.s1:eval('return _G.__log_warn'), {
        "(2PC) twophase_commit upload phase...",
        "(2PC) twophase_commit prepare phase...",
        "Prepared for twophase_commit at localhost:13302",
        "(2PC) twophase_commit commit phase...",
        "Committed twophase_commit at localhost:13302",
    })

    local function get_inbox()
        local upload = require('cartridge.upload')
        local _, data = next(upload.inbox)
        table.clear(upload.inbox)
        return data
    end
    t.assert_equals(helpers.run_remotely(g.s1, get_inbox), nil)
    t.assert_equals(helpers.run_remotely(g.s2, get_inbox), {'xyz'})
end

function g.test_upload_skipped()
    g.s1:eval([[
        _G.__prepare = function(data)
            assert(data == nil)
            return true
        end
    ]])

    local ok, err = call_twophase(g.s1, {
        activity_name = 'my_2pc',
        uri_list = {'localhost:13301', 'localhost:13302'},
        fn_prepare = '_G.__prepare',
        fn_commit = '_G.__commit',
        fn_abort = '_G.__abort',
    })
    t.assert_equals({ok, err}, {true, nil})
    t.assert_equals(g.s1:eval('return _G.__log_error'), {})
    t.assert_equals(g.s1:eval('return _G.__log_warn'), {
        "(2PC) my_2pc prepare phase...",
        "Prepared for my_2pc at localhost:13301",
        "Prepared for my_2pc at localhost:13302",
        "(2PC) my_2pc commit phase...",
        "Committed my_2pc at localhost:13301",
        "Committed my_2pc at localhost:13302",
    })
end

function g.test_prepare_fails()
    local twophase_args = {
        fn_prepare = '_G.__prepare',
        fn_abort = '_G.__abort',
        fn_commit = '_G.__commit',
        uri_list = {'localhost:13301', 'localhost:13302'},
        activity_name = 'simple_twophase'
    }

    init_remote_funcs({g.s2}, {'_G.__prepare'}, g.simple_stage_func_bad)
    local ok, err = call_twophase(g.s1, twophase_args)
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'Err',
        err = '"localhost:13302": Error occured',
    })
    t.assert_items_include(g.s1:eval('return _G.__log_warn'), {
        'Aborted simple_twophase at localhost:13301'
    })
    local error_log = g.s1:eval('return _G.__log_error')
    t.assert_str_contains(error_log[1],
        'Error preparing for simple_twophase at localhost:13302'
    )
end

function g.test_commit_fails()
    local twophase_args = {
        fn_prepare = '_G.__prepare',
        fn_abort = '_G.__abort',
        fn_commit = '_G.__commit',
        uri_list = {'localhost:13301', 'localhost:13302'},
        activity_name = 'simple_twophase'
    }

    init_remote_funcs({g.s2}, {'_G.__commit'}, g.simple_stage_func_bad)
    local ok, err = call_twophase(g.s1, twophase_args)
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'Err', err = '"localhost:13302": Error occured'
    })
    t.assert_items_include(g.s1:eval('return _G.__log_warn'),{
        'Committed simple_twophase at localhost:13301'
    })
    local error_log = g.s1:eval('return _G.__log_error')
    t.assert_str_contains(error_log[1],
        'Error committing simple_twophase at localhost:13302'
    )
end

function g.test_abort_fails()
    local twophase_args = {
        fn_prepare = '_G.__prepare',
        fn_abort = '_G.__abort',
        fn_commit = '_G.__commit',
        uri_list = {'localhost:13301', 'localhost:13302'},
        activity_name = 'simple_twophase'
    }

    init_remote_funcs({g.s2}, {'_G.__prepare'}, g.simple_stage_func_bad)
    init_remote_funcs({g.s1}, {'_G.__abort'}, g.simple_stage_func_bad)
    local ok, err = call_twophase(g.s1, twophase_args)
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'Err', err = '"localhost:13302": Error occured'
    })
    local error_log = g.s1:eval('return _G.__log_error')
    t.assert_str_contains(error_log[1],
        'Error preparing for simple_twophase at localhost:13302'
    )
    t.assert_str_contains(error_log[2],
        'Error aborting simple_twophase at localhost:13301'
    )
end

function g.test_timeouts()
    g.s1:exec(function()
        local t = require('luatest')
        local twophase = require('cartridge.twophase')

        twophase.set_netbox_call_timeout(222)
        t.assert_equals(twophase.get_netbox_call_timeout(), 222)

        twophase.set_upload_config_timeout(123)
        t.assert_equals(twophase.get_upload_config_timeout(), 123)

        twophase.set_validate_config_timeout(654)
        t.assert_equals(twophase.get_validate_config_timeout(), 654)

        twophase.set_apply_config_timeout(111)
        t.assert_equals(twophase.get_apply_config_timeout(), 111)
    end)
end

function g.test_2pc_is_locked()
    g.s1:exec(function()
        local t = require('luatest')
        local twophase = require('cartridge.twophase')
        twophase.set_validate_config_timeout(0.8)
        local _, err = twophase.patch_clusterwide({})
        twophase.set_validate_config_timeout(10) -- default
        _, err = twophase.patch_clusterwide({})
        t.assert_not(err)
    end)
end
