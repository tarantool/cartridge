local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')
local digest = require('digest')

local ADMIN_USERNAME = 'admin'
local ADMIN_FULLNAME = 'Cartridge Administrator'
local ADMIN_PASSWORD = '12345'

local function bauth(username, password)
    local auth_data = string.format("%s:%s", username, password)
    local b64_data = digest.base64_encode(auth_data)
    return {authorization = 'Basic ' .. b64_data}
end

g.before_all = function()
    g.server = helpers.Server:new({
        alias = 'master',
        workdir = fio.tempdir(),
        command = helpers.entrypoint('srv_basic'),
        advertise_port = 13301,
        http_port = 8081,
        cluster_cookie = ADMIN_PASSWORD,
        instance_uuid = helpers.uuid('a', 'a', 1),
        replicaset_uuid = helpers.uuid('a'),
        env = {
            TARANTOOL_AUTH_ENABLED   = 'true',
        }
    })
    g.server:start()
    t.helpers.retrying({}, function()
        g.server:graphql({
            query = '{ servers { uri } }'
        }, {
            http = {headers = bauth(ADMIN_USERNAME, ADMIN_PASSWORD)}
        })
    end)
end

g.after_all = function()
    g.server:stop()
    fio.rmtree(g.server.workdir)
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
            http = {headers = bauth(ADMIN_USERNAME, ADMIN_PASSWORD)}
        })

    local auth_params = resp['data']['cluster']['auth_params']
    t.assert_equals(auth_params['enabled'], true)
    t.assert_equals(auth_params['username'], ADMIN_FULLNAME)

    local add_user = function(username, password)
        return g.server:graphql({
                query = [[
                    mutation($username: String! $password: String!) {
                        cluster {
                            add_user(username:$username password:$password) { username }
                        }
                    }
                ]],
                variables = {username = username, password = password}
            }, {
                http = {headers = bauth(ADMIN_USERNAME, ADMIN_PASSWORD)}
            })
    end

    t.assert_error_msg_contains(
        "add_user() can't override integrated superuser",
        add_user, ADMIN_USERNAME, 'qwerty'
    )

    t.assert_error_msg_contains(
        "Current instance isn't bootstrapped yet",
        add_user, 'guest', 'qwerty'
    )

    local edit_user = function(username, password)
        return g.server:graphql({
                query = [[
                    mutation($username: String! $password: String!) {
                        cluster {
                            edit_user(username:$username password:$password) { username }
                        }
                    }
                ]],
                variables={username = username, password = password}
            }, {
                http = {headers = bauth(ADMIN_USERNAME, ADMIN_PASSWORD)}
            })
    end

    t.assert_error_msg_contains(
        "edit_user() can't change integrated superuser",
        edit_user, ADMIN_USERNAME, 'qwerty'
    )

    t.assert_error_msg_contains(
        "User not found: 'guest'",
        edit_user, 'guest', 'qwerty'
    )

    local list_users = function(username)
        return g.server:graphql({
            query = [[
                query($username: String) {
                    cluster {
                        users(username: $username) { username }
                    }
                }
            ]],
            variables = {username = username}
        }, {
            http = {headers = bauth(ADMIN_USERNAME, ADMIN_PASSWORD)}
        })
    end

    local resp = list_users(nil)
    t.assert_equals(resp['data']['cluster']['users'], {{username = ADMIN_USERNAME}})

    local resp = list_users(ADMIN_USERNAME)
    t.assert_equals(resp['data']['cluster']['users'], {{username = ADMIN_USERNAME}})

    t.assert_error_msg_contains(
        "User not found: 'guest'",
        list_users, 'guest'
    )
end

function g.test_login()
    local login = function(username, password)
        local auth_data = string.format("username=%s&password=%s", username, password)
        local res = g.server:http_request('post', '/login', {body = auth_data, raise = false})
        return res
    end

    t.assert_equals(login(ADMIN_USERNAME, 'Invalid Password')['status'], 403)
    t.assert_equals(login('Invalid Username', ADMIN_PASSWORD)['status'], 403)
    t.assert_equals(login(nil, ADMIN_PASSWORD)['status'], 403)
    t.assert_equals(login(ADMIN_USERNAME, nil)['status'], 403)
    t.assert_equals(login(nil, nil)['status'], 403)

    local check_200 = function(data)
        g.server:graphql({
                query = '{ servers { uri } }'
            }, {
                http = {headers = data}
            })
    end

    local check_401 = function(data)
        local graphql_fn_call = function(data)
            g.server:graphql({
                query = '{ servers { uri } }'
            }, {
                http = {headers = data}
            })
        end
        t.assert_error_msg_contains('Unauthorized', graphql_fn_call, data)
    end

    check_401()

    local resp = login(ADMIN_USERNAME, ADMIN_PASSWORD)
    t.assert_equals(resp['status'], 200)
    t.assert(resp['cookies']['lsid'][1])
    t.assert_not_equals(resp['cookies']['lsid'][1], '')
    local lsid = resp['cookies']['lsid'][1]

    check_401({cookie = "lsid=AA=="})
    check_401({cookie = "lsid=!!"})
    check_401({cookie = "lsid"})
    check_200({cookie = "lsid=" .. lsid})

    -- Check basic auth
    check_401(bauth(ADMIN_USERNAME, '000000'))
    check_401(bauth('guest',  ADMIN_PASSWORD))
    check_200(bauth(ADMIN_USERNAME, ADMIN_PASSWORD))
end
