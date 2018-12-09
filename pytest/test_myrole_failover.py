#!/usr/bin/env python3

import pytest
import logging
from conftest import Server

cluster = [
    Server(
        alias = 'master',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = ['myrole'],
        binary_port = 33001,
        http_port = 8081,
    ),
    Server(
        alias = 'slave',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000002',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = [],
        binary_port = 33002,
        http_port = 8082,
    )
]

def test_failover(cluster, helpers):
    obj = cluster['master'].graphql("""
        mutation {
            cluster { failover(enabled: true) }
        }
    """)
    assert 'errors' not in obj
    logging.warn('Failover enabled')

    cluster['slave'].conn.eval("""
        assert(package.loaded['mymodule'].is_master() == false)
    """)

    cluster['master'].kill()
    # helpers.wait_for(cluster['slave'].)

    helpers.wait_for(cluster['slave'].conn.eval, """
        assert(package.loaded['mymodule'].is_master() == true)
    """)
