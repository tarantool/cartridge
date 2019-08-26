#!/usr/bin/env python3

import sys
import json
import pytest
import base64
import logging
import requests

from conftest import Server

USERNAME = 'admin'
PASSWORD = '12345'
env = {
    'TARANTOOL_AUTH_ENABLED': 'true',
    'TARANTOOL_CLUSTER_COOKIE': PASSWORD
}
init_script = 'srv_woauth.lua'
unconfigured = [
    Server(
        alias = 'master',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = [],
        binary_port = 33001,
        http_port = 8081,
    )
]

def _login(srv, username, password):
    return srv.post_raw('/login',
        data={'username': username, 'password': password}
    )

def _bauth(username, password):
    _s = ':'.join([username, password])
    _b64 = base64.b64encode(_s.encode('utf-8')).decode('utf-8')
    return {'Authorization': ' '.join(['Basic', _b64])}

def check_401(srv, **kwargs):
    resp = srv.graphql('{}', **kwargs)
    assert resp['errors'][0]['message'] == "Unauthorized"


def check_200(srv, **kwargs):
    resp = srv.graphql('{}', **kwargs)
    assert 'errors' not in resp, resp['errors'][0]['message']

def test_api(cluster):
    srv = cluster['master']

    obj = srv.graphql("""
        {
            cluster {
                auth_params {
                    enabled
                    username
                }
            }
        }
    """, headers=_bauth(USERNAME, PASSWORD))
    assert 'errors' not in obj, obj['errors'][0]['message']
    auth_params = obj['data']['cluster']['auth_params']
    assert auth_params['enabled'] == True
    assert auth_params['username'] == USERNAME

    def add_user(username, password):
        return srv.graphql(
            """
                mutation($username: String! $password: String!) {
                    cluster {
                        add_user(username:$username password:$password) { username }
                    }
                }
            """,
            variables={'username': username, 'password': password},
            headers=_bauth(USERNAME, PASSWORD)
        )

    obj = add_user(USERNAME, 'qwerty')
    assert obj['errors'][0]['message'] == \
        "add_user() can't override integrated superuser '%s'" % USERNAME

    obj = add_user('guest', 'qwerty')
    assert obj['errors'][0]['message'] == \
        "add_user() callback isn't set"

    def edit_user(username, password):
        return srv.graphql(
            """
                mutation($username: String! $password: String!) {
                    cluster {
                        edit_user(username:$username password:$password) { username }
                    }
                }
            """,
            variables={'username': username, 'password': password},
            headers=_bauth(USERNAME, PASSWORD)
        )

    obj = edit_user(USERNAME, 'qwerty')
    assert obj['errors'][0]['message'] == \
        "edit_user() can't change integrated superuser '%s'" % USERNAME

    obj = edit_user('guest', 'qwerty')
    assert obj['errors'][0]['message'] == \
        "edit_user() callback isn't set"

    def list_users(username):
        return srv.graphql(
            """
                query($username: String) {
                    cluster {
                        users(username: $username) { username }
                    }
                }
            """,
            variables={'username': username},
            headers=_bauth(USERNAME, PASSWORD)
        )

    obj = list_users(None)
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['users'] == [{'username': USERNAME}]

    obj = list_users(USERNAME)
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['users'] == [{'username': USERNAME}]

    obj = list_users('guest')
    assert obj['errors'][0]['message'] == \
        "get_user() callback isn't set"

def test_login(cluster):
    srv = cluster['master']

    assert _login(srv, USERNAME, 'Invalid Password').status_code == 403
    assert _login(srv, 'Invalid Username', PASSWORD).status_code == 403
    assert _login(srv, None, PASSWORD).status_code == 403
    assert _login(srv, USERNAME, None).status_code == 403
    assert _login(srv, None, None).status_code == 403

    check_401(srv)

    # Check auth with cookie

    resp = _login(srv, USERNAME, PASSWORD)
    assert resp.status_code == 200, str(resp)
    assert 'lsid' in resp.cookies
    assert resp.cookies['lsid'] != ''
    lsid = resp.cookies['lsid']

    check_401(srv, cookies={'lsid': 'AA=='})
    check_401(srv, cookies={'lsid': '!!'})
    check_401(srv, cookies={'lsid': None})
    check_200(srv, cookies={'lsid': lsid})

    # Check basic auth

    check_401(srv, headers=_bauth(USERNAME, '000000'))
    check_401(srv, headers=_bauth('guest',  PASSWORD))
    check_200(srv, headers=_bauth(USERNAME, PASSWORD))

