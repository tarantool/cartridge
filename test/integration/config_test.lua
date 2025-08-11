local fio = require('fio')
local t = require('luatest')
local g = t.group()

local json = require('json')
local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'myrole-permanent', 'vshard-router'},
                servers = {
                    {
                        alias = 'master',
                        instance_uuid = helpers.uuid('a', 'a', 1),
                        http_port = 8081,
                        advertise_port = 13301,
                    }
                },
            },
        },
    })
    g.cluster:start()

    -- Disable on_patch_trigger for the ddl-manager role
    g.cluster.main_server.net_box:eval([[
        require('cartridge.twophase').on_patch(nil,
            _G._cluster_vars_values
            ['cartridge.roles.ddl-manager']
            .on_patch_trigger
        )
    ]])

    -- Make sure auth section exists in clusterwide config.
    -- It shouldn't be available for downloading via HTTP API
    g.cluster.main_server:eval([[
        local auth = require('cartridge.auth')
        local res, err = auth.add_user(...)
        assert(res, tostring(err))
    ]], {'guest', 'guest'})

    g.cluster.main_server:eval([[
        local mymodule = package.loaded['mymodule-permanent']
        mymodule.validate_config = function(conf)
            if conf.throw then
                error('Config rejected: ' .. conf.throw, 0)
            end
            return true
        end
    ]])
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

local function set_sections(sections)
    return g.cluster.main_server:graphql({query = [[
        mutation($sections: [ConfigSectionInput!]) {
            cluster {
                config(sections: $sections) {
                    filename
                    content
                }
            }
        }]],
        variables = {sections = sections}
    }).data.cluster.config
end

local function get_sections(sections)
    return g.cluster.main_server:graphql({query = [[
        query($sections: [String!]) {
            cluster {
                config(sections: $sections) {
                    filename
                    content
                }
            }
        }]],
        variables = {sections = sections}
    }).data.cluster.config
end

local function validate_config(sections)
    return g.cluster.main_server:graphql({query = [[
        query($sections: [ConfigSectionInput!]) {
            cluster {
                validate_config(sections: $sections) {
                    error
                }
            }
        }]],
        variables = {sections = sections}
    }).data.cluster.validate_config.error
end

function g.test_upload_good()
    local custom_config = {
        ['custom_config'] = {
            ['Ultimate Question of Life, the Universe, and Everything'] = 42
        }
    }
    g.cluster:upload_config(custom_config)
    g.cluster:upload_config({['custom_config.yml'] = '{spoiled: true}'})
    g.cluster:upload_config(custom_config)

    g.cluster.main_server:eval([[
        local confapplier = package.loaded['cartridge.confapplier']

        local custom_config = confapplier.get_readonly('custom_config')
        local _, answer = next(custom_config)
        assert(answer == 42, 'Answer ~= 42')

        local auth = confapplier.get_readonly('auth')
        assert(auth ~= nil, 'Missing auth config section')

        local users_acl = confapplier.get_readonly('users_acl')
        assert(users_acl ~= nil, 'Missing users_acl config section')
        local _, userdata = next(users_acl)
        assert(userdata ~= nil)
        assert(userdata.username == 'guest')
    ]])

    local config = g.cluster:download_config()
    t.assert_equals(config, custom_config)

    local other_config = {
        ['other_config'] = {
            ['How many engineers does it take to change a light bulb'] = 1
        }
    }
    g.cluster:upload_config(other_config)
    local config = g.cluster:download_config()
    t.assert_equals(config.custom_config, nil)
    t.assert_equals(config, other_config)

    local function _list(sections)
        local ret = {}
        for _, v in ipairs(sections) do
            table.insert(ret, v.filename)
        end
        return ret
    end

    t.assert_items_equals(
        _list(get_sections()),
        {'other_config.yml'}
    )

    t.assert_equals(
        set_sections({{filename = 'mod.txt', content = '%)'}}),
        {{filename = 'mod.txt', content = '%)'}}
    )

    t.assert_items_equals(_list(get_sections()), {'mod.txt', 'other_config.yml'})
    t.assert_items_equals(_list(get_sections({})), {})
    t.assert_items_equals(_list(get_sections({'mod.txt'})), {'mod.txt'})
    t.assert_items_equals(_list(get_sections({'other_config.yml'})), {'other_config.yml'})
    t.assert_equals(get_sections({'other_config'}), {})
    t.assert_equals(get_sections({'unknown.yml'}), {})

    t.assert_equals(
        set_sections({{filename = 'other_config.yml', content = box.NULL}}),
        {}
    )
    t.assert_equals(
        get_sections(),
        {{filename = 'mod.txt', content = '%)'}}
    )
end

function g.test_upload_fail()
    local system_sections = {
        'auth',
        'auth.yml',
        'topology',
        'topology.yml',
        'users_acl',
        'users_acl.yml',
        'vshard',
        'vshard.yml',
        'vshard_groups',
        'vshard_groups.yml',
    }

    local server = g.cluster.main_server
    for _, section in ipairs(system_sections) do
        local resp = server:http_request('put', '/admin/config', {
            body = json.encode({[section] = {}}),
            raise = false
        })
        t.assert_equals(resp.status, 400)
        t.assert_equals(resp.json['class_name'], 'Config upload failed')
        t.assert_equals(resp.json['err'],
            string.format('uploading system section "%s" is forbidden', section)
        )

        t.assert_error_msg_contains(
            string.format('uploading system section %q is forbidden', section),
            set_sections, {{filename = section, content = 'test'}}
        )
    end

    local resp = server:http_request('put', '/admin/config', {body = ',', raise = false})
    t.assert_equals(resp.status, 400)
    t.assert_equals(resp.json['class_name'], 'DecodeYamlError')
    t.assert_equals(resp.json['err'], 'unexpected END event')

    local resp = server:http_request('put', '/admin/config',
        {body = 'Lorem ipsum dolor', raise = false}
    )
    t.assert_equals(resp.status, 400)
    t.assert_equals(resp.json['class_name'], 'Config upload failed')
    t.assert_equals(resp.json['err'], 'Config must be a table')

    local function check_err(body)
        local resp = server:http_request('put', '/admin/config',
            {body = body, raise = false}
        )
        t.assert_equals(resp.status, 400)
        t.assert_equals(resp.json['class_name'], 'Config upload failed')
        t.assert_equals(resp.json['err'],
            'ambiguous sections "conflict" and "conflict.yml"'
        )
    end

    check_err([[
        conflict: "one"
        conflict.yml: "two"
    ]])
    check_err([[
        conflict: "one"
        conflict.yml: null
    ]])
    check_err([[
        conflict: null
        conflict.yml: null
    ]])
end

g.before_test('test_validate', function()
    g.cluster.main_server:eval([[
        local mymodule = package.loaded['mymodule-permanent']
        _G._apply_config = mymodule.apply_config
        mymodule.apply_config = function(conf)
            if conf.boom == 'Kaboom!' then
                error('Config rejected: ' .. conf.boom, 0)
            end
            return true
        end

        local hidden = package.loaded['mymodule-hidden']
        hidden.validate_config = function()
            error('Validation shouldn\'t be called because this role isn\'t enabled')
        end
    ]])
end)

function g.test_validate()
    local function run_validations()
        local content = "['a', 'b', {c: \"d\"}] ###"
        t.assert_equals(
            validate_config({{filename = 'test.yml', content = content}}),
            box.NULL
        )

        -- ddl validation
        t.assert_equals(
            validate_config({{filename = 'schema.yml', content = '42'}}),
            "Invalid schema (table expected, got number)"
        )
        t.assert_equals(
            validate_config({{filename = 'schema.yml', content = '{}'}}),
            "spaces: must be a table, got nil"
        )
        t.assert_equals(
            validate_config({{filename = 'schema.yml', content = 'spaces: false'}}),
            "spaces: must be a table, got boolean"
        )

        -- topology validation
        t.assert_equals(
            validate_config({{filename = 'topology.yml', content = 'servers: {}'}}),
            "Current instance \"localhost:13301\" is not listed in config"
        )

        -- vshard validation
        t.assert_equals(
            validate_config({{filename = 'vshard_groups.yml', content = 'vhsard_groups:'}}),
            "section vshard_groups[\"vhsard_groups\"] must be a table"
        )

        -- confapplier validation
        t.assert_equals(
            validate_config({{filename = 'throw', content = 'Go away'}}),
            "Config rejected: Go away"
        )
    end

    -- RolesConfigured
    run_validations()

    -- Drive instance into OperationError state.
    -- Still validation should be called only for enabled roles.
    t.assert_error_msg_contains(
        "Config rejected: Kaboom!",
        function()
            set_sections({{filename = 'boom', content = 'Kaboom!'}})
        end
    )
    local state = g.cluster.main_server:eval([[
        return require('cartridge.confapplier').get_state()
    ]])
    t.assert_equals(state, 'OperationError')

    -- OperationError
    run_validations()
end

g.after_test('test_validate', function()
    set_sections({{filename = 'boom', content = 'Nope'}})
    local state = g.cluster.main_server:eval([[
        return require('cartridge.confapplier').get_state()
    ]])
    t.assert_equals(state, 'RolesConfigured')

    g.cluster.main_server:eval([[
        local mymodule = package.loaded['mymodule-permanent']
        mymodule.apply_config = _G._apply_config
        _G._apply_config = nil

        hidden = package.loaded['mymodule-hidden']
        hidden.validate_config = nil
    ]])
end)

function g.test_rollback()
    -- hack utils to throw error on file_write
    g.cluster.main_server:eval([[
        local utils = package.loaded["cartridge.utils"]
        local e_file_write = require('errors').new_class("Artificial error")
        _G._utils_file_write = utils.file_write
        utils.file_write = function(filename)
            return nil, e_file_write:new("Hacked from test")
        end
    ]])

    -- try to apply new config - it should fail
    t.assert_error_msg_contains('Hacked from test', function()
        g.cluster.main_server:graphql({query = [[
            mutation {
                cluster { failover(enabled: false) }
            }
        ]]})
    end)

    -- restore utils.file_write
    g.cluster.main_server:eval([[
        local utils = package.loaded["cartridge.utils"]
        utils.file_write = _G._utils_file_write
        _G._utils_file_write = nil
    ]])

    -- try to apply new config - now it should succeed
    g.cluster.main_server:graphql({query = [[
        mutation {
            cluster { failover(enabled: false) }
        }
    ]]})
end

function g.test_formatting()
    -- Cartridge shouldn't spoil yaml formatting
    -- https://github.com/tarantool/cartridge/issues/1075

    local srv = g.cluster.main_server
    srv:upload_config({['test'] = {
        {1, '2'},
        {true, 'false'},
        {box.NULL, 'null'},
        {a = {b = {}}},
    }})

    local lines = table.concat({
        "- - 1",
        "  - '2'",
        "- - true",
        "  - 'false'",
        "- - null",
        "  - 'null'",
        "- a:",
        "    b: []",
        ""
    }, '\n')

    t.assert_equals(
        get_sections({'test.yml'})[1].content,
        '---\n' .. lines .. '...\n'
    )

    t.assert_equals(
        srv:http_request('get', '/admin/config').body,
        '---\n' .. 'test:\n' .. lines .. '...\n'
    )

    local content = "['a', 'b', {c: \"d\"}] ###"
    -- get/set_sections API preserves formatting
    set_sections({{filename = 'test.yml', content = content}})
    t.assert_equals(
        get_sections(),
        {{filename = 'test.yml', content = content}}
    )
    -- /admin/config re-renders it, but at least it should be pretty.
    t.assert_equals(
        srv:http_request('get', '/admin/config').body,
        table.concat({
            "---",
            "test:",
            "- a",
            "- b",
            "- c: d",
            "...",
            ""
        }, '\n')
    )
end

function g.test_on_patch_trigger()
    g.cluster.main_server:eval([[
        _G.__trigger = function(conf_new, conf_old)
            error(conf_new:get_readonly('e.txt'), 0)
        end

        require("cartridge.twophase").on_patch(__trigger)
    ]])

    t.assert_error_msg_contains('Boom!',
        set_sections, {{filename = 'e.txt', content = 'Boom!'}}
    )

    g.cluster.main_server:eval([[
        require("cartridge.twophase").on_patch(nil, __trigger)

        _G.__trigger = function(conf_new, conf_old)
            local txt = conf_new:get_readonly('i.txt')
            local i = tonumber(txt) or 0
            conf_new:set_plaintext('i.txt', tostring(i + 1))
        end

        require("cartridge.twophase").on_patch(__trigger)
        require("cartridge.twophase").on_patch(function(...)
            _G.__trigger(...)
            return 'nobody', 'checks', 'return', 'values'
        end)
    ]])

    t.assert_items_equals(
        set_sections({{filename = 'i.txt', content = ''}}),
        {{filename = 'i.txt', content = '2'}}
    )
    t.assert_items_equals(set_sections({}), {})
    t.assert_items_equals(
        get_sections({'i.txt'}),
        {{filename = 'i.txt', content = '4'}}
    )
end


local M = {}
local function test_remotely(fn_name, fn)
    M[fn_name] = fn
    g[fn_name] = function()
        g.cluster.main_server:eval([[
            local test = require('test.integration.config_test')
            test[...]()
        ]], {fn_name})
    end
end
test_remotely('test_patch_clusterwide', function()
    local cartridge = package.loaded['cartridge']
    local twophase = package.loaded['cartridge.twophase']
    local confapplier = package.loaded['cartridge.confapplier']
    t.assert_is(cartridge.config_get_readonly, confapplier.get_readonly)
    t.assert_is(cartridge.config_get_deepcopy, confapplier.get_deepcopy)
    t.assert_is(cartridge.config_patch_clusterwide, twophase.patch_clusterwide)
    local _patch = cartridge.config_patch_clusterwide
    local _get_ro = cartridge.config_get_readonly

    --------------------------------------------------------------------
    local ok, err = _patch({
        ['data'] = "friday",
    })
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    t.assert_equals(_get_ro('data'), 'friday')

    --------------------------------------------------------------------
    local ok, err = _patch({
        ['data'] = {today = "friday"},
    })
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    t.assert_equals(_get_ro('data'), {today = 'friday'})

    --------------------------------------------------------------------
    local ok, err = _patch({
        -- test that .yml extension isn't added twice
        ['data.yml'] = {tomorow = 'saturday'},
    })
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    t.assert_equals(_get_ro('data'), {tomorow = 'saturday'})

    local ok, err = _patch({
        ['data.yml'] = '{tomorow: saturday} # so excited',
    })
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    t.assert_equals(_get_ro('data'), {tomorow = 'saturday'})
    t.assert_equals(_get_ro('data.yml'), '{tomorow: saturday} # so excited')

    --------------------------------------------------------------------
    local ok, err = _patch({
        ['data'] = box.NULL,
    })
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    t.assert_equals(_get_ro('data'), nil)
    t.assert_equals(_get_ro('data.yml'), nil)

    --------------------------------------------------------------------
    local ok, err = _patch({
        ['data.yml'] = '{afterwards: sunday}',
    })
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    t.assert_equals(_get_ro('data'), {afterwards = 'sunday'})
    t.assert_equals(_get_ro('data.yml'), '{afterwards: sunday}')

    --------------------------------------------------------------------
    local ok, err = _patch({['data'] = "Fun, fun, fun, fun",})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'LoadConfigError',
        err = 'Ambiguous sections "data" and "data.yml"'
    })
    local ok, err = _patch({
        ['data'] = "Fun, fun, fun, fun",
        ['data.yml'] = box.NULL,
    })
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    t.assert_equals(_get_ro('data'), "Fun, fun, fun, fun")
    t.assert_equals(_get_ro('data.yml'), nil)

    --------------------------------------------------------------------
    local ok, err = _patch({['data.yml'] = "---\nWeekend\n...",})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'LoadConfigError',
        err = 'Ambiguous sections "data" and "data.yml"'
    })
    local ok, err = _patch({
        ['data'] = box.NULL,
        ['data.yml'] = "---\nWeekend\n...",
    })
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    t.assert_equals(_get_ro('data'), "Weekend")
    t.assert_equals(_get_ro('data.yml'), "---\nWeekend\n...")

    --------------------------------------------------------------------
    local ok, err = _patch({
        ['conflict'] = {},
        ['conflict.yml'] = "xxx",
    })
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'PatchConfigError',
        err = 'Ambiguous sections "conflict" and "conflict.yml"',
    })
end)



return M
