#!/usr/bin/env python3

import json
import time
import pytest
import logging
from conftest import Server

init_script = 'srv_vshardless.lua'

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

def test_edit_replicaset(cluster):
    obj = cluster['main'].graphql("""
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-4000-b000-000000000000"
                roles: ["vshard-router"]
            )
        }
    """)
    assert obj['errors'][0]['message'] == \
        'replicasets[aaaaaaaa-0000-4000-b000-000000000000]' + \
        ' can not enable unknown role "vshard-router"'

    obj = cluster['main'].graphql("""
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-4000-b000-000000000000"
                roles: ["vshard-storage"]
            )
        }
    """)
    assert obj['errors'][0]['message'] == \
        'replicasets[aaaaaaaa-0000-4000-b000-000000000000]' + \
        ' can not enable unknown role "vshard-storage"'

def test_package_loaded(cluster):
    cluster['main'].conn.eval("""
        assert( package.loaded['cluster.roles.vshard-router'] == nil )
        assert( package.loaded['cluster.roles.vshard-storage'] == nil )
    """)

def test_config(cluster):
    # TODO Eliminate vshard section initialization during bootstrap
    assert cluster['main'].conn.eval("""
        local cluster = require('cluster')
        return cluster.config_get_readonly('vshard')
    """)[0] == {
        'bootstrapped': False,
        'bucket_count': 30000,
    }

    assert cluster['main'].conn.eval("""
        local cluster = require('cluster')
        return cluster.config_get_readonly('vshard_groups')
    """)[0] == None

def test_api(cluster):
    obj = cluster['main'].graphql("""
        {
            cluster {
                can_bootstrap_vshard
                vshard_bucket_count
                vshard_known_groups
                vshard_groups {
                    name
                    bucket_count
                    bootstrapped
                }
            }
        }
    """)
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster'] == {
        "can_bootstrap_vshard": False,
        "vshard_bucket_count": 0,
        "vshard_known_groups": [],
        "vshard_groups": []
    }
