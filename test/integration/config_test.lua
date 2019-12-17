local fio = require('fio')
local t = require('luatest')
local g = t.group('config')

local json = require('json')
local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = test_helper.server_command,
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {},
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

    -- Make sure auth section exists in clusterwide config.
    -- It shouldn't be available for downloading via HTTP API
    g.cluster.main_server.net_box:eval([[
        local auth = require('cartridge.auth')
        local res, err = auth.add_user(...)
        assert(res, tostring(err))
    ]], {'guest', 'guest'})
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

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

function g.test_upload_good()
    local custom_config = {
        ['custom_config'] = {
            ['Ultimate Question of Life, the Universe, and Everything'] = 42
        }
    }
    g.cluster:upload_config(custom_config)
    g.cluster:upload_config({['custom_config.yml'] = '{spoiled: true}'})
    g.cluster:upload_config(custom_config)

    g.cluster.main_server.net_box:eval([[
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

local M = {}
local function test_remotely(fn_name, fn)
    M[fn_name] = fn
    g[fn_name] = function()
        g.cluster.main_server.net_box:eval([[
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
    t.assert_equals(err.class_name, 'LoadConfigError')
    t.assert_equals(err.err, 'Ambiguous sections "data" and "data.yml"')
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
    t.assert_equals(err.class_name, 'LoadConfigError')
    t.assert_equals(err.err, 'Ambiguous sections "data" and "data.yml"')
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
    t.assert_equals(err.class_name, 'PatchClusterwideError')
    t.assert_equals(err.err, 'Ambiguous sections "conflict" and "conflict.yml"')
end)



return M
