#!/usr/bin/env python3

import json
import time
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
        alias = 'storage',
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
        binary_port = 33004,
        http_port = 8084,
    ),
    Server(
        alias = 'expelled',
        instance_uuid = 'cccccccc-cccc-4000-b000-000000000001',
        replicaset_uuid = 'cccccccc-0000-4000-b000-000000000000',
        roles = [],
        binary_port = 33009,
        http_port = 8089,
    ),
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

@pytest.fixture(scope="module")
def expelled(cluster):
    cluster['expelled'].kill()
    obj = cluster['router'].graphql("""
        mutation {
            expel_server(
                uuid: "cccccccc-cccc-4000-b000-000000000001"
            )
        }
    """)
    assert 'errors' not in obj, obj['errors'][0]['message']

def test_self(cluster):
    obj = cluster['router'].graphql("""
        {
            cluster {
                self {
                    uri
                    uuid
                    alias
                }
                can_bootstrap_vshard
                vshard_bucket_count
                vshard_known_groups
            }
        }
    """)
    assert 'errors' not in obj, obj['errors'][0]['message']

    assert obj['data']['cluster']['self'] == {
        'uri': 'localhost:33001',
        'uuid': 'aaaaaaaa-aaaa-4000-b000-000000000001',
        'alias': 'router',
    }
    assert obj['data']['cluster']['can_bootstrap_vshard'] == False
    assert obj['data']['cluster']['vshard_bucket_count'] == 3000
    assert obj['data']['cluster']['vshard_known_groups'] == ['default']

def test_custom_http_endpoint(cluster):
    resp = cluster['router'].get('/custom-get')
    assert resp == 'GET OK'
    resp = cluster['router'].post('/custom-post')
    assert resp == 'POST OK'

def test_server_stat_schema(cluster):
    obj = cluster['router'].graphql("""
        {
            __type(name: "ServerStat") {
                fields { name }
            }
        }
    """)

    assert 'errors' not in obj, obj['errors'][0]['message']

    field_names = set([ field['name'] for field in obj['data']['__type']['fields'] ])
    assert field_names == set([
        'items_size', 'items_used', 'items_used_ratio',
        'quota_size', 'quota_used', 'quota_used_ratio',
        'arena_size', 'arena_used', 'arena_used_ratio',
        'vshard_buckets_count'
    ])

    obj = cluster['router'].graphql("""
        {
            servers {
                statistics { %s }
            }
        }
    """ % (
        ' '.join(field_names),
    ))
    assert 'errors' not in obj, obj['errors'][0]['message']
    logging.info(obj['data']['servers'][0])


def test_server_info_schema(cluster):
    obj = cluster['router'].graphql("""
        {
            general_fields: __type(name: "ServerInfoGeneral") {
                fields { name }
            }
            storage_fields: __type(name: "ServerInfoStorage") {
                fields { name }
            }
            network_fields: __type(name: "ServerInfoNetwork") {
                fields { name }
            }
            replication_fields: __type(name: "ServerInfoReplication") {
                fields { name }
            }
        }
    """)

    assert 'errors' not in obj, obj['errors'][0]['message']

    obj = cluster['router'].graphql("""
        {
            servers {
                boxinfo {
                    general { %s }
                    storage { %s }
                    network { %s }
                    replication { %s }
                }
            }
        }
    """ % (
        ' '.join([ field['name'] for field in obj['data']['general_fields']['fields'] ]),
        ' '.join([ field['name'] for field in obj['data']['storage_fields']['fields'] ]),
        ' '.join([ field['name'] for field in obj['data']['network_fields']['fields'] ]),
        ' '.join([ field['name'] for field in obj['data']['replication_fields']['fields'] ]),
    ))
    assert 'errors' not in obj, obj['errors'][0]['message']
    logging.info(obj['data']['servers'][0])

def test_replication_info_schema(cluster):
    obj = cluster['router'].graphql("""
        {
            __type(name: "ReplicaStatus") {
                fields { name }
            }
        }
    """)
    assert 'errors' not in obj, obj['errors'][0]['message']
    field_names = set([ field['name'] for field in obj['data']['__type']['fields'] ])
    logging.info(field_names)

    obj = cluster['router'].graphql("""
        {
            servers {
                boxinfo {
                    replication {
                        replication_info {
                            %s
                        }
                    }
                }
            }
        }
    """ % ' '.join(field_names))
    assert 'errors' not in obj, obj['errors'][0]['message']


def test_servers(cluster, expelled, helpers):
    helpers.wait_for(cluster['router'].conn.eval,
        ["assert(require('membership').probe_uri('localhost:33003'))"]
    )

    obj = cluster['router'].graphql("""
        {
            servers {
                uri
                uuid
                alias
                labels
                disabled
                priority
                replicaset { roles }
                statistics { vshard_buckets_count }
            }
        }
    """)
    assert 'errors' not in obj, obj['errors'][0]['message']

    servers = obj['data']['servers']
    assert {
        'uri': 'localhost:33001',
        'uuid': 'aaaaaaaa-aaaa-4000-b000-000000000001',
        'alias': 'router',
        'labels': [],
        'priority': 1,
        'disabled': False,
        'statistics': {'vshard_buckets_count': None},
        'replicaset': {'roles': ['vshard-router']}
    } == helpers.find(servers, 'uri', 'localhost:33001')
    assert {
        'uri': 'localhost:33002',
        'uuid': 'bbbbbbbb-bbbb-4000-b000-000000000001',
        'alias': 'storage',
        'labels': [],
        'priority': 1,
        'disabled': False,
        'statistics': {'vshard_buckets_count': 3000},
        'replicaset': {'roles': ['vshard-storage']}
    } == helpers.find(servers, 'uri', 'localhost:33002')
    assert {
        'uri': 'localhost:33003',
        'uuid': '',
        'alias': 'spare',
        'labels': None,
        'priority': None,
        'disabled': None,
        'statistics': None,
        'replicaset': None
    } == helpers.find(servers, 'uri', 'localhost:33003')
    assert len(servers) == 4

def test_replicasets(cluster, expelled, helpers):
    obj = cluster['router'].graphql("""
        {
            replicasets {
                uuid
                alias
                roles
                status
                master { uuid }
                active_master { uuid }
                servers { uri priority }
                all_rw
                weight
            }
        }
    """)
    assert 'errors' not in obj, obj['errors'][0]['message']

    replicasets = obj['data']['replicasets']
    assert {
        'uuid': 'aaaaaaaa-0000-4000-b000-000000000000',
        'alias': 'unnamed',
        'roles': ['vshard-router'],
        'status': 'healthy',
        'master': {'uuid': 'aaaaaaaa-aaaa-4000-b000-000000000001'},
        'active_master': {'uuid': 'aaaaaaaa-aaaa-4000-b000-000000000001'},
        'servers': [{'uri': 'localhost:33001', 'priority': 1}],
        'all_rw': False,
        'weight': None,
    } == helpers.find(replicasets, 'uuid', 'aaaaaaaa-0000-4000-b000-000000000000')
    assert {
        'uuid': 'bbbbbbbb-0000-4000-b000-000000000000',
        'alias': 'unnamed',
        'roles': ['vshard-storage'],
        'status': 'healthy',
        'master': {'uuid': 'bbbbbbbb-bbbb-4000-b000-000000000001'},
        'active_master': {'uuid': 'bbbbbbbb-bbbb-4000-b000-000000000001'},
        'weight': 1,
        'all_rw': False,
        'servers': [
            {'uri': 'localhost:33002', 'priority': 1},
            {'uri': 'localhost:33004', 'priority': 2},
        ]
    } == helpers.find(replicasets, 'uuid', 'bbbbbbbb-0000-4000-b000-000000000000')
    assert len(replicasets) == 2

def test_probe_server(cluster, expelled, module_tmpdir, helpers):
    srv = cluster['router']
    req = """mutation($uri: String!) { probe_server(uri:$uri) }"""

    obj = srv.graphql(req,
        variables={'uri': 'localhost:9'}
    )
    assert obj['errors'][0]['message'] == \
        'Probe "localhost:9" failed: no response'

    obj = srv.graphql(req,
        variables={'uri': 'bad-host'}
    )
    assert obj['errors'][0]['message'] == \
        'Probe "bad-host" failed: ping was not sent'

    obj = srv.graphql(req,
        variables={'uri': srv.advertise_uri}
    )
    assert obj['data']['probe_server'] == True

def test_edit_server(cluster, expelled):
    obj = cluster['router'].graphql("""
        mutation {
            edit_server(
                uuid: "aaaaaaaa-aaaa-4000-b000-000000000001"
                uri: "localhost:3303"
            )
        }
    """)
    assert obj['errors'][0]['message'] == \
        'Server "localhost:3303" is not in membership'

    obj = cluster['router'].graphql("""
        mutation {
            edit_server(
                uuid: "cccccccc-cccc-4000-b000-000000000001"
                uri: "localhost:3303"
            )
        }
    """)
    assert obj['errors'][0]['message'] == \
        'Server "cccccccc-cccc-4000-b000-000000000001" is expelled'

    obj = cluster['router'].graphql("""
        mutation {
            edit_server(
                uuid: "dddddddd-dddd-4000-b000-000000000001"
                uri: "localhost:3303"
            )
        }
    """)
    assert obj['errors'][0]['message'] == \
        'Server "dddddddd-dddd-4000-b000-000000000001" not in config'

def test_edit_replicaset(cluster, expelled):
    obj = cluster['router'].graphql("""
        mutation {
            edit_replicaset(
                uuid: "bbbbbbbb-0000-4000-b000-000000000000"
                roles: ["vshard-router", "vshard-storage"]
            )
        }
    """)
    assert 'errors' not in obj

    obj = cluster['router'].graphql("""
        mutation {
            edit_replicaset(
                uuid: "bbbbbbbb-0000-4000-b000-000000000000"
                weight: 2
            )
        }
    """)
    assert 'errors' not in obj

    obj = cluster['router'].graphql("""
        mutation {
            edit_replicaset(
                uuid: "bbbbbbbb-0000-4000-b000-000000000000"
                master: ["bbbbbbbb-bbbb-4000-b000-000000000003"]
            )
        }
    """)
    assert obj['errors'][0]['message'] == \
        'replicasets[bbbbbbbb-0000-4000-b000-000000000000] leader ' + \
        '"bbbbbbbb-bbbb-4000-b000-000000000003" doesn\'t exist'

    obj = cluster['router'].graphql("""
        mutation {
            edit_replicaset(
                uuid: "bbbbbbbb-0000-4000-b000-000000000000"
                weight: -100
            )
        }
    """)
    assert obj['errors'][0]['message'] == \
        'replicasets[bbbbbbbb-0000-4000-b000-000000000000].weight must be non-negative, got -100'

    obj = cluster['storage'].graphql("""
        {
            replicasets(uuid: "bbbbbbbb-0000-4000-b000-000000000000") {
                uuid
                roles
                status
                servers { uri }
                weight
                all_rw
            }
        }
    """)

    replicasets = obj['data']['replicasets']
    assert len(replicasets) == 1
    assert {
        'uuid': 'bbbbbbbb-0000-4000-b000-000000000000',
        'roles': ['vshard-storage', 'vshard-router'],
        'status': 'healthy',
        'weight': 2,
        'all_rw': False,
        'servers': [{'uri': 'localhost:33002'}, {'uri': 'localhost:33004'}]
    } == replicasets[0]

    obj = cluster['router'].graphql("""
        mutation {
            edit_replicaset(
                uuid: "bbbbbbbb-0000-4000-b000-000000000000"
                all_rw: true
            )
        }
    """)
    assert 'errors' not in obj

    obj = cluster['storage'].graphql("""
        {
            replicasets(uuid: "bbbbbbbb-0000-4000-b000-000000000000") {
                uuid
                roles
                status
                servers { uri }
                weight
                all_rw
            }
        }
    """)
    replicasets = obj['data']['replicasets']
    assert len(replicasets) == 1
    assert {
        'uuid': 'bbbbbbbb-0000-4000-b000-000000000000',
        'roles': ['vshard-storage', 'vshard-router'],
        'status': 'healthy',
        'weight': 2,
        'all_rw': True,
        'servers': [{'uri': 'localhost:33002'}, {'uri': 'localhost:33004'}]
    } == replicasets[0]


@pytest.mark.parametrize("all_rw", [True, False])
def test_all_rw(cluster, all_rw, helpers):
    obj = cluster['router'].graphql("""
        mutation($all_rw: Boolean!) {
            edit_replicaset(
                uuid: "bbbbbbbb-0000-4000-b000-000000000000"
                all_rw: $all_rw
            )
        }
    """, variables={'all_rw': all_rw})
    assert 'errors' not in obj

    obj = cluster['router'].graphql("""
        {
            replicasets(uuid: "bbbbbbbb-0000-4000-b000-000000000000") {
                all_rw
                servers {
                    uuid
                    boxinfo {
                        general { ro }
                    }
                }
                master {
                    uuid
                }
            }
        }
    """)

    assert len(obj['data']['replicasets']) == 1
    replicaset = obj['data']['replicasets'][0]

    assert replicaset['all_rw'] == all_rw

    for srv in replicaset['servers']:
        if srv['uuid'] == replicaset['master']['uuid']:
            assert srv['boxinfo']['general']['ro'] == False
        else:
            assert srv['boxinfo']['general']['ro'] == (not all_rw)


def test_uninitialized(module_tmpdir, helpers):
    srv = Server(
        binary_port = 33101,
        http_port = 8181,
        alias = 'dummy'
    )
    srv.start(
        workdir="{}/localhost-{}".format(module_tmpdir, srv.binary_port),
    )

    try:
        helpers.wait_for(srv.ping_udp, timeout=5)

        obj = srv.graphql("""
            {
                servers {
                    uri
                    replicaset { roles }
                }
                replicasets {
                    status
                }
                cluster {
                    self {
                        uri
                        uuid
                        alias
                    }
                    can_bootstrap_vshard
                    vshard_bucket_count
                }
            }
        """)
        assert 'errors' not in obj, obj['errors'][0]['message']

        servers = obj['data']['servers']
        assert len(servers) == 1
        assert servers[0] == {'uri': 'localhost:33101', 'replicaset': None}

        replicasets = obj['data']['replicasets']
        assert len(replicasets) == 0

        assert obj['data']['cluster']['self'] == {
            'uri': 'localhost:33101',
            'alias': 'dummy',
            'uuid': None,
        }
        assert obj['data']['cluster']['can_bootstrap_vshard'] == False
        assert obj['data']['cluster']['vshard_bucket_count'] == 3000

        obj = srv.graphql("""
            mutation {
                join_server(uri: "127.0.0.1:33101")
            }
        """)
        assert obj['errors'][0]['message'] == \
            'Invalid attempt to call join_server().' + \
            ' This instance isn\'t bootstrapped yet' + \
            ' and advertises uri="localhost:33101"' + \
            ' while you are joining uri="127.0.0.1:33101".'

        obj = srv.graphql("""
            {
                cluster { failover }
            }
        """)
        assert 'errors' not in obj, obj['errors'][0]['message']
        assert obj['data']['cluster']['failover'] == False

        obj = srv.graphql("""
            mutation {
                cluster { failover(enabled: false) }
            }
        """)
        assert obj['errors'][0]['message'] == 'Not bootstrapped yet'
    finally:
        srv.kill()

def test_join_server(cluster, expelled, helpers):

    obj = cluster['router'].graphql("""
        mutation {
            probe_server(
                uri: "localhost:33003"
            )
        }
    """)
    assert 'errors' not in obj
    assert obj['data']['probe_server'] == True

    obj = cluster['router'].graphql("""
        mutation {
            join_server(
                uri: "localhost:33003"
                instance_uuid: "cccccccc-cccc-4000-b000-000000000001"
            )
        }
    """)
    assert obj['errors'][0]['message'] == \
        'Server "cccccccc-cccc-4000-b000-000000000001" is already joined'

    obj = cluster['router'].graphql("""
        mutation {
            join_server(
                uri: "localhost:33003"
                instance_uuid: "dddddddd-dddd-4000-b000-000000000001"
                replicaset_uuid: "dddddddd-0000-4000-b000-000000000000"
                roles: ["vshard-storage"]
                replicaset_weight: -0.3
            )
        }
    """)
    assert obj['errors'][0]['message'] == \
        '''replicasets[dddddddd-0000-4000-b000-000000000000].weight''' + \
        ''' must be non-negative, got -0.3'''

    obj = cluster['router'].graphql("""
        mutation {
            join_server(
                uri: "localhost:33003"
                instance_uuid: "dddddddd-dddd-4000-b000-000000000001"
                replicaset_uuid: "dddddddd-0000-4000-b000-000000000000"
                roles: ["vshard-storage"]
                vshard_group: "unknown"
            )
        }
    """)
    assert obj['errors'][0]['message'] == \
        '''replicasets[dddddddd-0000-4000-b000-000000000000] can't be added''' + \
        ''' to vshard_group "unknown", cluster doesn't have any'''

    obj = cluster['router'].graphql("""
        mutation {
            join_server(
                uri: "localhost:33003"
                instance_uuid: "dddddddd-dddd-4000-b000-000000000001"
                replicaset_uuid: "dddddddd-0000-4000-b000-000000000000"
                replicaset_alias: "spare-set"
                roles: ["vshard-storage"]
            )
        }
    """)
    assert 'errors' not in obj
    assert obj['data']['join_server'] == True

    helpers.wait_for(cluster['spare'].connect, timeout=5)
    helpers.wait_for(cluster['router'].connect, timeout=5)

    obj = cluster['router'].graphql("""
        {
            servers {
                uri
                uuid
                status
                replicaset { alias uuid status roles weight }
            }
        }
    """)

    assert 'errors' not in obj
    servers = obj['data']['servers']
    assert len(servers) == 4
    assert {
        'uri': 'localhost:33003',
        'uuid': 'dddddddd-dddd-4000-b000-000000000001',
        'status': 'healthy',
        'replicaset': {
            'alias': 'spare-set',
            'uuid': 'dddddddd-0000-4000-b000-000000000000',
            'roles': ["vshard-storage"],
            'status': 'healthy',
            'weight': 0,
        }
    } == helpers.find(servers, 'uuid', 'dddddddd-dddd-4000-b000-000000000001')
