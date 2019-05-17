#!/usr/bin/env python3

import json
import time
import pytest
import logging
from conftest import Server

cluster = [
    Server(
        alias = 'survivor',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = ['vshard-router'],
        binary_port = 33001,
        http_port = 8081,
    ),
    Server(
        alias = 'victim',
        instance_uuid = 'bbbbbbbb-bbbb-4000-b000-000000000001',
        replicaset_uuid = 'bbbbbbbb-0000-4000-b000-000000000000',
        roles = ['vshard-storage'],
        binary_port = 33002,
        http_port = 8082,
    )
]

def test_api_disable(cluster):
    # 1. Kill victim
    cluster['victim'].kill()

    # 2. Disable it
    obj = cluster['survivor'].graphql("""
        mutation {
            cluster { disable_servers(uuids: ["bbbbbbbb-bbbb-4000-b000-000000000001"]) }
        }
    """)
    assert 'errors' not in obj

    # 3. Check status
    obj = cluster['survivor'].graphql("""
        {
            servers(uuid: "bbbbbbbb-bbbb-4000-b000-000000000001") {
                disabled
            }
        }
    """)
    servers = obj['data']['servers']
    assert len(servers) == 1
    assert servers[0] == { 'disabled': True }
