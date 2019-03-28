#!/usr/bin/env python3

import json
import pytest
import base64
import logging
from conftest import Server

cluster = [
    Server(
        alias = 'master',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = [],
        binary_port = 33001,
        http_port = 8081,
    )
]

@pytest.fixture(scope="function")
def enable_auth(cluster):
    cluster['master'].conn.eval("""
        local log = require('log')
        local cluster = require('cluster')
        cluster.set_auth_enabled(true)
        log.info('Auth enabled')
    """)

@pytest.fixture(scope="function")
def disable_auth(cluster):
    cluster['master'].conn.eval("""
        local log = require('log')
        local cluster = require('cluster')
        cluster.set_auth_enabled(false)
        log.info('Auth disabled')
    """)

def _login(srv, username, password):
    return srv.post_raw('/login',
        data={'username': username, 'password': password}
    )

@pytest.mark.parametrize("auth", [True, False])
def test_login(cluster, auth):
    srv = cluster['master']
    if auth:
        enable_auth(cluster)
        USERNAME = 'Ptarmigan'
    else:
        disable_auth(cluster)
        USERNAME = 'Sparrow'
    PASSWORD = 'Fuschia Copper'

    srv.conn.eval("""
        local auth_mocks = require('auth-mocks')
        assert(auth_mocks.add_user('{}', '{}'))
    """.format(USERNAME, PASSWORD))

    assert _login(srv, USERNAME, 'Invalid Password').status_code == 403
    assert _login(srv, 'Invalid Username', PASSWORD).status_code == 403
    assert _login(srv, None, PASSWORD).status_code == 403
    assert _login(srv, USERNAME, None).status_code == 403
    assert _login(srv, None, None).status_code == 403

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
        local auth_mocks = require('auth-mocks')
        assert(auth_mocks.edit_user('{}', '{}'))
    """.format(USERNAME, NEW_PASSWORD))

    assert _login(srv, USERNAME, OLD_PASSWORD).status_code == 403
    resp = _login(srv, USERNAME, NEW_PASSWORD)
    assert resp.status_code == 200
    assert 'lsid' in resp.cookies
    assert resp.cookies['lsid'] != ''

    srv.conn.eval("""
        local auth_mocks = require('auth-mocks')
        assert(auth_mocks.remove_user('{}'))
    """.format(USERNAME))
    assert _login(srv, USERNAME, OLD_PASSWORD).status_code == 403
    assert _login(srv, USERNAME, NEW_PASSWORD).status_code == 403

def test_auth_disabled(cluster, disable_auth):
    srv = cluster['master']
    USERNAME1 = 'Duckling'
    PASSWORD1 = 'Red Nickel'
    USERNAME2 = 'Grouse'
    PASSWORD2 = 'Silver Copper'
    assert srv.post_raw('/graphql').status_code == 200

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
    assert 'username' not in auth_params

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
    assert srv.post_raw('/graphql', cookies={'lsid': 'AA=='}).status_code == 401
    assert srv.post_raw('/graphql', cookies={'lsid': '!!'}).status_code == 401
    assert srv.post_raw('/graphql', cookies={'lsid': None}).status_code == 401
    assert srv.post_raw('/graphql', cookies={'lsid': lsid}).status_code == 200

def test_clusterwide(cluster, enable_auth, module_tmpdir, helpers):
    USERNAME = 'Cormorant'
    PASSWORD = 'Navy Iron'

    master = cluster['master']
    master.conn.eval("""
        local auth_mocks = require('auth-mocks')
        assert(auth_mocks.add_user(...))
    """, (USERNAME, PASSWORD))
    lsid = _login(master, USERNAME, PASSWORD).cookies['lsid']

    replica = Server(
        binary_port = 33002,
        http_port = 8082,
        alias = 'replica'
    )
    replica.start(
        workdir="{}/localhost-{}".format(module_tmpdir, replica.binary_port),
    )

    try:
        helpers.wait_for(replica.ping_udp, timeout=5)
        obj = master.graphql("""
            mutation {
                join_server(
                    uri: "localhost:33002"
                    instance_uuid: "dddddddd-dddd-4000-b000-000000000001"
                    replicaset_uuid: "dddddddd-0000-4000-b000-000000000000"
                )
            }
        """, cookies={'lsid': lsid})
        assert 'errors' not in obj, obj['errors'][0]['message']
        assert obj['data']['join_server'] == True

        helpers.wait_for(replica.connect, timeout=5)
        replica.conn.eval("""
            local auth_mocks = require('auth-mocks')
            assert(auth_mocks.add_user(...))
        """, (USERNAME, PASSWORD))
        assert replica.post_raw('/graphql', cookies={'lsid': None}).status_code == 401
        assert replica.post_raw('/graphql', cookies={'lsid': lsid}).status_code == 200

    finally:
        replica.kill()

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
        assert srv.post_raw('/graphql', cookies={'lsid': None}).status_code == 401
        assert srv.post_raw('/graphql', cookies={'lsid': lsid}).status_code == 200

    finally:
        srv.kill()

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

    def _post(h):
        return srv.post_raw('/graphql', headers=h)

    assert _post(_h('Basic', _b64('U'))).status_code == 401
    assert _post(_h('Basic', _b64('U:'))).status_code == 401
    assert _post(_h('Basic', _b64(':P'))).status_code == 401
    assert _post(_h('Basic', _b64(':U:P'))).status_code == 401
    assert _post(_h('Basic', _b64('U:P:'))).status_code == 401
    assert _post(_h('Basic', _b64(':U:P:'))).status_code == 401
    assert _post(_h('Basic', _b64('U:P:C'))).status_code == 401
    assert _post(_h('Basic', _b64('U'), _b64('P'))).status_code == 401

    assert _post(_h('Basic', _b64('x:x'))).status_code == 401
    assert _post(_h('Basic', _b64('x:P'))).status_code == 401
    assert _post(_h('Basic', _b64('U:x'))).status_code == 401
    assert _post(_h('Weird', _b64('U:P'))).status_code == 401

    assert _post(_h('Basic', _b64('U:P'))).status_code == 200

