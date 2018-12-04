#!/usr/bin/env python3

import os
import time
import yaml
import pytest
import signal
import logging
from conftest import Server

cluster = [
    Server(
        alias = 'A1',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = [],
        binary_port = 33001,
        http_port = 8081,
    ),
    Server(
        alias = 'B1',
        instance_uuid = 'bbbbbbbb-bbbb-4000-b000-000000000001',
        replicaset_uuid = 'bbbbbbbb-0000-4000-b000-000000000000',
        roles = ['myrole'],
        binary_port = 33002,
        http_port = 8082,
    ),
    Server(
        alias = 'B2',
        instance_uuid = 'bbbbbbbb-bbbb-4000-b000-000000000002',
        replicaset_uuid = 'bbbbbbbb-0000-4000-b000-000000000000',
        roles = ['myrole'],
        binary_port = 33003,
        http_port = 8083,
    )
]

def rpc_call(srv, role_name, fn_name, args=None, **kwargs):
    resp = srv.conn.eval("""
        local rpc = require('cluster.rpc')
        return rpc.call(...)
    """, (role_name, fn_name, args, kwargs))
    err = resp[1] if len(resp) > 1 else None
    return resp[0], err

def test_rpc_api(cluster):
    srv = cluster['A1']

    assert rpc_call(cluster['A1'], 'myrole', 'get_state') == \
        ('initialized', None)

    ret, err = rpc_call(cluster['A1'], 'myrole', 'fn_undefined')
    assert ret == None
    assert err['err'] == 'Role "myrole" has no method "fn_undefined"'

    ret, err = rpc_call(cluster['A1'], 'unknown-role', 'fn_undefined')
    assert ret == None
    assert err['err'] == 'No remotes with role "unknown-role" available'

def test_routing(cluster):
    assert rpc_call(cluster['B2'], 'myrole', 'is_master', leader_only=True) == \
        (True, None)
