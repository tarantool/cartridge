#!/usr/bin/env python3

import pytest
import logging
from conftest import Server
from test_multisharding_one import edit_vshard_group, get_vshard_groups

init_script = 'srv_multisharding.lua'

cluster = [
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
    ),
    Server(
        alias = 'router',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = ['vshard-router'],
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
    assert obj['data']['cluster']['vshard_bucket_count'] == 32000
    assert obj['data']['cluster']['vshard_known_groups'] == ['cold', 'hot']
    assert obj['data']['cluster']['vshard_groups'] == \
        [{
            'collect_bucket_garbage_interval': 0.5,
            'collect_lua_garbage': False,
            'rebalancer_disbalance_threshold': 1,
            'rebalancer_max_receiving': 100,
            'sync_timeout': 1,
            'name': 'cold',
            'bucket_count': 2000,
            'bootstrapped': True,
        }, {
            'collect_bucket_garbage_interval': 0.5,
            'collect_lua_garbage': False,
            'rebalancer_disbalance_threshold': 1,
            'rebalancer_max_receiving': 100,
            'sync_timeout': 1,
            'name': 'hot',
            'bucket_count': 30000,
            'bootstrapped': True,
        }]

    obj = cluster['spare'].graphql(req)
    assert 'errors' not in obj, obj['errors'][0]['message']
    assert obj['data']['cluster']['self']['uuid'] == None
    assert obj['data']['cluster']['can_bootstrap_vshard'] == False
    assert obj['data']['cluster']['vshard_bucket_count'] == 32000
    assert obj['data']['cluster']['vshard_known_groups'] == ['cold', 'hot']
    assert obj['data']['cluster']['vshard_groups'] == [
        {
            'collect_bucket_garbage_interval': 0.5,
            'collect_lua_garbage': False,
            'rebalancer_disbalance_threshold': 1,
            'rebalancer_max_receiving': 100,
            'sync_timeout': 1,
            'name': 'cold',
            'bucket_count': 2000,
            'bootstrapped': False,
        }, {
            'collect_bucket_garbage_interval': 0.5,
            'collect_lua_garbage': False,
            'rebalancer_disbalance_threshold': 1,
            'rebalancer_max_receiving': 100,
            'sync_timeout': 1,
            'name': 'hot',
            'bucket_count': 30000,
            'bootstrapped': False,
        }
    ]


def test_mutations(cluster):
    ruuid_cold = cluster['storage-cold'].replicaset_uuid
    obj = cluster['router'].graphql("""
        mutation {{
            edit_replicaset(
                uuid: "{uuid_cold}"
                vshard_group: "hot"
            )
        }}
    """.format(
        uuid_cold = ruuid_cold
    ))
    assert obj['errors'][0]['message'] == \
        'replicasets[{}].vshard_group can\'t be modified'.format(ruuid_cold)

    req = """
        mutation($group: String) {{
            join_server(
                uri: "{spare.advertise_uri}"
                instance_uuid: "{spare.instance_uuid}"
                replicaset_uuid: "{spare.replicaset_uuid}"
                roles: ["vshard-storage"]
                vshard_group: $group
            )
        }}
    """.format(spare = cluster['spare'])

    obj = cluster['router'].graphql(req)
    assert obj['errors'][0]['message'] == \
        'replicasets[{}]'.format(cluster['spare'].replicaset_uuid) + \
        '.vshard_group "default" doesn\'t exist'

    obj = cluster['router'].graphql(req,
        variables = {'group': 'unknown'}
    )
    assert obj['errors'][0]['message'] == \
        'replicasets[{}]'.format(cluster['spare'].replicaset_uuid) + \
        '.vshard_group "unknown" doesn\'t exist'


def test_router_role(cluster):
    resp = cluster['router'].conn.eval("""
        local cartridge = require('cartridge')
        local router_role = assert(cartridge.service_get('vshard-router'))

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


def test_set_vshard_options_positive(cluster):
    assert edit_vshard_group(cluster, group = 'cold',
                             rebalancer_max_receiving = 42)['data']['cluster']['edit_vshard_options'] == \
       {
           'collect_bucket_garbage_interval': 0.5,
           'collect_lua_garbage': False,
           'rebalancer_disbalance_threshold': 1,
           'rebalancer_max_receiving': 42,
           'sync_timeout': 1,
           'name': 'cold',
           'bucket_count': 2000,
           'bootstrapped': True,
       }

    assert edit_vshard_group(cluster, group = 'hot',
                             rebalancer_max_receiving = 44)['data']['cluster']['edit_vshard_options'] == \
           {
               'collect_bucket_garbage_interval': 0.5,
               'collect_lua_garbage': False,
               'rebalancer_disbalance_threshold': 1,
               'rebalancer_max_receiving': 44,
               'sync_timeout': 1,
               'name': 'hot',
               'bucket_count': 30000,
               'bootstrapped': True,
           }

    assert get_vshard_groups(cluster) == \
        [
            {
                'collect_bucket_garbage_interval': 0.5,
                'collect_lua_garbage': False,
                'rebalancer_disbalance_threshold': 1,
                'rebalancer_max_receiving': 42,
                'sync_timeout': 1,
                'name': 'cold',
                'bucket_count': 2000,
                'bootstrapped': True,
            },
            {
                'collect_bucket_garbage_interval': 0.5,
                'collect_lua_garbage': False,
                'rebalancer_disbalance_threshold': 1,
                'rebalancer_max_receiving': 44,
                'sync_timeout': 1,
                'name': 'hot',
                'bucket_count': 30000,
                'bootstrapped': True,
            }
        ]
