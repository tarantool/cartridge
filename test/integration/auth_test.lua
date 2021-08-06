local fio = require('fio')
local t = require('luatest')
local g = t.group()

local digest = require('digest')
local log = require('log')

local helpers = require('test.helper')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
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
                    }, {
                        alias = 'replica',
                        instance_uuid = helpers.uuid('a', 'a', 2),
                        http_port = 8082,
                        advertise_port = 13302,
                    }
                },
            },
        },
    })
    g.cluster:start()

    g.server = helpers.Server:new({
        workdir = fio.pathjoin(g.cluster.datadir, 'dummy'),
        alias = 'dummy',
        command = helpers.entrypoint('srv_basic'),
        replicaset_uuid = helpers.uuid('b'),
        instance_uuid = helpers.uuid('b', 'b', 1),
        http_port = 8083,
        cluster_cookie = 'cluster-cookies-for-the-cluster-monster',
        advertise_port = 13303,
        env = {
            ['TARANTOOL_AUTH_ENABLED'] = 'true'
        }
    })
    g.server:start()

    g.server_user = 'admin'
    local auth_b64 = digest.base64_encode(
        g.server_user .. ':' .. g.server.cluster_cookie
    )

    t.helpers.retrying({timeout = 5}, function()
        g.server:graphql(
            {query = '{ servers { uri } }'},
            {http = {headers = {authorization = 'Basic ' .. auth_b64}}}
        )
    end)
end

g.after_all = function()
    g.cluster:stop()
    g.server:stop()
    fio.rmtree(g.cluster.datadir)
end

g.setup = function()
    g.cluster.main_server:eval([[
        local cartridge = require('cartridge')
        local ok, err = cartridge.config_patch_clusterwide({users_acl = box.NULL})
        assert(ok, err)
    ]])
end

local function set_auth_enabled_internal(cluster, enabled)
    cluster.main_server:eval([[
        local log = require('log')
        local auth = require('cartridge.auth')
        local enabled = ...
        auth.set_params({enabled = enabled})
        if enabled then
            log.info('Auth enabled')
        else
            log.info('Auth disabled')
        end
    ]], {enabled})
end

local function check_401(server, kv_args)
    local unauthorized = function()
        server:graphql({query = '{ servers { uri } }'}, {http = kv_args})
    end
    t.assert_error_msg_contains("Unauthorized", unauthorized)
end

local function check_200(server, kv_args)
    server:graphql({query = '{ servers { uri } }'}, {http = kv_args})
end

local function get_lsid_max_age(resp)
    local cookie = resp.cookies['lsid']
    local max_age_part = cookie[2][2]
    local max_age = max_age_part:split('=')[2]
    return tonumber(max_age)
end

local function _login(server, username, password)
    local auth_data = string.format("username=%s&password=%s", username, password)
    local res = server:http_request('post', '/login', {body = auth_data, raise = false})
    return res
end

local function _remove_user(server, username)
    server:eval([[
        local auth = require('cartridge.auth')
        local res, err = auth.remove_user(...)
        assert(res, tostring(err))
    ]], {username})
end

local function _add_user(server, username, password, fullname)
    server:eval([[
        local auth = require('cartridge.auth')
        local res, err = auth.add_user(...)
        assert(res, tostring(err))
    ]], {username, password, fullname})
end

local function _edit_user(server, username, password, fullname)
    server:eval([[
        local auth = require('cartridge.auth')
        local res, err = auth.edit_user(...)
        assert(res, tostring(err))
    ]], {username, password, fullname})
end

local function _test_login(alias, auth)
    set_auth_enabled_internal(g.cluster, auth)
    local server = g.cluster:server(alias)
    local USERNAME = 'Ptarmigan'
    local PASSWORD = 'Fuschia Copper'

    if not auth then
        USERNAME = 'Sparrow'
        PASSWORD = 'Green Zinc'
    end

    _add_user(server, USERNAME, PASSWORD)


    t.assert_equals(_login(server, USERNAME, 'Invalid Password').status, 403)
    t.assert_equals(_login(server, 'Invalid Username', PASSWORD).status, 403)
    t.assert_equals(_login(server, nil, PASSWORD).status, 403)
    t.assert_equals(_login(server, USERNAME, nil).status, 403)
    t.assert_equals(_login(server, nil, nil).status, 403)

    if auth then
        check_401(server)
    else
        check_200(server)
    end

    local resp = _login(server, USERNAME, PASSWORD)
    t.assert_equals(resp.status, 200)
    t.assert_not_equals(resp.cookies['lsid'], nil)
    local lsid = resp.cookies['lsid'][1]
    t.assert_not_equals(lsid, '')

    local resp = server:http_request('post', '/logout',
        {http = {headers = {cookie = 'lsid=' .. lsid}}}
    )
    t.assert_equals(resp.status, 200)
    t.assert_equals(resp.cookies['lsid'][1], '""')

    local OLD_PASSWORD = PASSWORD
    local NEW_PASSWORD = 'Teal Bronze'
    _edit_user(server, USERNAME, NEW_PASSWORD)

    t.assert_equals(_login(server, USERNAME, OLD_PASSWORD).status, 403)
    local resp = _login(server, USERNAME, NEW_PASSWORD)
    t.assert_equals(resp.status, 200)
    t.assert_not_equals(resp.cookies['lsid'], nil)
    t.assert_not_equals(resp.cookies['lsid'][1], '')

    _remove_user(server, USERNAME)
    t.assert_equals(_login(server, USERNAME, OLD_PASSWORD).status, 403)
    t.assert_equals(_login(server, USERNAME, NEW_PASSWORD).status, 403)

    if auth then
        local USERNAME = "SuperPuperUser"
        local PASSWORD = "SuperPuperPassword-@3"
        _add_user(server, USERNAME, PASSWORD)

        local resp = _login(server, USERNAME, PASSWORD)
        t.assert_equals(resp.status, 200)
        t.assert_not_equals(resp.cookies['lsid'], nil)
        t.assert_not_equals(resp.cookies['lsid'], '')
        local cookie_lsid = 'lsid=' .. resp.cookies['lsid'][1]

        local request = [[
            mutation($username: String!) {
                cluster {
                    remove_user(username:$username) { username }
                }
            }
        ]]

        local function remove_self()
            server:graphql({
                query = request,
                variables = {username = USERNAME}
            },
            {http = {headers = {cookie = cookie_lsid}}})
        end
        t.assert_error_msg_contains("user can not remove himself", remove_self)

        local function remove_admin()
            server:graphql({
                query = request,
                variables = {username = 'admin'}
            },
            {http = {headers = {cookie = cookie_lsid}}})
        end
        t.assert_error_msg_contains(
            "remove_user() can't delete integrated superuser 'admin'",
            remove_admin
        )

        t.assert_equals(_login(server, USERNAME, PASSWORD).status,200)

        _remove_user(server, USERNAME)
        t.assert_equals(_login(server, USERNAME, PASSWORD).status, 403)
    end
end

function g.test_login_master_auth_enabled()
    _test_login('master', true)
end

function g.test_login_master_auth_disabled()
    _test_login('master', false)
end

function g.test_login_replica_auth_enabled()
    _test_login('replica', true)
end

function g.test_login_replica_auth_disabled()
    _test_login('replica', false)
end

function g.test_empty_list()
    set_auth_enabled_internal(g.cluster, false)
    local res = g.cluster.main_server:graphql({query = [[{
            cluster {
                users { username }
            }
        }]]
    })

    t.assert_equals(res['data']['cluster']['users'], {{['username'] = "admin"}})
end

function g.test_auth_disabled()
    set_auth_enabled_internal(g.cluster, false)
    local server = g.cluster.main_server
    local USERNAME1 = 'Duckling'
    local PASSWORD1 = 'Red Nickel'
    local USERNAME2 = 'Grouse'
    local PASSWORD2 = 'Silver Copper'
    local FULLNAME2 = 'Vladimir Mayakovsky'
    check_200(server)

    local function add_user(vars)
        return server:graphql({query = [[
            mutation(
                $username: String!
                $password: String!
                $fullname: String
                $email: String
            ) {
                cluster {
                    add_user(
                        username:$username
                        password:$password
                        fullname:$fullname
                        email:$email
                    ) { username fullname }
                }
            }]],
            variables = vars
        })['data']['cluster']['add_user']
    end

    t.assert_equals(
        add_user({
            username = USERNAME1,
            password = PASSWORD1,
        }),
        { username = USERNAME1, fullname = box.NULL }
    )

    t.assert_equals(
        add_user({
            username = USERNAME2,
            password = PASSWORD2,
            fullname = FULLNAME2,
            email = 'tester@tarantool.org'
        }),
        { username = USERNAME2, fullname = FULLNAME2 }
    )

    t.assert_error_msg_contains(
        string.format("User already exists: '%s'",  USERNAME1),
        add_user, {username = USERNAME1, password = PASSWORD1}
    )

    t.assert_error_msg_contains(
        "E-mail already in use: 'TeStEr@tarantool.org'",
        add_user,
        {
            username = USERNAME1 .. ' clone',
            password = PASSWORD1,
            email = 'TeStEr@tarantool.org'
        }
    )

    local function get_users(vars)
        return server:graphql({query = [[
            query($username: String) {
                cluster {
                    users(username: $username) { username }
                }
            }]],
            variables = vars
        })['data']['cluster']['users']
    end

    local user_list = get_users({username = USERNAME1})
    t.assert_equals(#user_list, 1)
    t.assert_equals(user_list[1]['username'], USERNAME1)

    local user_list = get_users({username = USERNAME2})
    t.assert_equals(#user_list, 1)
    t.assert_equals(user_list[1]['username'], USERNAME2)

    t.assert_error_msg_contains(
        "User not found: 'Invalid Username'",
        get_users, {username = 'Invalid Username'}
    )

    t.assert_equals(#get_users(), 3)

    local function edit_user(vars)
        return server:graphql({query = [[
            mutation($username: String! $email: String) {
                cluster {
                    edit_user(username:$username email:$email) { username email }
                }
            }]],
            variables = vars
        })['data']['cluster']['edit_user']['email']
    end

    local EMAIL1 = string.format('%s@tarantool.io', USERNAME1:lower())
    t.assert_equals(
        edit_user({
            username = USERNAME1,
            email = EMAIL1
        }), EMAIL1
    )

    -- Check that editing self email (to the same) won't raise error
    t.assert_equals(
        edit_user({
            username = USERNAME1,
            email = EMAIL1
        }), EMAIL1
    )

    -- Check that editing email (on existing) won't raise error
    EMAIL1 = 'prefix' .. EMAIL1
    t.assert_equals(
        edit_user({
            username = USERNAME1,
            email = EMAIL1
        }), EMAIL1
    )

    t.assert_error_msg_contains(
        string.format("E-mail already in use: '%s'", EMAIL1),
        edit_user, {
            username = USERNAME2,
            email = EMAIL1
        }
    )

    t.assert_error_msg_contains(
        "User not found: 'Invalid Username'",
        edit_user, {username = 'Invalid Username'}
    )

    local function remove_user(vars)
        return server:graphql({query = [[
            mutation($username: String!) {
                cluster {
                    remove_user(username:$username) { username }
                }
            }]],
            variables = vars
        })['data']['cluster']['remove_user']['username']
    end

    t.assert_equals(
        remove_user({username = USERNAME2}),
        USERNAME2
    )

    t.assert_error_msg_contains(
        "User not found: 'Invalid Username'",
        remove_user, {username = 'Invalid Username'}
    )

    local request = [[{
        cluster {
            auth_params {
                enabled
                username
            }
        }
    }]]

    local res  = server:graphql({query = request})
    local auth_params = res['data']['cluster']['auth_params']
    t.assert_equals(auth_params['enabled'], false)
    t.assert_equals(auth_params['username'], box.NULL)

    local lsid = _login(server, USERNAME1, PASSWORD1).cookies['lsid'][1]
    local cookie_lsid = 'lsid=' .. lsid
    local res = server:graphql(
        {query = request},
        {http = {headers = {cookie = cookie_lsid}}}
    )

    local auth_params = res['data']['cluster']['auth_params']
    t.assert_equals(auth_params['enabled'], false)
    t.assert_equals(auth_params['username'], USERNAME1)

    local request = [[
        mutation {
            cluster {
                auth_params(enabled: true) { enabled }
            }
        }
    ]]

    local function invalid_enabling_auth()
        server:graphql({query = request})
    end
    t.assert_error_msg_contains(
        'You must log in to enable authentication',
        invalid_enabling_auth
    )

    local res = server:graphql(
        {query = request},
        {http = {headers = {cookie = cookie_lsid}}}
    )
    local auth_params = res['data']['cluster']['auth_params']
    t.assert_equals(auth_params['enabled'], true)
end

function g.test_auth_enabled()
    set_auth_enabled_internal(g.cluster, true)
    local server = g.cluster.main_server
    local USERNAME = 'Gander'
    local PASSWORD = 'Black Lead'
    _add_user(server, USERNAME, PASSWORD)

    local lsid = _login(server, USERNAME, PASSWORD).cookies['lsid'][1]
    local cookie_lsid = 'lsid=' .. lsid
    check_401(server, {headers = {cookie = 'lsid=AA=='}})
    check_401(server, {headers = {cookie = 'lsid=!!'}})
    check_401(server, {headers = {cookie = 'lsid='}})
    check_200(server, {headers = {cookie = cookie_lsid}})
end

function g.test_uninitialized()
    local USERNAME = g.server_user
    local PASSWORD = g.server.cluster_cookie

    local resp = _login(g.server, USERNAME, PASSWORD)
    log.info('login successful')
    t.assert_equals(resp.status, 200)
    t.assert_not_equals(resp.cookies['lsid'], nil)

    local lsid = resp.cookies['lsid'][1]
    check_401(g.server, {headers = {cookie = 'lsid='}})
    check_200(g.server, {headers = {cookie = 'lsid=' .. lsid}})

    t.assert_error_msg_contains(
        "PatchClusterwideError: Current instance isn't bootstrapped yet",
        _add_user, g.server, 'new_admin', 'password'
    )

    t.assert_error_msg_contains(
        "edit_user() can't change integrated superuser 'admin'",
        _edit_user, g.server, g.server_user, 'password11'
    )
end

function g.test_keepalive()
    set_auth_enabled_internal(g.cluster, false)
    local server = g.cluster:server('master')
    local USERNAME = 'Crow'
    local PASSWORD = 'Teal Lead'
    _add_user(server, USERNAME, PASSWORD)

    local function get_username(session)
        return server:graphql({query = [[{
            cluster {
                auth_params { enabled username }
            }}]]},
            {http = {headers = session}}
        )['data']['cluster']['auth_params'].username
    end

    t.assert_equals(get_username(), box.NULL)

    local resp = _login(server, USERNAME, PASSWORD)
    t.assert_equals(resp.status, 200)

    local cookie_lsid = 'lsid=' .. resp.cookies['lsid'][1]
    local session = {cookie = cookie_lsid}
    t.assert_equals(get_username(session), USERNAME)

    local resp = server:http_request('post', '/logout', {
        http = {headers = session}
    })
    t.assert_equals(resp.status, 200)

    local cookie_lsid = 'lsid=' .. resp.cookies['lsid'][1]
    local session = {cookie = cookie_lsid}
    t.assert_equals(get_username(session), box.NULL)
end

function g.test_basic_auth()
    set_auth_enabled_internal(g.cluster, true)
    local server = g.cluster:server('master')
    _add_user(server, 'U', 'P')

    local function _b64(s)
        return digest.base64_encode(s)
    end

    local function _h(args)
        return {authorization = table.concat(args, ' ')}
    end

    check_401(server, {headers = _h({'Basic', _b64('U')})} )
    check_401(server, {headers = _h({'Basic', _b64('U:')})} )
    check_401(server, {headers = _h({'Basic', _b64(':P')})} )
    check_401(server, {headers = _h({'Basic', _b64(':U:P')})} )
    check_401(server, {headers = _h({'Basic', _b64('U:P:')})} )
    check_401(server, {headers = _h({'Basic', _b64(':U:P:')})} )
    check_401(server, {headers = _h({'Basic', _b64('U:P:C')})} )
    check_401(server, {headers = _h({'Basic', _b64('U'), _b64('P')})} )

    check_401(server, {headers = _h({'Basic', _b64('x:x')})} )
    check_401(server, {headers = _h({'Basic', _b64('x:P')})} )
    check_401(server, {headers = _h({'Basic', _b64('U:x')})} )
    check_401(server, {headers = _h({'Weird', _b64('U:P')})} )

    check_200(server, {headers = _h({'Basic', _b64('U:P')})} )
end


function g.test_set_params_graphql()
    set_auth_enabled_internal(g.cluster, false)
    local server = g.cluster:server('master')
    local USERNAME = 'Heron'
    local PASSWORD = 'Silver Titanium'
    local FULLNAME = 'Hermann Hesse'
    _add_user(server, USERNAME, PASSWORD)

    local resp = _login(server, USERNAME, PASSWORD)
    local lsid = resp.cookies['lsid']
    local cookie_lsid = 'lsid=' .. lsid[1]

    local function get_auth_params(server)
        return server:graphql({query = [[{
                cluster {
                    auth_params {
                        username
                        enabled
                        cookie_max_age
                    }
                }
            }]]}, {
                http = {headers = {cookie = cookie_lsid}}
            }
        )['data']['cluster']['auth_params']
    end

    local function set_auth_params(enabled, cookie_max_age)
        return g.cluster.main_server:graphql({query = [[
            mutation(
                $enabled: Boolean
                $cookie_max_age: Long
            ) {
                cluster {
                    auth_params(
                        enabled: $enabled
                        cookie_max_age: $cookie_max_age
                    ){
                        enabled
                        cookie_max_age
                    }
                }
            }]],
            variables = {
                enabled = enabled,
                cookie_max_age = cookie_max_age,
            }},
            {http = {headers = {cookie = cookie_lsid}}}
        )['data']['cluster']['auth_params']
    end

    t.assert_equals(
        get_auth_params(g.cluster:server('master'))['cookie_max_age'],
        get_lsid_max_age(resp)
    )

    t.assert_equals(
        set_auth_params(false)['enabled'],
        false
    )
    t.assert_equals(
        set_auth_params(nil)['enabled'],
        false
    )
    t.assert_equals(
        get_auth_params(g.cluster:server('replica'))['enabled'],
        false
    )
    t.assert_equals(
        set_auth_params(true)['enabled'],
        true
    )
    t.assert_equals(
        set_auth_params(nil)['enabled'],
        true
    )
    t.assert_equals(get_auth_params(
        g.cluster:server('replica'))['enabled'],
        true
    )

    t.assert_equals(
        set_auth_params(nil, 69)['cookie_max_age'],
        69
    )
    t.assert_equals(
        set_auth_params(nil, nil)['cookie_max_age'],
        69
    )
    t.assert_equals(
        get_auth_params(g.cluster:server('replica'))['cookie_max_age'],
        69
    )
    t.assert_equals(
        get_auth_params(g.cluster:server('master'))['username'],
        USERNAME
    )
    _edit_user(server, USERNAME, nil, FULLNAME)
    t.assert_equals(
        get_auth_params(g.cluster:server('master'))['username'],
        FULLNAME
    )
    t.assert_equals(
        get_auth_params(g.cluster:server('replica'))['username'],
        FULLNAME
    )

    local function login(alias)
        return _login(g.cluster:server(alias), USERNAME, PASSWORD)
    end

    t.assert_equals(
        get_lsid_max_age(login('master')),
        69
    )
    t.assert_equals(
        get_lsid_max_age(login('replica')),
        69
    )
end

function g.test_cookie_renew()
    local USERNAME = 'Eagle'
    local PASSWORD = 'Yellow Zinc'
    local server = g.cluster:server('master')
    _add_user(server, USERNAME, PASSWORD)

    local lsid = _login(server, USERNAME, PASSWORD).cookies['lsid'][1]
    local cookie_lsid = 'lsid=' .. lsid
    server:graphql({query = [[
        mutation {
            cluster {
                auth_params(cookie_renew_age: 0) { enabled }
            }
        }]]},
        {http = {headers = {cookie = cookie_lsid}}}
    )

    local resp = server:http_request('get', '/admin/config',
        {http = {headers = {cookie = cookie_lsid}}}
    )
    t.assert_equals(resp.status, 200)
    t.assert_not_equals(resp.cookies['lsid'], nil)
    t.assert_not_equals(resp.cookies['lsid'][1], '')
    t.assert_not_equals(resp.cookies['lsid'][1], lsid)
end

function g.test_cookie_expiry()
    set_auth_enabled_internal(g.cluster, false)
    local server = g.cluster:server('master')
    local USERNAME = 'Hen'
    local PASSWORD = 'White Platinum'
    _add_user(server, USERNAME, PASSWORD)

    local lsid = _login(server, USERNAME, PASSWORD).cookies['lsid'][1]
    local cookie_lsid = 'lsid=' .. lsid

    local function set_max_age(max_age)
        return server:graphql({query = [[
            mutation($max_age: Long) {
                cluster {
                    auth_params(cookie_max_age: $max_age) { enabled }
                }
            }]],
            variables = {max_age = max_age}
        })
    end

    local function get_username()
        return server:graphql({query = [[{
            cluster {
                auth_params {
                    username
                }}}]]
            }, {
                http = {headers = {cookie = cookie_lsid}}
            }
        )['data']['cluster']['auth_params']['username']
    end

    set_max_age(0)
    t.assert_equals(get_username(), box.NULL)

    local resp = server:http_request('get', '/admin/config',
        {http = {headers = {cookie = cookie_lsid}}}
    )
    t.assert_equals(get_lsid_max_age(resp), 0)

    set_max_age(3600)
    t.assert_equals(get_username(), USERNAME)
end

function g.test_invalidate_cookie_on_password_change()
    local USERNAME = 'Niles Rumfoord'
    local PASSWORD = 'Beatrice'
    local server = g.cluster:server('master')
    set_auth_enabled_internal(g.cluster, true)
    _add_user(server, USERNAME, PASSWORD)

    local resp = _login(server, USERNAME, PASSWORD)
    log.info('login successful')
    t.assert_equals(resp.status, 200)
    t.assert_not_equals(resp.cookies['lsid'], nil)
    local lsid = resp.cookies['lsid'][1]
    local cookie_lsid = 'lsid=' .. lsid
    check_200(server, {headers = {cookie = cookie_lsid}})

    local NEW_PASSWORD = 'Salo'
    _edit_user(server, USERNAME, NEW_PASSWORD)
    check_401(server, {headers = {cookie = cookie_lsid}})

    resp = _login(server, USERNAME, NEW_PASSWORD)
    log.info('login successful')
    t.assert_equals(resp.status, 200)
    t.assert_not_equals(resp.cookies['lsid'], nil)
    lsid = resp.cookies['lsid'][1]
    cookie_lsid = 'lsid=' .. lsid
    check_200(server, {headers = {cookie = cookie_lsid}})

    local function edit_user(cookie, vars)
        return server:http_request('post', '/admin/api', {
            http = {headers = {cookie = cookie}},
            json = {
                query = [[
                mutation($username:String! $password:String) {
                    cluster {
                        edit_user(username:$username password:$password) { username }
                    }
                }]],
                variables = vars,
            },
            raise = false,
        })
    end

    local resp = edit_user(cookie_lsid, {username = USERNAME, password = PASSWORD})
    local cookie = resp.headers['set-cookie']
    check_200(server, {headers = {cookie = cookie}})
end
