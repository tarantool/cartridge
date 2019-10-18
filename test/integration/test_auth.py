#!/usr/bin/env python3

import sys
import json
import pytest
import base64
import logging
import requests
if sys.version_info >= (3, 0):
    from http.cookies import SimpleCookie
else:
    from Cookie import SimpleCookie

from conftest import Server

cluster = [
    Server(
        alias = 'master',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = [],
        binary_port = 33001,
        http_port = 8081,
    ),
    Server(
        alias = 'replica',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000002',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = [],
        binary_port = 33002,
        http_port = 8082,
    )
]

def set_auth_enabled_internal(cluster, enabled):
    cluster['master'].conn.eval("""
        local log = require('log')
        local auth = require('cartridge.auth')
        local enabled = ...
        auth.set_params({enabled = enabled})
        if enabled then
            log.info('Auth enabled')
        else
            log.info('Auth disabled')
        end
    """, (enabled))

@pytest.fixture(scope="function")
def cleanup(cluster):
    cluster['master'].conn.eval("""
        local cartridge = require('cartridge')
        local ok, err = cartridge.config_patch_clusterwide({users_acl = box.NULL})
        assert(ok, err)
    """)


@pytest.fixture(scope="function")
def enable_auth(cluster):
    set_auth_enabled_internal(cluster, True)

@pytest.fixture(scope="function")
def disable_auth(cluster):
    set_auth_enabled_internal(cluster, False)

def _login(srv, username, password):
    return srv.post_raw('/login',
        data={'username': username, 'password': password}
    )

def check_401(srv, **kwargs):
    resp = srv.graphql('{}', **kwargs)
    assert resp['errors'][0]['message'] == "Unauthorized"


def check_200(srv, **kwargs):
    resp = srv.graphql('{}', **kwargs)
    assert 'errors' not in resp, resp['errors'][0]['message']


@pytest.mark.parametrize("auth", [True, False])
@pytest.mark.parametrize("alias", ['master', 'replica'])
def test_login(cluster, cleanup, auth, alias):
    srv = cluster[alias]
    set_auth_enabled_internal(cluster, auth)
    USERNAME = 'Ptarmigan' if auth else 'Sparrow'
    PASSWORD = 'Fuschia Copper' if auth else 'Green Zinc'

    srv.conn.eval("""
        local auth = require('cartridge.auth')
        local res, err = auth.add_user('{}', '{}')
        assert(res, tostring(err))
    """.format(USERNAME, PASSWORD))

    assert _login(srv, USERNAME, 'Invalid Password').status_code == 403
    assert _login(srv, 'Invalid Username', PASSWORD).status_code == 403
    assert _login(srv, None, PASSWORD).status_code == 403
    assert _login(srv, USERNAME, None).status_code == 403
    assert _login(srv, None, None).status_code == 403

    if auth:
        check_401(srv)
    else:
        check_200(srv)

    resp = _login(srv, USERNAME, PASSWORD)
    assert resp.status_code == 200, str(resp)
    assert 'lsid' in resp.cookies
    assert resp.cookies['lsid'] != ''
    lsid = resp.cookies['lsid']

    resp = srv.post_raw('/logout', cookies={'lsid': lsid})
    assert resp.status_code == 200
    assert 'lsid' not in resp.cookies

    OLD_PASSWORD = PASSWORD
    NEW_PASSWORD = 'Teal Bronze'
    del PASSWORD

    srv.conn.eval("""
        local auth = require('cartridge.auth')
        local res, err = auth.edit_user('{}', '{}')
        assert(res, tostring(err))
    """.format(USERNAME, NEW_PASSWORD))

    assert _login(srv, USERNAME, OLD_PASSWORD).status_code == 403
    resp = _login(srv, USERNAME, NEW_PASSWORD)
    assert resp.status_code == 200
    assert 'lsid' in resp.cookies
    assert resp.cookies['lsid'] != ''

    srv.conn.eval("""
        local auth = require('cartridge.auth')
        local res, err = auth.remove_user('{}')
        assert(res, tostring(err))
    """.format(USERNAME))
    assert _login(srv, USERNAME, OLD_PASSWORD).status_code == 403
    assert _login(srv, USERNAME, NEW_PASSWORD).status_code == 403

    if auth:
        USERNAME = "SuperPuperUser"
        PASSWORD = "SuperPuperPassword-@3"

        srv.conn.eval("""
            local auth = require('cartridge.auth')
            local res, err = auth.add_user('{}', '{}')
            assert(res, tostring(err))
        """.format(USERNAME, PASSWORD))

        resp = _login(srv, USERNAME, PASSWORD)
        assert resp.status_code == 200
        assert 'lsid' in resp.cookies
        assert resp.cookies['lsid'] != ''
        lsid = resp.cookies['lsid']

        req = """
            mutation($username: String!) {
                cluster {
                    remove_user(username:$username) { username }
                }
            }
        """

        assert srv.graphql(req,
            variables={ 'username': USERNAME },
            cookies={ 'lsid': lsid }
        )['errors'][0]['message'] == "user can not remove himself"

        assert srv.graphql(req,
            variables={ 'username': 'admin' },
            cookies={ 'lsid': lsid }
        )['errors'][0]['message'] == \
            "remove_user() can't delete integrated superuser 'admin'"

        assert _login(srv, USERNAME, PASSWORD).status_code == 200

        srv.conn.eval("""
            local auth = require('cartridge.auth')
            local res, err = auth.remove_user('{}')
            assert(res, tostring(err))
        """.format(USERNAME))
        assert _login(srv, USERNAME, PASSWORD).status_code == 403

def test_empty_list(cluster, cleanup):
    obj = cluster['master'].graphql("""
        query {
            cluster {
                users { username }
            }
        }
    """)
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['users'] == [{"username": "admin"}]

def test_auth_disabled(cluster, cleanup, disable_auth):
    srv = cluster['master']
    USERNAME1 = 'Duckling'
    PASSWORD1 = 'Red Nickel'
    USERNAME2 = 'Grouse'
    PASSWORD2 = 'Silver Copper'
    check_200(srv)

    req = """
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
                ) { username }
            }
        }
    """
    obj = srv.graphql(req, variables={
        'username': USERNAME1,
        'password': PASSWORD1
    })
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['add_user']['username'] == USERNAME1

    obj = srv.graphql(req, variables={
        'username': USERNAME2,
        'password': PASSWORD2,
        'fullname': USERNAME2,
        'email': 'tester@tarantool.org'
    })
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['add_user']['username'] == USERNAME2

    obj = srv.graphql(req, variables={
        'username': USERNAME1,
        'password': PASSWORD1
    })
    assert obj['errors'][0]['message'] == \
        "User already exists: '%s'" % USERNAME1

    obj = srv.graphql(req, variables={
        'username': USERNAME1 + ' clone',
        'password': PASSWORD1,
        'email': 'TeStEr@tarantool.org'
    })
    assert obj['errors'][0]['message'] == \
        "E-mail already in use: 'TeStEr@tarantool.org'"

    req = """
        query($username: String) {
            cluster {
                users(username: $username) { username }
            }
        }
    """

    obj = srv.graphql(req, variables={'username': USERNAME1})
    assert 'errors' not in obj, obj['errors'][0]['message']
    user_list = obj['data']['cluster']['users']
    assert len(user_list) == 1
    assert user_list[0]['username'] == USERNAME1

    obj = srv.graphql(req, variables={'username': USERNAME2})
    assert 'errors' not in obj, obj['errors'][0]['message']
    user_list = obj['data']['cluster']['users']
    assert len(user_list) == 1
    assert user_list[0]['username'] == USERNAME2

    obj = srv.graphql(req, variables={'username': 'Invalid Username'})
    assert obj['errors'][0]['message'] == \
        "User not found: 'Invalid Username'"

    obj = srv.graphql(req)
    assert len(obj['data']['cluster']['users']) == 3

    req = """
        mutation($username: String! $email: String) {
            cluster {
                edit_user(username:$username email:$email) { username email }
            }
        }
    """
    EMAIL1 = '{}@tarantool.io'.format(USERNAME1).lower()
    obj = srv.graphql(req, variables={'username': USERNAME1, 'email': EMAIL1})
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['edit_user']['email'] == EMAIL1
    del EMAIL1

    obj = srv.graphql(req, variables={'username': 'Invalid Username'})
    assert obj['errors'][0]['message'] == \
        "User not found: 'Invalid Username'"

    req = """
        mutation($username: String!) {
            cluster {
                remove_user(username:$username) { username }
            }
        }
    """
    obj = srv.graphql(req, variables={'username': USERNAME2})
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['remove_user']['username'] == USERNAME2
    del USERNAME2
    del PASSWORD2

    obj = srv.graphql(req, variables={'username': 'Invalid Username'})
    assert obj['errors'][0]['message'] == \
        "User not found: 'Invalid Username'"

    req = """
        {
            cluster {
                auth_params {
                    enabled
                    username
                }
            }
        }
    """

    obj = srv.graphql(req)
    assert 'errors' not in obj, obj['errors'][0]['message']
    auth_params = obj['data']['cluster']['auth_params']
    assert auth_params['enabled'] == False
    assert auth_params['username'] is None

    lsid = _login(srv, USERNAME1, PASSWORD1).cookies['lsid']
    obj = srv.graphql(req, cookies={'lsid': lsid})
    assert 'errors' not in obj, obj['errors'][0]['message']
    auth_params = obj['data']['cluster']['auth_params']
    assert auth_params['enabled'] == False
    assert auth_params['username'] == USERNAME1

    req = """
        mutation {
            cluster {
                auth_params(enabled: true) { enabled }
            }
        }
    """

    obj = srv.graphql(req)
    assert obj['errors'][0]['message'] == \
        'You must log in to enable authentication'

    obj = srv.graphql(req, cookies={'lsid': lsid})
    assert 'errors' not in obj, obj['errors'][0]['message']
    auth_params = obj['data']['cluster']['auth_params']
    assert auth_params['enabled'] == True

def test_auth_enabled(cluster, cleanup, enable_auth):
    srv = cluster['master']
    USERNAME = 'Gander'
    PASSWORD = 'Black Lead'

    srv.conn.eval("""
        local auth = require('cartridge.auth')
        local res, err = auth.add_user('{}', '{}')
        assert(res, tostring(err))
    """.format(USERNAME, PASSWORD))

    lsid = _login(srv, USERNAME, PASSWORD).cookies['lsid']
    check_401(srv, cookies={'lsid': 'AA=='})
    check_401(srv, cookies={'lsid': '!!'})
    check_401(srv, cookies={'lsid': None})
    check_200(srv, cookies={'lsid': lsid})

def test_uninitialized(module_tmpdir, helpers):
    srv = Server(
        binary_port = 33401,
        http_port = 8401,
        alias = 'dummy'
    )
    srv.start(
        workdir="{}/localhost-{}".format(module_tmpdir, srv.binary_port),
        env = {
            'TARANTOOL_AUTH_ENABLED': 'true'
        }
    )

    try:
        helpers.wait_for(srv.ping_udp, timeout=5)

        resp = _login(srv, 'admin', 'cluster-cookies-for-the-cluster-monster')
        print('login successful')
        assert resp.status_code == 200, resp.content
        assert 'lsid' in resp.cookies

        lsid = resp.cookies['lsid']
        check_401(srv, cookies={'lsid': None})
        check_200(srv, cookies={'lsid': lsid})

    finally:
        srv.kill()

def test_keepalive(cluster, cleanup, disable_auth):
    USERNAME = 'Crow'
    PASSWORD = 'Teal Lead'

    srv = cluster['master']
    srv.conn.eval("""
        local auth = require('cartridge.auth')
        local res, err = auth.add_user(...)
        assert(res, tostring(err))
    """, (USERNAME, PASSWORD))

    def get_username(session):
        request = {"query": """
            {
                cluster {
                    auth_params { enabled username }
                }
            }
        """}
        r = session.post(srv.baseurl + '/admin/api', json=request)
        r.raise_for_status()
        obj = r.json()
        assert 'errors' not in obj, obj['errors'][0]['message']
        return obj['data']['cluster']['auth_params'].get('username', None)

    with requests.Session() as s:
        assert get_username(s) == None
        assert s.post(srv.baseurl + '/login',
            data={'username': USERNAME, 'password': PASSWORD}
        ).status_code == 200
        assert get_username(s) == USERNAME
        assert s.post(srv.baseurl + '/logout').status_code == 200
        assert get_username(s) == None

def test_basic_auth(cluster, cleanup, enable_auth):
    srv = cluster['master']

    srv.conn.eval("""
        local auth = require('cartridge.auth')
        local res, err = auth.add_user('U', 'P')
        assert(res, tostring(err))
    """)

    def _b64(s):
        return base64.b64encode(s.encode('utf-8')).decode('utf-8')

    def _h(*args):
        return {'Authorization': ' '.join(args)}

    check_401(srv, headers=_h('Basic', _b64('U')) )
    check_401(srv, headers=_h('Basic', _b64('U:')) )
    check_401(srv, headers=_h('Basic', _b64(':P')) )
    check_401(srv, headers=_h('Basic', _b64(':U:P')) )
    check_401(srv, headers=_h('Basic', _b64('U:P:')) )
    check_401(srv, headers=_h('Basic', _b64(':U:P:')) )
    check_401(srv, headers=_h('Basic', _b64('U:P:C')) )
    check_401(srv, headers=_h('Basic', _b64('U'), _b64('P')) )

    check_401(srv, headers=_h('Basic', _b64('x:x')) )
    check_401(srv, headers=_h('Basic', _b64('x:P')) )
    check_401(srv, headers=_h('Basic', _b64('U:x')) )
    check_401(srv, headers=_h('Weird', _b64('U:P')) )

    check_200(srv, headers=_h('Basic', _b64('U:P')) )

def get_lsid(resp):
    cookie = SimpleCookie()
    cookie.load(resp.headers['set-cookie'])
    return cookie['lsid']

def get_lsid_max_age(resp):
    return int(get_lsid(resp)['max-age'])

def test_set_params_graphql(cluster, cleanup, disable_auth):
    USERNAME = 'Heron'
    PASSWORD = 'Silver Titanium'

    srv = cluster['master']
    srv.conn.eval("""
        local auth = require('cartridge.auth')
        local res, err = auth.add_user('{}', '{}')
        assert(res, tostring(err))
    """.format(USERNAME, PASSWORD))

    lsid = get_lsid(_login(srv, USERNAME, PASSWORD))

    def get_auth_params(srv):
        req = """
            query {
                cluster {
                    auth_params {
                        enabled
                        cookie_max_age
                    }
                }
            }
        """
        obj = srv.graphql(req, cookies={'lsid': lsid.value})
        assert 'errors' not in obj, obj['errors'][0]['message']

        return obj['data']['cluster']['auth_params']

    def set_auth_params(enabled=None, cookie_max_age=None, **kwargs):
        req = """
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
            }
        """
        obj = cluster['master'].graphql(req,
            variables={
                'enabled': enabled,
                'cookie_max_age': cookie_max_age,
            },
            cookies={
                'lsid': lsid.value
            }
        )
        assert 'errors' not in obj, obj['errors'][0]['message']

        return obj['data']['cluster']['auth_params']

    assert get_auth_params(cluster['master'])['cookie_max_age'] == \
        int(lsid['max-age'])

    assert set_auth_params(enabled=False)['enabled'] == False
    assert set_auth_params(enabled=None)['enabled'] == False
    assert get_auth_params(cluster['replica'])['enabled'] == False
    assert set_auth_params(enabled=True)['enabled'] == True
    assert set_auth_params(enabled=None)['enabled'] == True
    assert get_auth_params(cluster['replica'])['enabled'] == True

    assert set_auth_params(cookie_max_age=69)['cookie_max_age'] == 69
    assert set_auth_params(cookie_max_age=None)['cookie_max_age'] == 69
    assert get_auth_params(cluster['replica'])['cookie_max_age'] == 69

    def login(alias):
        return _login(cluster[alias], USERNAME, PASSWORD)
    assert get_lsid_max_age(login('master')) == 69
    assert get_lsid_max_age(login('replica')) == 69

def test_cookie_renew(cluster, cleanup):
    USERNAME = 'Eagle'
    PASSWORD = 'Yellow Zinc'

    srv = cluster['master']
    srv.conn.eval("""
        local auth = require('cartridge.auth')
        local res, err = auth.add_user('{}', '{}')
        assert(res, tostring(err))
    """.format(USERNAME, PASSWORD))

    lsid = _login(srv, USERNAME, PASSWORD).cookies['lsid']

    obj = cluster['master'].graphql("""
        mutation {
            cluster {
                auth_params(cookie_renew_age: 0) { }
            }
        }
    """, cookies={'lsid': lsid})
    assert 'errors' not in obj, obj['errors'][0]['message']

    resp = srv.get_raw('/admin/config', cookies={'lsid': lsid})
    assert resp.status_code == 200
    assert 'lsid' in resp.cookies
    assert resp.cookies['lsid'] != ''
    assert resp.cookies['lsid'] != lsid

def test_cookie_expiry(cluster, cleanup, disable_auth):
    srv = cluster['master']
    USERNAME = 'Hen'
    PASSWORD = 'White Platinum'
    srv.conn.eval("""
        local auth = require('cartridge.auth')
        local res, err = auth.add_user('{}', '{}')
        assert(res, tostring(err))
    """.format(USERNAME, PASSWORD))

    lsid = _login(srv, USERNAME, PASSWORD).cookies['lsid']

    def set_max_age(max_age):
        obj = srv.graphql("""
            mutation($max_age: Long) {
                cluster {
                    auth_params(cookie_max_age: $max_age) { }
                }
            }
        """, variables={'max_age': max_age})
        assert 'errors' not in obj, obj['errors'][0]['message']

    def get_username():
        obj = srv.graphql("""
            {
                cluster {
                    auth_params {
                        username
                    }
                }
            }
        """, cookies={'lsid': lsid})
        return obj['data']['cluster']['auth_params']['username']

    set_max_age(0)
    assert get_username() == None

    resp = srv.get_raw('/admin/config', cookies={'lsid': lsid})
    assert get_lsid_max_age(resp) == 0

    set_max_age(3600)
    assert get_username() == USERNAME
