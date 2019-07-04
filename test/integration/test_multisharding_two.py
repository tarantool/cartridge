#!/usr/bin/env python3

import pytest
import logging
from conftest import Server

env = {'MULTIPLE_VSHARD_ENABLED': 'YES'}
cluster = [
    Server(
        alias = 'router',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = ['vshard-router'],
        binary_port = 33001,
        http_port = 8081
    ),
    Server(
        alias = 'storage-hot',
        instance_uuid = 'bbbbbbbb-bbbb-4000-b000-000000000002',
        replicaset_uuid = 'bbbbbbbb-0000-4000-b000-000000000000',
        roles = ['vshard-storage'],
        vshard_group = 'hot',
        binary_port = 33002,
        http_port = 8082
    ),
    Server(
        alias = 'storage-cold',
        instance_uuid = 'cccccccc-cccc-4000-b000-000000000002',
        replicaset_uuid = 'cccccccc-0000-4000-b000-000000000000',
        roles = ['vshard-storage'],
        vshard_group = 'cold',
        binary_port = 33004,
        http_port = 8084
    )
]

unconfigured = [
    Server(
        alias = 'spare',
        instance_uuid = 'dddddddd-dddd-4000-b000-000000000001',
        replicaset_uuid = 'dddddddd-0000-4000-b000-000000000000',
        roles = [],
        vshard_group = None,
        binary_port = 33005,
        http_port = 8085
    )
]

def test_api(cluster):
    req = """
        {
            cluster {
                self { uuid }
                can_bootstrap_vshard
                vshard_bucket_count
                vshard_known_groups
            }
        }
    """

    obj = cluster['router'].graphql(req)
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['self']['uuid'] == cluster['router'].instance_uuid
    assert obj['data']['cluster']['can_bootstrap_vshard'] == False
    assert obj['data']['cluster']['vshard_bucket_count'] == 5000
    assert obj['data']['cluster']['vshard_known_groups'] == ['cold', 'hot']

    obj = cluster['spare'].graphql(req)
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['self']['uuid'] == None
    assert obj['data']['cluster']['can_bootstrap_vshard'] == False
    assert obj['data']['cluster']['vshard_bucket_count'] == 5000
    assert obj['data']['cluster']['vshard_known_groups'] == ['cold', 'hot']

def test_router_role(cluster):

    resp = cluster['router'].conn.eval("""
        local cluster = require('cluster')
        local router_role = assert(cluster.service_get('vshard-router'))

        assert(router_role.get() == nil, "Default router isn't initialized")

        return {
            hot = router_role.get('hot'):call(1, 'read', 'get_uuid'),
            cold = router_role.get('cold'):call(1, 'read', 'get_uuid'),
        }
    """)

    assert resp[0] == {
        'hot': 'bbbbbbbb-bbbb-4000-b000-000000000002',
        'cold': 'cccccccc-cccc-4000-b000-000000000002'
    }
