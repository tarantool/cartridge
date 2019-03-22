#!/usr/bin/env python3

import json
import pytest
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
        assert(cluster.set_auth_params({enabled = true}))
        log.info('Auth enabled')
    """)

@pytest.fixture(scope="function")
def disable_auth(cluster):
    cluster['master'].conn.eval("""
        local log = require('log')
        local cluster = require('cluster')
        assert(cluster.set_auth_params({enabled = false}))
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
    USERNAME = 'Duckling'
    PASSWORD = 'Red Nickel'
    assert srv.post_raw('/graphql').status_code == 200

    obj = srv.graphql("""
        mutation($username: String! $password: String!) {
            cluster {
                add_user(username:$username password:$password) { username }
            }
        }
    """, variables={'username': USERNAME, 'password': PASSWORD})
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['add_user']['username'] == USERNAME

    obj = srv.graphql("""
        {
            cluster {
                list_users { username }
            }
        }
    """)
    assert 'errors' not in obj, obj['errors'][0]['message']
    user_list = obj['data']['cluster']['list_users']
    assert len(user_list) == 1
    assert user_list[0]['username'] == USERNAME

    req = """
        {
            cluster {
                auth_params {
                    enabled
                    username
                    cookie_max_age
                    cookie_caching_time
                }
            }
        }
    """

    obj = srv.graphql(req)
    assert 'errors' not in obj, obj['errors'][0]['message']
    auth_params = obj['data']['cluster']['auth_params']
    assert auth_params['enabled'] == False
    assert auth_params['cookie_max_age'] > 0
    assert auth_params['cookie_caching_time'] > 0
    assert 'username' not in auth_params

    lsid = _login(srv, USERNAME, PASSWORD).cookies['lsid']
    obj = srv.graphql(req, cookies={'lsid': lsid})
    assert 'errors' not in obj, obj['errors'][0]['message']
    auth_params = obj['data']['cluster']['auth_params']
    assert auth_params['enabled'] == False
    assert auth_params['username'] == USERNAME

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


