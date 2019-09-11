local fio = require('fio')
local t = require('luatest')
local g = t.group('admin')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')
local httpcli = require('http.client')
local json = require('json')
local digest = require('digest')

local username = 'admin'
local password = '12345'

local function bauth(username, password)
    local auth_data = string.format("%s:%s", username, password)
    local b64_data = digest.base64_encode(auth_data)
    return {authorization = 'Basic ' .. b64_data}
end

g.before_all = function()
    g.client = httpcli.new()
    g.server = helpers.Server:new({
        alias = 'master',
        workdir = fio.tempdir(),
        command = fio.pathjoin(test_helper.root, 'test', 'integration', 'srv_woauth.lua'),
        advertise_port = 33001,
        http_port = 8081,
        cluster_cookie = 'super-cluster-cookie',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        env = {
            TARANTOOL_AUTH_ENABLED   = 'true',
            TARANTOOL_CLUSTER_COOKIE =  password
        }
    })
    g.client.server_addr = 'http://localhost:' .. g.server.http_port
    g.server:start()
    t.helpers.retrying({}, function()
        g.server:graphql({
                query = '{}'
            }, {
                http = {headers = bauth(username, password)}
            })
    end)
end

g.after_all = function()
    g.server:stop()
    fio.rmtree(g.server.workdir)
end

local function login(client, username, password)
    local auth_data = string.format("username=%s&password=%s", username, password)
    local res = client:post(client.server_addr .. '/login', auth_data)
    return res
end

local function check_401(server, data)
    local graphql_fn_call = function(data)
        server:graphql({
            query = '{}'
        }, {
            http = {headers = data}
        })
    end
    t.assert_error_msg_contains('Unauthorized', graphql_fn_call, data)
end

local function check_200(server, data)
    local resp = server:graphql({
            query = '{}'
        }, {
            http = {headers = data}
        }
    )
    t.assert_nil(resp['errors'])
end


local function add_user(server, uname, passwd)
    return server:graphql({
            query = [[
                mutation($username: String! $password: String!) {
                    cluster {
                        add_user(username:$username password:$password) { username }
                    }
                }
            ]],
            variables = {username = uname, password = passwd}
        }, {
            http = {headers = bauth(username, password)}
        })
end

local function edit_user(server, uname, passwd)
    return g.server:graphql({
            query = [[
                mutation($username: String! $password: String!) {
                    cluster {
                        edit_user(username:$username password:$password) { username }
                    }
                }
            ]],
            variables={username = uname, password = passwd}
        }, {
            http = {headers = bauth(username, password)}
        })
end

local function list_users(server, uname)
    return g.server:graphql({
        query = [[
            query($username: String) {
                cluster {
                    users(username: $username) { username }
                }
            }
        ]],
        variables = {username = uname}
    }, {
        http = {headers = bauth(username, password)}
    })
end


function g.test_api()
    local resp = g.server:graphql({
            query = [[
            {
                cluster {
                    auth_params {
                        enabled
                        username
                    }
                }
            }
        ]]}, {
            http = {headers = bauth(username, password)}
        })

    t.assert_nil(resp['errors'])

    local auth_params = resp['data']['cluster']['auth_params']
    t.assert_true(auth_params['enabled'])
    t.assert_equals(auth_params['username'], username)

    -- Cheks add_user
    local expected_msg = string.format(
        "add_user() can\'t override integrated superuser '%s'", username
    )
    t.assert_error_msg_contains(
        expected_msg,
        add_user, g.server, username, 'qwerty'
    )

    t.assert_error_msg_contains(
        'add_user() callback isn\'t set',
        add_user, g.server, 'guest', 'qwerty'
    )

    -- checks edit_user
    local expected_msg = string.format(
        "edit_user() can't change integrated superuser '%s'", username
    )
    t.assert_error_msg_contains(
        expected_msg,
        edit_user, g.server, username, 'qwerty'
    )

    t.assert_error_msg_contains(
        "edit_user() callback isn't set",
        edit_user, g.server, 'guest', qwerty
    )

    -- checks list_users
    local resp = list_users(g.server, nil)
    t.assert_equals(resp['data']['cluster']['users'], {{username = username}})

    local resp = list_users(g.server, username)
    t.assert_nil(resp['errors'])
    t.assert_equals(resp['data']['cluster']['users'], {{username = username}})

    t.assert_error_msg_contains(
        "get_user() callback isn't set",
        list_users, g.server, 'guest'
    )
end

function g.test_login()
    t.assert_equals(login(g.client, username, 'Invalid Password')['status'], 403)
    t.assert_equals(login(g.client, 'Invalid Username', password)['status'], 403)
    t.assert_equals(login(g.client, nil, password)['status'], 403)
    t.assert_equals(login(g.client, username, nil)['status'], 403)
    t.assert_equals(login(g.client, nil, nil)['status'], 403)

    check_401(g.server)

    local resp = login(g.client, username, password)
    t.assert_equals(resp['status'], 200)
    t.assert_not_nil(resp['cookies']['lsid'][1])
    t.assert_not_equals(resp['cookies']['lsid'][1], '')
    local lsid = resp['cookies']['lsid'][1]

    check_401(g.server, {cookie = "lsid=AA=="})
    check_401(g.server, {cookie = "lsid=!!"})
    check_401(g.server, {cookie = "lsid"}) -- ???
    check_200(g.server, {cookie = "lsid=" .. lsid})

    -- Check basic auth
    check_401(g.server, bauth(username, '000000'))
    check_401(g.server, bauth('guest',  password))
    check_200(g.server, bauth(username, password))
end
