#!/usr/bin/env python3

import pytest
import logging
from conftest import Server

cluster = [
    Server(
        alias = 'router',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = ['vshard-router', 'vshard-storage'],
        binary_port = 33001,
        http_port = 8081
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


def get_vshard_groups(cluster):
    req = """
        query {
            cluster {
                vshard_groups {
                    name
                    bucket_count
                    bootstrapped
                    rebalancer_max_receiving
                    collect_lua_garbage
                    sync_timeout
                    collect_bucket_garbage_interval
                    rebalancer_disbalance_threshold
                }
            }
        }
        """
    obj = cluster['router'].graphql(req)
    assert 'errors' not in obj, obj['errors'][0]['message']
    return obj['data']['cluster']['vshard_groups']


def edit_vshard_group(cluster, check = True, **kwargs):
    req = """
        mutation(
            $rebalancer_max_receiving: Int
            $group: String!
            $collect_lua_garbage: Boolean
            $sync_timeout: Float
            $collect_bucket_garbage_interval: Float,
            $rebalancer_disbalance_threshold: Float
        ) {
            cluster {
                edit_vshard_options(
                    name: $group
                    rebalancer_max_receiving: $rebalancer_max_receiving
                    collect_lua_garbage: $collect_lua_garbage
                    sync_timeout: $sync_timeout
                    collect_bucket_garbage_interval: $collect_bucket_garbage_interval
                    rebalancer_disbalance_threshold: $rebalancer_disbalance_threshold
                ) {
                    name
                    bucket_count
                    bootstrapped
                    rebalancer_max_receiving
                    collect_lua_garbage
                    sync_timeout
                    collect_bucket_garbage_interval
                    rebalancer_disbalance_threshold
                }
            }
        }
    """

    obj = cluster['router'].graphql(req, variables=kwargs)
    if check:
        assert 'errors' not in obj, obj['errors'][0]['message']
    return obj


def test_api(cluster):
    req = """
        {
            cluster {
                self { uuid }
                can_bootstrap_vshard
                vshard_bucket_count
                vshard_known_groups
                vshard_groups {
                    name
                    bucket_count
                    bootstrapped
                    rebalancer_max_receiving
                    collect_lua_garbage
                    sync_timeout
                    collect_bucket_garbage_interval
                    rebalancer_disbalance_threshold
                }
            }
        }
    """

    obj = cluster['router'].graphql(req)
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['self']['uuid'] == cluster['router'].instance_uuid
    assert obj['data']['cluster']['can_bootstrap_vshard'] == False
    assert obj['data']['cluster']['vshard_bucket_count'] == 3000
    assert obj['data']['cluster']['vshard_known_groups'] == ['default']
    assert obj['data']['cluster']['vshard_groups'] == [
        {
            'collect_bucket_garbage_interval': 0.5,
            'collect_lua_garbage': False,
            'rebalancer_disbalance_threshold': 1,
            'rebalancer_max_receiving': 100,
            'sync_timeout': 1,
            'name': 'default',
            'bucket_count': 3000,
            'bootstrapped': True,
        }
    ]

    obj = cluster['spare'].graphql(req)
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['self']['uuid'] == None
    assert obj['data']['cluster']['can_bootstrap_vshard'] == False
    assert obj['data']['cluster']['vshard_bucket_count'] == 3000
    assert obj['data']['cluster']['vshard_known_groups'] == ['default']
    assert obj['data']['cluster']['vshard_groups'] == [
        {
            'collect_bucket_garbage_interval': 0.5,
            'collect_lua_garbage': False,
            'rebalancer_disbalance_threshold': 1,
            'rebalancer_max_receiving': 100,
            'sync_timeout': 1,
            'name': 'default',
            'bucket_count': 3000,
            'bootstrapped': False,
        }
    ]


def test_router_role(cluster):
    resp = cluster['router'].conn.eval("""
        local vshard = require('vshard')
        local cartridge = require('cartridge')
        local router_role = assert(cartridge.service_get('vshard-router'))

        assert(router_role.get() == vshard.router.static, "Default router is initialized")
        return {
            null = router_role.get():call(1, 'read', 'get_uuid'),
            default = router_role.get('default'):call(1, 'read', 'get_uuid'),
            static = vshard.router.call(1, 'read', 'get_uuid'),
        }
    """)

    assert resp[0] == {
        'null': 'aaaaaaaa-aaaa-4000-b000-000000000001',
        'static': 'aaaaaaaa-aaaa-4000-b000-000000000001',
        'default': 'aaaaaaaa-aaaa-4000-b000-000000000001'
    }


def test_set_vshard_options_positive(cluster):
    assert edit_vshard_group(cluster,
                             group = "default",
                             rebalancer_max_receiving = 42,
                             collect_lua_garbage = True,
                             sync_timeout = 24,
                             collect_bucket_garbage_interval = 42.24,
                             rebalancer_disbalance_threshold = 14
                             )['data']['cluster']['edit_vshard_options'] == \
           {
               'collect_bucket_garbage_interval': 42.24,
               'collect_lua_garbage': True,
               'rebalancer_disbalance_threshold': 14,
               'rebalancer_max_receiving': 42,
               'sync_timeout': 24,
               'name': 'default',
               'bucket_count': 3000,
               'bootstrapped': True,
           }

    assert edit_vshard_group(cluster,
                             group = "default",
                             rebalancer_max_receiving = None,
                             sync_timeout = 25,
                             )['data']['cluster']['edit_vshard_options'] == \
           {
               'collect_bucket_garbage_interval': 42.24,
               'collect_lua_garbage': True,
               'rebalancer_disbalance_threshold': 14,
               'rebalancer_max_receiving': 42,
               'sync_timeout': 25,
               'name': 'default',
               'bucket_count': 3000,
               'bootstrapped': True,
           }

    assert get_vshard_groups(cluster) == \
        [
           {
               'collect_bucket_garbage_interval': 42.24,
               'collect_lua_garbage': True,
               'rebalancer_disbalance_threshold': 14,
               'rebalancer_max_receiving': 42,
               'sync_timeout': 25,
               'name': 'default',
               'bucket_count': 3000,
               'bootstrapped': True,
           }
        ]


def test_set_vshard_options_negative(cluster):
    obj = edit_vshard_group(cluster, False, group = "undef", rebalancer_max_receiving = 42)
    assert obj['errors'][0]['message'] == 'vshard-group "undef" doesn\'t exist'

    obj = edit_vshard_group(cluster, False, group = "default", rebalancer_max_receiving = -42)
    assert obj['errors'][0]['message'] == 'vshard.rebalancer_max_receiving must be positive'

    obj = edit_vshard_group(cluster, False, group = "default", sync_timeout = -24)
    assert obj['errors'][0]['message'] == 'vshard.sync_timeout must be non-negative'

    obj = edit_vshard_group(cluster, False, group = "default", collect_bucket_garbage_interval = -42.24)
    assert obj['errors'][0]['message'] == 'vshard.collect_bucket_garbage_interval must be positive'

    obj = edit_vshard_group(cluster, False, group = "default", rebalancer_disbalance_threshold = -14)
    assert obj['errors'][0]['message'] == \
           'vshard.rebalancer_disbalance_threshold must be non-negative'
