#!/usr/bin/env python3

import json
import time
import signal
import pytest
import logging
from conftest import Server
from conftest import create_cluster

vshard_uuid_replicaset = "bbbbbbbb-0000-4000-b000-000000000000"
vshard_uuid_s1 = "bbbbbbbb-bbbb-4000-b000-000000033011"
vshard_uuid_s2 = "bbbbbbbb-bbbb-4000-b000-000000033012"

empty_uuid_replicaset = "cccccccc-0000-4000-b000-000000000000"
empty_uuid_s1 = "cccccccc-cccc-4000-b000-000000033011"
empty_uuid_s2 = "cccccccc-cccc-4000-b000-000000033012"

cluster_with_vshard = [
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
        instance_uuid = vshard_uuid_s1,
        replicaset_uuid = vshard_uuid_replicaset,
        roles = ['vshard-storage'],
        binary_port = 33011,
        http_port = 8181,
    ),
    Server(
        alias = 'storage-2',
        instance_uuid = vshard_uuid_s2,
        replicaset_uuid = vshard_uuid_replicaset,
        roles = ['vshard-storage'],
        binary_port = 33012,
        http_port = 8182,
    )
]

cluster_without_vshard = [
    Server(
        alias = 'router',
        instance_uuid = 'aaaaaaaa-bbbb-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-1111-4000-b000-000000000000',
        roles = [],
        binary_port = 33002,
        http_port = 8082,
    ),
    Server(
        alias = 'storage-1',
        instance_uuid = empty_uuid_s1,
        replicaset_uuid = empty_uuid_replicaset,
        roles = [],
        binary_port = 33021,
        http_port = 8281,
    ),
    Server(
        alias = 'storage-2',
        instance_uuid = empty_uuid_s2,
        replicaset_uuid = empty_uuid_replicaset,
        roles = [],
        binary_port = 33022,
        http_port = 8282,
    )
]


@pytest.fixture(scope="module")
def vshard_cluster(request, confdir, module_tmpdir, helpers):
    return {
        "cluster": create_cluster(request, module_tmpdir, helpers, cluster_with_vshard),
        "uuid_replicaset": vshard_uuid_replicaset,
        "uuid_s1": vshard_uuid_s1,
        "uuid_s2": vshard_uuid_s2
    }


@pytest.fixture(scope="module")
def empty_cluster(request, confdir, module_tmpdir, helpers):
    return {
        "cluster": create_cluster(request, module_tmpdir, helpers, cluster_without_vshard),
        "uuid_replicaset": empty_uuid_replicaset,
        "uuid_s1": empty_uuid_s1,
        "uuid_s2": empty_uuid_s2
    }


@pytest.fixture(scope="module", params=["vshard", "empty"])
def cluster_wrapper(request):
    if request.param == "vshard":
        return request.getfuncargvalue("vshard_cluster")
    else:
        return request.getfuncargvalue("empty_cluster")


def get_master(cluster, replicaset_uuid):
    resp = cluster['router'].graphql("""
        query(
            $uuid: String!
        ){
            replicasets(uuid: $uuid) {
                master { uuid }
                active_master { uuid }
            }
        }
    """, variables={'uuid': replicaset_uuid})
    assert 'errors' not in resp, resp['errors'][0]['message']

    replicasets = resp['data']['replicasets']
    assert len(replicasets) == 1
    return replicasets[0]['master']['uuid'], \
        replicasets[0]['active_master']['uuid']

def set_master(cluster, replicaset_uuid, master_uuid):
    resp = cluster['router'].graphql("""
        mutation(
            $uuid: String!
            $master_uuid: [String!]!
        ) {
            edit_replicaset(
                uuid: $uuid
                master: $master_uuid
            )
        }
    """, variables={'uuid': replicaset_uuid, 'master_uuid': [master_uuid]})
    assert 'errors' not in resp, resp['errors'][0]['message']

def get_failover(cluster):
    obj = cluster['router'].graphql("""
        {
            cluster { failover }
        }
    """)
    assert 'errors' not in obj
    return obj['data']['cluster']['failover']

def set_failover(cluster, enabled):
    obj = cluster['router'].graphql("""
        mutation {
            cluster { failover(enabled: %s) }
        }
    """ % ("true" if enabled else "false"))
    assert 'errors' not in obj
    logging.warn('Failover %s' % ('enabled' if enabled else 'disabled'))
    return obj['data']['cluster']['failover']

def check_active_master(cluster, uuid_replicaset, expected_uuid):
    """Make sure active master uuid equals to the given uuid"""
    master, active_master = get_master(cluster, uuid_replicaset)
    assert active_master == expected_uuid

def test_api_master(cluster_wrapper, helpers):
    cluster = cluster_wrapper["cluster"]
    uuid_replicaset = cluster_wrapper["uuid_replicaset"]
    uuid_s1 = cluster_wrapper["uuid_s1"]
    uuid_s2 = cluster_wrapper["uuid_s2"]

    set_master(cluster, uuid_replicaset, uuid_s2)
    assert get_master(cluster, uuid_replicaset) == (uuid_s2, uuid_s2)
    set_master(cluster, uuid_replicaset, uuid_s1)
    assert get_master(cluster, uuid_replicaset) == (uuid_s1, uuid_s1)

    with pytest.raises(AssertionError) as excinfo:
        set_master(cluster, uuid_replicaset, 'bbbbbbbb-bbbb-4000-b000-000000000003')
    assert str(excinfo.value).split('\n', 1)[0] == \
        'replicasets[' + uuid_replicaset + '].master ' + \
        '"bbbbbbbb-bbbb-4000-b000-000000000003" doesn\'t exist'

    resp = cluster['router'].graphql("""
        mutation { expel_server(uuid: "%s") }
    """ % (uuid_s1))
    assert resp['errors'][0]['message'] == \
        'Server "' + uuid_s1 + '" is the master and can\'t be expelled'

    obj = cluster['router'].graphql("""
        {
            replicasets {
                uuid
                servers { uuid priority }
            }
        }
    """)
    assert 'errors' not in obj, obj['errors'][0]['message']
    replicasets = obj['data']['replicasets']
    assert {
        'uuid': uuid_replicaset,
        'servers': [
            {
                'uuid': uuid_s1,
                'priority': 1
            },
            {
                'uuid': uuid_s2,
                'priority': 2
            },
        ]
    } == helpers.find(replicasets, 'uuid', uuid_replicaset)


def test_api_failover(cluster_wrapper, helpers):
    cluster = cluster_wrapper["cluster"]
    assert set_failover(cluster, False) == False
    assert get_failover(cluster) == False
    assert set_failover(cluster, True) == True
    assert get_failover(cluster) == True


def test_switchover(cluster_wrapper, helpers):
    cluster = cluster_wrapper["cluster"]
    uuid_replicaset = cluster_wrapper["uuid_replicaset"]
    uuid_s1 = cluster_wrapper["uuid_s1"]
    uuid_s2 = cluster_wrapper["uuid_s2"]

    set_failover(cluster, False)

    # Switch to s1
    set_master(cluster, uuid_replicaset, uuid_s1)
    helpers.wait_for(check_active_master, [cluster, uuid_replicaset, uuid_s1])
    assert get_master(cluster, uuid_replicaset) == (uuid_s1, uuid_s1)

    # Switch to s2
    set_master(cluster, uuid_replicaset, uuid_s2)
    helpers.wait_for(check_active_master, [cluster, uuid_replicaset, uuid_s2])
    assert get_master(cluster, uuid_replicaset) == (uuid_s2, uuid_s2)


def test_sigkill(cluster_wrapper, helpers):
    cluster = cluster_wrapper["cluster"]
    uuid_replicaset = cluster_wrapper["uuid_replicaset"]
    uuid_s1 = cluster_wrapper["uuid_s1"]
    uuid_s2 = cluster_wrapper["uuid_s2"]

    set_failover(cluster, True)

    # Switch to s1
    set_master(cluster, uuid_replicaset, uuid_s1)
    helpers.wait_for(check_active_master, [cluster, uuid_replicaset, uuid_s1])
    assert get_master(cluster, uuid_replicaset) == (uuid_s1, uuid_s1)

    # Send SIGKILL to s1
    cluster['storage-1'].kill()
    logging.warning('storage-1 KILLED')
    helpers.wait_for(check_active_master, [cluster, uuid_replicaset, uuid_s2])
    assert get_master(cluster, uuid_replicaset) == (uuid_s1, uuid_s2)

    # Restart s1
    cluster['storage-1'].start()
    helpers.wait_for(cluster['storage-1'].connect)
    logging.warning('storage-1 STARTED')
    helpers.wait_for(check_active_master, [cluster, uuid_replicaset, uuid_s1])
    assert get_master(cluster, uuid_replicaset) == (uuid_s1, uuid_s1)


def test_sigstop(cluster_wrapper, helpers):
    cluster = cluster_wrapper["cluster"]
    uuid_replicaset = cluster_wrapper["uuid_replicaset"]
    uuid_s1 = cluster_wrapper["uuid_s1"]
    uuid_s2 = cluster_wrapper["uuid_s2"]

    set_failover(cluster, True)

    # Switch to s1
    set_master(cluster, uuid_replicaset, uuid_s1)
    helpers.wait_for(check_active_master, [cluster, uuid_replicaset, uuid_s1])
    assert get_master(cluster, uuid_replicaset) == (uuid_s1, uuid_s1)

    # Send SIGSTOP to s1
    cluster['storage-1'].process.send_signal(signal.SIGSTOP)
    logging.warning('storage-1 STOPPED')
    helpers.wait_for(check_active_master, [cluster, uuid_replicaset, uuid_s2])
    assert get_master(cluster, uuid_replicaset) == (uuid_s1, uuid_s2)

    logging.warning('Requesting statistics...')
    resp = cluster['router'].graphql("""
        {
            servers {
                uri
                statistics { }
            }
        }
    """)

    assert 'errors' not in resp, resp['errors'][0]['message']
    servers = resp['data']['servers']
    assert {
        'uri': cluster['storage-1'].advertise_uri,
        'statistics': None,
    } == helpers.find(servers, 'uri', cluster['storage-1'].advertise_uri)
    assert {
        'uri': cluster['storage-2'].advertise_uri,
        'statistics': {}
    } == helpers.find(servers, 'uri', cluster['storage-2'].advertise_uri)

    # Send SIGCONT to s1
    cluster['storage-1'].process.send_signal(signal.SIGCONT)
    logging.warning('storage-1 CONTINUED')
    helpers.wait_for(cluster['router'].cluster_is_healthy)
    helpers.wait_for(check_active_master, [cluster, uuid_replicaset, uuid_s1])
    assert get_master(cluster, uuid_replicaset) == (uuid_s1, uuid_s1)

    logging.warning('Requesting statistics...')
    resp = cluster['router'].graphql("""
        {
            servers {
                uri
                statistics { }
            }
        }
    """)

    assert 'errors' not in resp, resp['errors'][0]['message']
    servers = resp['data']['servers']
    assert {
        'uri': cluster['storage-1'].advertise_uri,
        'statistics': {}
    } == helpers.find(servers, 'uri', cluster['storage-1'].advertise_uri)
    assert {
        'uri': cluster['storage-2'].advertise_uri,
        'statistics': {}
    } == helpers.find(servers, 'uri', cluster['storage-2'].advertise_uri)


def test_rollback(cluster_wrapper, helpers):
    cluster = cluster_wrapper["cluster"]

    conn = cluster['storage-1'].conn

    # hack utils to throw error on file_write
    conn.eval('''\
        local utils = package.loaded["cluster.utils"]
        local e_file_write = require('errors').new_class("Artificial error")
        _G._utils_file_write = utils.file_write
        utils.file_write = function(filename)
            return nil, e_file_write:new("Hacked from pytest")
        end
    ''')

    # try to apply new config - it should fail
    obj = cluster['router'].graphql("""
        mutation {
            cluster { failover(enabled: false) }
        }
    """)
    assert obj['errors'][0]['message'] == 'Hacked from pytest'

    # restore utils.file_write
    conn.eval('''
        local utils = package.loaded["cluster.utils"]
        utils.file_write = _G._utils_file_write
        _G._utils_file_write = nil
    ''')

    # try to apply new config - now it should succeed
    resp = cluster['router'].graphql("""
        mutation {
            cluster { failover(enabled: false) }
        }
    """)
    assert 'errors' not in resp, resp['errors'][0]['message']
