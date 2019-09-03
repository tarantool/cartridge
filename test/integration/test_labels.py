#!/usr/bin/env python3

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
        labels = [{"name": "dc", "value": "msk"}]
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

unconfigured = [
    Server(
        alias = 'spare',
        instance_uuid = "dddddddd-dddd-4000-b000-000000000001",
        replicaset_uuid = "dddddddd-0000-4000-b000-000000000000",
        roles = [],
        binary_port = 33003,
        http_port = 8083,
    )
]

def test_servers_labels(cluster, helpers):
    helpers.wait_for(cluster['master'].conn.eval,
        ["assert(require('membership').probe_uri('localhost:33003'))"]
    )

    req = """
        {
            servers {
                uri
                labels { name value }
            }
        }
    """

    def assert_labels(servers, dc_expected):
        assert {
           'uri': 'localhost:33001',
           'labels': [{'name': 'dc', 'value': dc_expected}]
        } == helpers.find(servers, 'uri', 'localhost:33001')
        assert {
           'uri': 'localhost:33002',
           'labels': []
        } == helpers.find(servers, 'uri', 'localhost:33002')
        assert {
           'uri': 'localhost:33003',
           'labels': None
        } == helpers.find(servers, 'uri', 'localhost:33003')


    # Query labels
    obj = cluster['master'].graphql(req)
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert_labels(obj['data']['servers'], 'msk')


    # Edit labels
    obj = cluster['master'].graphql("""
        mutation {
            edit_server(
                uuid: "aaaaaaaa-aaaa-4000-b000-000000000001"
                labels: [{name: "dc", value: "spb"}]
            )
        }
    """)
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['edit_server'] == True

    # Query labels once again
    obj = cluster['master'].graphql(req)
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert_labels(obj['data']['servers'], 'spb')

def test_replicaset_labels(cluster, helpers):

    obj = cluster['master'].graphql("""
        {
            replicasets {
                servers {
                    uri
                    labels { name value }
                }
            }
        }
    """)
    assert 'errors' not in obj, obj['errors'][0]['message']

    replicasets = obj['data']['replicasets']
    assert len(replicasets) == 1
    servers = replicasets[0]['servers']
    assert len(servers) == 2

    master = servers[0]
    assert master['labels'] != None
    assert len(master['labels']) == 1

    slave = servers[1]
    assert slave['labels'] != None
    assert len(slave['labels']) == 0
