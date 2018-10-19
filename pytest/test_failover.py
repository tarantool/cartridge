#!/usr/bin/env python3

import json
import time
import pytest
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
        instance_uuid = 'bbbbbbbb-bbbb-4000-b000-000000000001',
        replicaset_uuid = 'bbbbbbbb-0000-4000-b000-000000000000',
        roles = ['vshard-storage'],
        binary_port = 33002,
        http_port = 8082,
    ),
    Server(
        alias = 'storage-2',
        instance_uuid = 'bbbbbbbb-bbbb-4000-b000-000000000002',
        replicaset_uuid = 'bbbbbbbb-0000-4000-b000-000000000000',
        roles = ['vshard-storage'],
        binary_port = 33003,
        http_port = 8083,
    )
]

def get_master(cluster, replicaset_uuid):
    obj = cluster['router'].graphql("""
        {
            replicasets(uuid: "%s") {
                master { uuid }
            }
        }
    """ % replicaset_uuid)
    assert 'errors' not in obj
    replicasets = obj['data']['replicasets']
    assert len(replicasets) == 1
    return replicasets[0]['master']['uuid']

def set_master(cluster, replicaset_uuid, master_uuid):
    obj = cluster['router'].graphql("""
        mutation {
            edit_replicaset(
                uuid: "%s"
                master: "%s"
            )
        }
    """ % (replicaset_uuid, master_uuid))
    assert 'errors' not in obj


def test_api(cluster):
    uuid_replicaset = "bbbbbbbb-0000-4000-b000-000000000000"
    uuid_s1 = "bbbbbbbb-bbbb-4000-b000-000000000001"
    uuid_s2 = "bbbbbbbb-bbbb-4000-b000-000000000002"

    set_master(cluster, uuid_replicaset, uuid_s1)
    assert get_master(cluster, uuid_replicaset) == uuid_s1
    set_master(cluster, uuid_replicaset, uuid_s2)
    assert get_master(cluster, uuid_replicaset) == uuid_s2

    try:
        set_master(cluster, uuid_replicaset, "bbbbbbbb-bbbb-4000-b000-000000000003")
    except AssertionError as e:
        pass
    else:
        raise RuntimeError('Invalid mutation succeded')

