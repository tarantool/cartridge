local fio = require('fio')

local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')


local function init_remote_funcs(servers, fn_names, fn_body)
    for _, server in pairs(servers) do
        for _, fn_name in ipairs(fn_names) do
            local eval_str = ('%s = %s'):format(fn_name, fn_body)
            server.net_box:eval(eval_str)
        end
    end
end

local function cleanup_log_data()
    g.s1.net_box:eval([[
        _G.__log_warn = {}
        _G.__log_error = {}
    ]])
end

local function call_twophase(server, arg)
    return server.net_box:eval(
        "return require('cartridge.twophase').twophase_commit(...)", {arg}
    )
end


g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
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

    g.s1.net_box:eval([[
        _G.__log_warn = {}
        _G.__log_error = {}
        package.loaded['log'].warn = function(...) table.insert(_G.__log_warn, string.format(...)) end
        package.loaded['log'].error = function(...) table.insert(_G.__log_error, string.format(...)) end
    ]])
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

g.before_each(function()
    init_remote_funcs(g.cluster.servers, g.two_phase_funcs, g.simple_stage_func_good)
    cleanup_log_data()
end)


function g.test_twophase_badness()
    local twophase_args = {
        uri_list = {uri1 = 'localhost:13301'},
        fn_prepare = '_G.undefined'
    }
    t.assert_error_msg_contains(
        'bad argument opts.fn_abort to nil (string expected, got nil)',
        call_twophase, g.s1, twophase_args
    )

    twophase_args.fn_commit = '_G.undefined'
    twophase_args.fn_abort = '_G.undefined'
    t.assert_error_msg_contains(
        'bad argument opts.uri_list to twophase_commit' ..
        ' (contiguous array of strings expected)',
        call_twophase, g.s1, twophase_args
    )

    twophase_args.uri_list = {'localhost:13301'}
    local ok, err = call_twophase(g.s1, twophase_args)
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'NetboxCallError',
        err = [["localhost:13301": Procedure '_G.undefined' is not defined]],
    })
end

function g.test_twophase_ok()
    g.s1.net_box:eval('_G.__prepare = function(data) assert(data == nil) return true end')

    local twophase_args = {
        fn_prepare = '_G.__prepare',
        fn_abort = '_G.__abort',
        fn_commit = '_G.__commit',
        uri_list = {'localhost:13301', 'localhost:13302'}
    }

    local expeced_log_res = {
        "(2PC) Preparation stage...",
        "Prepared for twophase_commit at localhost:13301",
        "Prepared for twophase_commit at localhost:13302",
        "(2PC) Commit stage...",
        "Committed twophase_commit at localhost:13301",
        "Committed twophase_commit at localhost:13302",
    }

    local ok, err = call_twophase(g.s1, twophase_args)
    t.assert_equals(ok, true)
    t.assert_equals(err, nil)
    t.assert_equals(g.s1.net_box:eval('return _G.__log_error'), {})
    t.assert_equals(g.s1.net_box:eval('return _G.__log_warn'), expeced_log_res)


    -- check activity name changes log output
    cleanup_log_data()
    twophase_args.activity_name = 'simple_twophase'
    for i, _ in ipairs(expeced_log_res) do
        expeced_log_res[i] = (expeced_log_res[i]):gsub(
            'twophase_commit', twophase_args.activity_name
        )
    end

    local ok, err = call_twophase(g.s1, twophase_args)
    t.assert_equals(ok, true)
    t.assert_equals(err, nil)
    t.assert_equals(g.s1.net_box:eval('return _G.__log_error'), {})
    t.assert_equals(g.s1.net_box:eval('return _G.__log_warn'), expeced_log_res)


    -- check upload works
    cleanup_log_data()
    g.s1.net_box:eval('_G.__prepare = function(data) assert(data ~= nil) return true end')
    twophase_args.upload_data = 'something'
    table.insert(expeced_log_res, 1, '(2PC) Upload stage...')

    local ok, err = call_twophase(g.s1, twophase_args)
    t.assert_equals(ok, true)
    t.assert_equals(err, nil)
    t.assert_equals(g.s1.net_box:eval('return _G.__log_error'), {})
    t.assert_equals(g.s1.net_box:eval('return _G.__log_warn'), expeced_log_res)
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
        class_name = 'Err', err = '"localhost:13302": Error occured'
    })
    t.assert_items_include(g.s1.net_box:eval('return _G.__log_warn'),{
        'Aborted simple_twophase at localhost:13301'
    })
    local error_log = g.s1.net_box:eval('return _G.__log_error')
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
    t.assert_items_include(g.s1.net_box:eval('return _G.__log_warn'),{
        'Committed simple_twophase at localhost:13301'
    })
    local error_log = g.s1.net_box:eval('return _G.__log_error')
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
    local error_log = g.s1.net_box:eval('return _G.__log_error')
    t.assert_str_contains(error_log[1],
        'Error preparing for simple_twophase at localhost:13302'
    )
    t.assert_str_contains(error_log[2],
        'Error aborting simple_twophase at localhost:13301'
    )
end
