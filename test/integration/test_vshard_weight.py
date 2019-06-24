#!/usr/bin/env python3

import json
import time
import pytest
import logging
from conftest import Server

cluster = [
    Server(
        alias = 'main',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = [],
        binary_port = 33001,
        http_port = 8081,
    )
]

def test_storage_weight(cluster):
    """ Test that vshard storages can be disabled without any limitations
    unless it has already been bootstrapped """

    srv = cluster['main']
    obj = srv.graphql("""
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-4000-b000-000000000000"
                roles: ["vshard-router", "vshard-storage"]
            )
        }
    """)
    assert 'errors' not in obj

    obj = srv.graphql("""
        query {
            replicasets(uuid: "aaaaaaaa-0000-4000-b000-000000000000") {
                weight
            }
        }
    """)
    assert 'errors' not in obj
    replicasets = obj['data']['replicasets']
    assert replicasets[0]['weight'] == 1

    obj = srv.graphql("""
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-4000-b000-000000000000"
                roles: []
            )
        }
    """)
    assert 'errors' not in obj

