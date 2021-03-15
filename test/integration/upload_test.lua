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
            roles = {'myrole-permanent'},
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

    local future = g.s1.net_box:call(
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
    t.assert_covers(err, {
        class_name = 'NetboxCallError',
        err = 'Timeout exceeded',
    })

    -- prefix should be cleaned up even if upload_begin fails
    t.assert_equals(fio.listdir(g.upload_path_1), {})
    t.assert_equals(fio.listdir(g.upload_path_2), {})

    g.s2.process:kill('CONT')
    -- give the instance some time to wake up after stop
    fiber.sleep(0.3)

    t.assert_equals(fio.listdir(g.upload_path_1), {})
    t.assert_equals(fio.listdir(g.upload_path_2), {})
end

function g.test_transmission_failure()
    g.s3.net_box:eval([[
        _G.upload_transmit_original = _G.__cartridge_upload_transmit
        _G.__cartridge_upload_transmit = function()
            require('fiber').sleep(0.3)
            error('Artificial transmission failure', 0)
        end
    ]])

    local future = g.s1.net_box:call(
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
        err = 'Artificial transmission failure',
    })

    -- prefix should be cleaned up even if upload_transmit fails
    t.assert_equals(fio.listdir(g.upload_path_1), {})
    t.assert_equals(fio.listdir(g.upload_path_2), {})

    -- Revert all hacks
    g.s3.net_box:eval([[
        _G.__cartridge_upload_transmit = _G.upload_transmit_original
    ]])
end

function g.test_finish_failure()
    g.s1.net_box:eval([[
        local twophase_vars = require('cartridge.vars').new('cartridge.twophase')
        twophase_vars.options.netbox_call_timeout = 0.1
        _G.upload_finish_original = _G.__cartridge_upload_finish
        _G.__cartridge_upload_finish = function()
            require('fiber').sleep(0.3)
            return _G.upload_finish_original
        end
    ]])

    local future = g.s1.net_box:call(
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
        err = 'Upload not found, see earlier logs for the details',
    })

    -- prefix should be cleaned up even if upload_transmit fails
    t.assert_equals(fio.listdir(g.upload_path_1), {})
    t.assert_equals(fio.listdir(g.upload_path_2), {})

    -- Revert all hacks
    g.s1.net_box:eval([[
        local twophase_vars = require('cartridge.vars').new('cartridge.twophase')
        twophase_vars.options.netbox_call_timeout = 0.1
        _G.__cartridge_upload_finish = _G.upload_finish_original
    ]])
end

function g.test_unchanged_config()
    -- s2 will think that every prepared_config has no changes
    g.s2.net_box:eval([[
        _G.old_commit_2pc = _G.__cartridge_clusterwide_config_commit_2pc
        _G.__cartridge_clusterwide_config_commit_2pc = function()
            local vars = require('cartridge.vars').new('cartridge.twophase')
            local confapplier = require('cartridge.confapplier')
            vars.prepared_config = confapplier.get_active_config()
            return _G.old_commit_2pc()
        end
    ]])

    local function config_version()
        local res = {}
        local q_get_version = [[
            local confapplier = require('cartridge.confapplier')
            local config = confapplier.get_active_config()
            return config:get_readonly()['version.txt']
        ]]
        res.s1 = g.s1.net_box:eval(q_get_version)
        res.s2 = g.s2.net_box:eval(q_get_version)
        res.s3 = g.s3.net_box:eval(q_get_version)
        return res
    end

    local function new_version(version)
        local result, err = g.s1.net_box:call(
            'package.loaded.cartridge.config_patch_clusterwide',
            {{['version.txt'] = version}}
        )
        t.assert_equals(err, nil)
        t.assert_equals(result, true)
    end

    -- s2 will not apply 'unchanged' config.
    -- However it is ok for s1 and s3.
    new_version('1')
    t.assert_covers(config_version(), {s1 = '1', s2 = box.NULL, s3 = '1'})

    -- Trigger OperationError on s3. That means that apply_config can't be
    -- skipped even if config is unchanged.
    g.s3.net_box:eval([[
        package.loaded['mymodule-permanent'].apply_config = function()
            error('Artificial Error', 0)
        end
    ]])
    local function force_reapply(uuids)
        return g.cluster.main_server:graphql({
            query = [[mutation($uuids: [String]) {
                cluster { config_force_reapply(uuids: $uuids) }
            }]],
            variables = {uuids = uuids}
        })
    end
    t.assert_error_msg_equals(
        'Artificial Error',
        force_reapply, {g.s3.instance_uuid}
    )
    helpers.wish_state(g.s3, 'OperationError')

    -- Fix s2 and s3. s2 will recognize previous config as new. It is unchanged
    -- for others. But s3's state is OperationError thus config will be
    -- reapplied.
    g.s1.net_box:eval([[
        package.loaded['mymodule-permanent'].apply_config = function()
            error('Should not be called', 0)
        end
    ]])
    g.s2.net_box:eval([[
        _G.__cartridge_clusterwide_config_commit_2pc = _G.old_commit_2pc
        _G.old_commit_2pc = nil
    ]])
    g.s3.net_box:eval([[
        package.loaded['mymodule-permanent'].apply_config = nil
    ]])

    new_version('1')
    t.assert_covers(config_version(), {s1 = '1', s2 = '1', s3 = '1'})
    helpers.wish_state(g.s3, 'RolesConfigured')


    g.s1.net_box:eval([[
        package.loaded['mymodule-permanent'].apply_config = nil
    ]])
    new_version('2')
    t.assert_covers(config_version(), {s1 = '2', s2 = '2', s3 = '2'})
end
