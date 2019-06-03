#!/usr/bin/env python3

import json
import pytest
import base64
import logging
import requests
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

def enable_auth_internal(cluster):
    cluster['master'].conn.eval("""
            local log = require('log')
            local auth = require('cluster.auth')
            auth.set_enabled(true)
            log.info('Auth enabled')
        """)


@pytest.fixture(scope="function")
def enable_auth(cluster):
    enable_auth_internal(cluster)

def disable_auth_internal(cluster):
    cluster['master'].conn.eval("""
        local log = require('log')
        local auth = require('cluster.auth')
        auth.set_enabled(false)
        log.info('Auth disabled')
    """)

@pytest.fixture(scope="function")
def disable_auth(cluster):
    disable_auth_internal(cluster)

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
def test_login(cluster, auth, alias):
    srv = cluster[alias]
    if auth:
        enable_auth_internal(cluster)
        USERNAME = 'Ptarmigan'
    else:
        disable_auth_internal(cluster)
        USERNAME = 'Sparrow'
    PASSWORD = 'Fuschia Copper'

    srv.conn.eval("""
        local auth = require('cluster.auth')
        assert(auth.add_user('{}', '{}'))
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
    assert resp.status_code == 200
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
        local auth = require('cluster.auth')
        assert(auth.edit_user('{}', '{}'))
    """.format(USERNAME, NEW_PASSWORD))

    assert _login(srv, USERNAME, OLD_PASSWORD).status_code == 403
    resp = _login(srv, USERNAME, NEW_PASSWORD)
    assert resp.status_code == 200
    assert 'lsid' in resp.cookies
    assert resp.cookies['lsid'] != ''

    srv.conn.eval("""
        local auth = require('cluster.auth')
        assert(auth.remove_user('{}'))
    """.format(USERNAME))
    assert _login(srv, USERNAME, OLD_PASSWORD).status_code == 403
    assert _login(srv, USERNAME, NEW_PASSWORD).status_code == 403

    if auth:
        USERNAME = "SuperPuperUser"
        PASSWORD = "SuperPuperPassword-@3"

        srv.conn.eval("""
            local auth = require('cluster.auth')
            assert(auth.add_user('{}', '{}'))
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
        obj = srv.graphql(req, 
            variables={ 'username': USERNAME }, 
            cookies={ 'lsid': lsid }
        )
        assert obj['errors'][0]['message'] == "user can not remove himself"

        assert _login(srv, USERNAME, PASSWORD).status_code == 200

        srv.conn.eval("""
            local auth = require('cluster.auth')
            assert(auth.remove_user('{}'))
        """.format(USERNAME))
        assert _login(srv, USERNAME, PASSWORD).status_code == 403



def test_auth_disabled(cluster, disable_auth):
    srv = cluster['master']
    USERNAME1 = 'Duckling'
    PASSWORD1 = 'Red Nickel'
    USERNAME2 = 'Grouse'
    PASSWORD2 = 'Silver Copper'
    check_200(srv)

    req = """
        mutation($username: String! $password: String!) {
            cluster {
                add_user(username:$username password:$password) { username }
            }
        }
    """
    obj = srv.graphql(req, variables={'username': USERNAME1, 'password': PASSWORD1})
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['add_user']['username'] == USERNAME1

    obj = srv.graphql(req, variables={'username': USERNAME2, 'password': PASSWORD2})
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['add_user']['username'] == USERNAME2

    obj = srv.graphql(req, variables={'username': USERNAME1, 'password': PASSWORD1})
    assert obj['errors'][0]['message'] == \
        'User already exists'

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
        'User not found'

    obj = srv.graphql(req)
    assert len(obj['data']['cluster']['users']) == 2

    req = """
        mutation($username: String! $email: String) {
            cluster {
                edit_user(username:$username email:$email) { username email }
            }
        }
    """
    EMAIL1 = '{}@tarantool.io'.format(USERNAME1)
    obj = srv.graphql(req, variables={'username': USERNAME1, 'email': EMAIL1})
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['edit_user']['email'] == EMAIL1
    del EMAIL1

    obj = srv.graphql(req, variables={'username': 'Invalid Username'})
    assert obj['errors'][0]['message'] == \
        'User not found'

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
        'User not found'

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

def test_auth_enabled(cluster, enable_auth):
    srv = cluster['master']
    USERNAME = 'Gander'
    PASSWORD = 'Black Lead'

    srv.conn.eval("""
        local auth_mocks = require('auth-mocks')
        assert(auth_mocks.add_user('{}', '{}'))
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
        env = {'ADMIN_PASSWORD': 'qwerty'}
    )

    try:
        helpers.wait_for(srv.ping_udp, timeout=5)

        resp = _login(srv, 'admin', 'qwerty')
        assert resp.status_code == 200
        assert 'lsid' in resp.cookies

        lsid = resp.cookies['lsid']
        check_401(srv, cookies={'lsid': None})
        check_200(srv, cookies={'lsid': lsid})

    finally:
        srv.kill()

def test_keepalive(cluster, disable_auth):
    USERNAME = 'Crow'
    PASSWORD = 'Teal Lead'

    srv = cluster['master']
    srv.conn.eval("""
        local auth_mocks = require('auth-mocks')
        assert(auth_mocks.add_user(...))
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

def test_basic_auth(cluster, enable_auth):
    srv = cluster['master']

    srv.conn.eval("""
        local auth_mocks = require('auth-mocks')
        assert(auth_mocks.add_user('U', 'P'))
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
