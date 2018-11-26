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

def test_api(cluster):
    srv = cluster['master']
    obj = srv.graphql("""
        {
            cluster { known_roles }
        }
    """)
    assert 'errors' not in obj
    assert obj['data']['cluster']['known_roles'] == \
        ['vshard-storage', 'vshard-router', 'myrole']


def test_myrole(cluster):
    srv = cluster['master']
    obj = srv.graphql("""
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-4000-b000-000000000000"
                roles: ["myrole"]
            )
        }
    """)
    assert 'errors' not in obj
    srv.conn.eval("""
        local service_registry = require('cluster.service-registry')
        assert(service_registry.get('myrole') ~= nil)
    """)
    srv.conn.eval("""
        assert(package.loaded['mymodule'].get_state() == 'initialized')
    """)


