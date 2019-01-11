#!/usr/bin/env python3

import pytest
import logging
from conftest import Server

cluster = [
    Server(
        alias = 'router',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = ['vshard-router'],
        binary_port = 33001,
        http_port = 8081,
    ),
    Server(
        alias = 'storage-1',
        instance_uuid = "bbbbbbbb-bbbb-4000-b000-000000000001",
        replicaset_uuid = "bbbbbbbb-0000-4000-b000-000000000000",
        roles = ['vshard-storage'],
        binary_port = 33011,
        http_port = 8181,
    ),
    Server(
        alias = 'storage-2',
        instance_uuid = "cccccccc-cccc-4000-b000-000000000001",
        replicaset_uuid = "cccccccc-0000-4000-b000-000000000000",
        roles = ['vshard-storage'],
        binary_port = 33012,
        http_port = 8182,
    )
]

def test_nonzero_weight(cluster):
    # It's prohibited to disable vshard-storage role with non-zero weight
    resp = cluster['router'].graphql("""
        mutation {
            edit_replicaset(
                uuid: "bbbbbbbb-0000-4000-b000-000000000000"
                roles: []
            )
        }
    """)
    assert resp['errors'][0]['message'] == \
        "replicasets[bbbbbbbb-0000-4000-b000-000000000000] is a vshard-storage which can't be removed"

    # It's prohibited to expell storage with non-zero weight
    resp = cluster['router'].graphql("""
        mutation {
            expell_server(
                uuid: "bbbbbbbb-bbbb-4000-b000-000000000001"
            )
        }
    """)
    assert resp['errors'][0]['message'] == \
        "replicasets[bbbbbbbb-0000-4000-b000-000000000000] is a vshard-storage which can't be removed"

@pytest.fixture(scope="module")
def storage_zero_weight(cluster):
    resp = cluster['router'].graphql("""
        mutation {
            edit_replicaset(
                uuid: "bbbbbbbb-0000-4000-b000-000000000000"
                weight: 0
            )
        }
    """)
    assert 'errors' not in resp, resp['errors'][0]['message']

def test_rebalancing_unfinished(cluster, storage_zero_weight):
    # It's prohibited to disable vshard-storage role until rebalancing finishes
    resp = cluster['router'].graphql("""
        mutation {
            edit_replicaset(
                uuid: "bbbbbbbb-0000-4000-b000-000000000000"
                roles: []
            )
        }
    """)
    assert resp['errors'][0]['message'] == \
        "replicasets[bbbbbbbb-0000-4000-b000-000000000000] rebalancing isn't finished yet"

    # It's prohibited to expell storage until rebalancing finishes
    resp = cluster['router'].graphql("""
        mutation {
            expell_server(
                uuid: "bbbbbbbb-bbbb-4000-b000-000000000001"
            )
        }
    """)
    assert resp['errors'][0]['message'] == \
        "replicasets[bbbbbbbb-0000-4000-b000-000000000000] rebalancing isn't finished yet"

def test_success(cluster, storage_zero_weight):
    # Speed up rebalancing
    cluster['storage-1'].conn.eval("""
        while vshard.storage.buckets_count() > 0 do
            vshard.storage.rebalancer_wakeup()
            require('fiber').sleep(0.1)
        end
    """)

    # Now it's possible to disable vshard-storage role
    resp = cluster['router'].graphql("""
        mutation {
            edit_replicaset(
                uuid: "bbbbbbbb-0000-4000-b000-000000000000"
                roles: []
            )
        }
    """)
    assert 'errors' not in resp, resp['errors'][0]['message']

    # Now it's possible to expell the storage
    resp = cluster['router'].graphql("""
        mutation {
            expell_server(
                uuid: "bbbbbbbb-bbbb-4000-b000-000000000001"
            )
        }
    """)
    assert 'errors' not in resp, resp['errors'][0]['message']
