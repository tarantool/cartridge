#!/usr/bin/env python3

import json
import time
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

def rpc_call(srv, role_name, fn_name, args=None, **kwargs):
    resp = srv.conn.eval("""
        local rpc = require('cluster.rpc')
        return rpc.call(...)
    """, (role_name, fn_name, args, kwargs))
    err = resp[1]['err'] if len(resp) > 1 else None
    return resp[0], err

def test_call(cluster, module_tmpdir, helpers):
    """ RPC calls must work properly right after synchronous join"""
    srv = Server(
        binary_port = 33002,
        http_port = 8082,
    )
    srv.start(
        workdir="{}/localhost-{}".format(module_tmpdir, srv.binary_port)
    )

    try:
        helpers.wait_for(srv.ping_udp, timeout=5)

        obj = cluster['master'].graphql("""
            mutation {
                join_server(
                    uri: "localhost:33002"
                    instance_uuid: "bbbbbbbb-bbbb-4000-b000-000000000001"
                    replicaset_uuid: "bbbbbbbb-0000-4000-b000-000000000000"
                    roles: ["myrole"]
                    timeout: 5
                )
            }
        """)
        assert 'errors' not in obj, obj['errors'][0]['message']
        assert obj['data']['join_server'] == True

        srv.connect()
        assert rpc_call(cluster['master'], 'myrole', 'get_state') == \
            ('initialized', None)

    finally:
        srv.kill()
