local fio = require('fio')
local t = require('luatest')
local g = t.group('config')

local yaml = require('yaml')
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
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_upload_good()
    g.cluster.main_server.net_box:eval([[
        local auth = require('cartridge.auth')
        local res, err = auth.add_user(...)
        assert(res, tostring(err))
    ]], {'guest', 'guest'})

    local upload_config = function(config)
        g.cluster.main_server:http_request('put', '/admin/config', {
            body = yaml.encode(config)
        })
    end

    local custom_config = {
        ['custom_config'] = {
            ['Ultimate Question of Life, the Universe, and Everything'] = 42
        }
    }
    upload_config(custom_config)

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

    local resp = g.cluster.main_server:http_request('get', '/admin/config')
    local config = yaml.decode(resp.body)
    t.assert_equals(config, custom_config)

    local other_config = {
        ['other_config'] = {
            ['How many engineers does it take to change a light bulb'] = 1
        }
    }
    upload_config(other_config)

    local resp = g.cluster.main_server:http_request('get', '/admin/config')
    local config = yaml.decode(resp.body)
    t.assert_nil(config.custom_config)
    t.assert_equals(config, other_config)
end

function g.test_upload_fail()
    local system_sections = {
        'topology',
        'vshard', 'vshard_groups',
        'auth', 'users_acl'
    }

    local server = g.cluster.main_server
    for _, section in ipairs(system_sections) do
        local resp = server:http_request('put', '/admin/config', {
            body = json.encode({[section] = {}}),
            raw = true
        })
        t.assert_equals(resp.status, 400)
        t.assert_equals(resp.json['class_name'], 'Config upload failed')
        t.assert_equals(resp.json['err'],
            string.format('uploading system section "%s" is forbidden', section)
        )
    end

    local resp = server:http_request('put', '/admin/config', {body = ',', raw = true})
    t.assert_equals(resp.status, 400)
    t.assert_equals(resp.json['class_name'], 'Decoding YAML failed')
    t.assert_equals(resp.json['err'], 'unexpected END event')

    local resp = server:http_request('put', '/admin/config', {body = 'Lorem ipsum dolor', raw = true})
    t.assert_equals(resp.status, 400)
    t.assert_equals(resp.json['class_name'], 'Config upload failed')
    t.assert_equals(resp.json['err'], 'Config must be a table')
end
