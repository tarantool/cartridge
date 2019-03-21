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
        local auth_mocks = require('auth-mocks')
        assert(
            cluster.set_auth_callbacks(auth_mocks)
        )
        log.info('Auth enabled')
    """)

@pytest.fixture(scope="function")
def disable_auth(cluster):
    cluster['master'].conn.eval("""
        local log = require('log')
        local cluster = require('cluster')
        assert(
            cluster.set_auth_callbacks(nil)
        )
        log.info('Auth disabled')
    """)

def test_unprotected(cluster, disable_auth):
    srv = cluster['master']
    assert srv.post_raw('/graphql').status_code == 200

def test_protected(cluster, enable_auth):
    srv = cluster['master']
    srv.conn.eval("""
        local auth_mocks = require('auth-mocks')
        assert(
            auth_mocks.add_user('Ptarmigan', 'Fuschia Copper')
        )
    """)

    def _login(username, password):
        return srv.post_raw('/login',
            data={'username': username, 'password': password}
        )

    assert _login('Ptarmigan', 'Invalid Password').status_code == 403
    assert _login(None, 'Invalid Password').status_code == 403
    assert _login('Ptarmigan', None).status_code == 403
    assert _login(None, None).status_code == 403

    resp = _login('Ptarmigan', 'Fuschia Copper')
    assert resp.status_code == 200
    assert 'lsid' in resp.cookies
    assert resp.cookies['lsid'] != ''

    lsid = resp.cookies['lsid']
    assert srv.post_raw('/graphql', cookies={'lsid': 'AA=='}).status_code == 401
    assert srv.post_raw('/graphql', cookies={'lsid': '!!'}).status_code == 401
    assert srv.post_raw('/graphql', cookies={'lsid': None}).status_code == 401
    assert srv.post_raw('/graphql', cookies={'lsid': lsid}).status_code == 200

    resp = srv.post_raw('/logout', cookies={'lsid': lsid})
    assert resp.status_code == 200
    assert 'lsid' not in resp.cookies
