#!/usr/bin/env python3

import json
import time
import signal
import pytest
import logging
from conftest import Server

uuid_replicaset = "bbbbbbbb-0000-4000-b000-000000000000"
uuid_s1 = "bbbbbbbb-bbbb-4000-b000-000000033011"
uuid_s2 = "bbbbbbbb-bbbb-4000-b000-000000033012"

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
        instance_uuid = uuid_s1,
        replicaset_uuid = uuid_replicaset,
        roles = ['vshard-storage'],
        binary_port = 33011,
        http_port = 8181,
    ),
    Server(
        alias = 'storage-2',
        instance_uuid = uuid_s2,
        replicaset_uuid = uuid_replicaset,
        roles = ['vshard-storage'],
        binary_port = 33012,
        http_port = 8182,
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
    assert 'errors' not in obj, obj['errors'][0]['message']

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

def callrw(cluster, fn, args=[]):
    conn = cluster['router'].conn
    resp = conn.call('vshard.router.callrw', (1, fn, args))
    err = resp[1] if len(resp) > 1 else None
    assert err == None
    return resp[0]

def test_api_master(cluster):
    set_master(cluster, uuid_replicaset, uuid_s2)
    assert get_master(cluster, uuid_replicaset) == uuid_s2
    set_master(cluster, uuid_replicaset, uuid_s1)
    assert get_master(cluster, uuid_replicaset) == uuid_s1

    with pytest.raises(AssertionError) as excinfo:
        set_master(cluster, uuid_replicaset, 'bbbbbbbb-bbbb-4000-b000-000000000003')
    assert str(excinfo.value).split('\n', 1)[0] \
        == 'replicasets[bbbbbbbb-0000-4000-b000-000000000000].master does not exist'

def test_api_failover(cluster):
    assert set_failover(cluster, False) == False
    assert get_failover(cluster) == False
    assert set_failover(cluster, True) == True
    assert get_failover(cluster) == True

def test_switchover(cluster, helpers):
    set_failover(cluster, False)

    set_master(cluster, uuid_replicaset, uuid_s1)
    assert helpers.wait_for(callrw, [cluster, 'get_uuid']) == uuid_s1

    set_master(cluster, uuid_replicaset, uuid_s2)
    assert helpers.wait_for(callrw, [cluster, 'get_uuid']) == uuid_s2

def test_sigkill(cluster, helpers):
    set_failover(cluster, True)

    set_master(cluster, uuid_replicaset, uuid_s1)
    assert helpers.wait_for(callrw, [cluster, 'get_uuid']) == uuid_s1

    cluster['storage-1'].kill()
    logging.warning('storage-1 KILLED')
    assert helpers.wait_for(callrw, [cluster, 'get_uuid']) == uuid_s2

    cluster['storage-1'].start()
    helpers.wait_for(cluster['storage-1'].connect)
    logging.warning('storage-1 STARTED')

    cluster['storage-2'].process.send_signal(signal.SIGSTOP)
    assert helpers.wait_for(callrw, [cluster, 'get_uuid']) == uuid_s1
    cluster['storage-2'].process.send_signal(signal.SIGCONT)
    helpers.wait_for(cluster['router'].cluster_is_healthy)

def test_sigstop(cluster, helpers):
    set_failover(cluster, True)

    set_master(cluster, uuid_replicaset, uuid_s1)
    assert helpers.wait_for(callrw, [cluster, 'get_uuid']) == uuid_s1

    ### Send SIGSTOP and check
    cluster['storage-1'].process.send_signal(signal.SIGSTOP)
    logging.warning('storage-1 STOPPED')
    assert helpers.wait_for(callrw, [cluster, 'get_uuid']) == uuid_s2

    logging.warning('Requesting statistics...')
    obj = cluster['router'].graphql("""
        {
            servers {
                uri
                statistics { }
            }
        }
    """)

    assert 'errors' not in obj, obj['errors'][0]['message']
    servers = obj['data']['servers']
    assert {
        'uri': 'localhost:33011'
    } == helpers.find(servers, 'uri', 'localhost:33011')
    assert {
        'uri': 'localhost:33012',
        'statistics': []
    } == helpers.find(servers, 'uri', 'localhost:33012')

    ### Send SIGCONT and check
    cluster['storage-1'].process.send_signal(signal.SIGCONT)
    logging.warning('storage-1 CONTINUED')
    helpers.wait_for(cluster['router'].cluster_is_healthy)
    assert helpers.wait_for(callrw, [cluster, 'get_uuid']) == uuid_s1

    logging.warning('Requesting statistics...')
    obj = cluster['router'].graphql("""
        {
            servers {
                uri
                statistics { }
            }
        }
    """)

    assert 'errors' not in obj, obj['errors'][0]['message']
    servers = obj['data']['servers']
    assert {
        'uri': 'localhost:33011',
        'statistics': []
    } == helpers.find(servers, 'uri', 'localhost:33011')
    assert {
        'uri': 'localhost:33012',
        'statistics': []
    } == helpers.find(servers, 'uri', 'localhost:33012')

def test_rollback(cluster, helpers):
    conn = cluster['storage-1'].conn

    # hack utils to throw error on file_write
    conn.eval('''\
        local utils = package.loaded["cluster.utils"]
        _G._utils_file_write = utils.file_write
        utils.file_write = function()
            error("Hacked from pytest")
        end
    ''')

    # try to apply new config - it should fail
    obj = cluster['router'].graphql("""
        mutation {
            cluster { failover(enabled: false) }
        }
    """)
    assert obj['errors'][0]['message'] == 'eval:4: Hacked from pytest'

    # restore utils.file_write
    conn.eval('''
        local utils = package.loaded["cluster.utils"]
        utils.file_write = _G._utils_file_write
        _G._utils_file_write = nil
    ''')

    # try to apply new config - now it should succeed
    obj = cluster['router'].graphql("""
        mutation {
            cluster { failover(enabled: false) }
        }
    """)
    assert 'errors' not in obj
