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
        labels = [{"name": "storage", "value": "cold"}]
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

def test_server_labels(cluster, helpers):
    obj = cluster['master'].graphql("""
        {
            servers{
                uri
                labels{
                    name
                    value
                }
            }
        }
    """)

    assert 'errors' not in obj, obj['errors'][0]['message']
    servers = obj['data']['servers']

    assert {
       'uri': 'localhost:33001',
       'labels': [{'name': 'storage', 'value': 'cold'}]
    } == helpers.find(servers, 'uri', 'localhost:33001')

    assert {
       'uri': 'localhost:33002',
       'labels': []
    } == helpers.find(servers, 'uri', 'localhost:33002')

    obj = cluster['master'].graphql("""
        mutation {
            edit_server(
                uuid: "aaaaaaaa-aaaa-4000-b000-000000000002"
                labels: [{name: "storage", value: "hot"}]
            )
        }
    """)
    assert 'errors' not in obj, obj['errors'][0]['message']

    obj = cluster['master'].graphql("""
            {
                servers{
                    uri,
                    labels{
                        name
                        value
                    }
                }
            }
        """)

    assert 'errors' not in obj, obj['errors'][0]['message']
    servers = obj['data']['servers']

    assert {
               'uri': 'localhost:33001',
               'labels': [{'name': 'storage', 'value': 'cold'}]
           } == helpers.find(servers, 'uri', 'localhost:33001')

    assert {
               'uri': 'localhost:33002',
               'labels': [{'name': 'storage', 'value': 'hot'}]
           } == helpers.find(servers, 'uri', 'localhost:33002')

