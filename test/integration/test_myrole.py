#!/usr/bin/env python3

import os
import json
import time
import yaml
import pytest
import signal
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
    )
]

def test_api(cluster):
    srv = cluster['master']
    obj = srv.graphql("""
        {
            cluster {
                known_roles { name dependencies }
            }
        }
    """)
    assert 'errors' not in obj
    assert obj['data']['cluster']['known_roles'] == \
        [
            {'name': 'vshard-storage', 'dependencies': [] },
            {'name': 'vshard-router', 'dependencies': [] },
            {'name': 'myrole-dependency', 'dependencies': [] },
            {'name': 'myrole', 'dependencies': ['myrole-dependency'] }
        ]

def test_myrole(cluster):
    srv = cluster['master']
    obj = srv.graphql("""
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-4000-b000-000000000000"
                roles: ["myrole"]
            )
        }
    """)
    assert 'errors' not in obj
    srv.conn.eval("""
        local service_registry = require('cartridge.service-registry')
        assert(service_registry.get('myrole') ~= nil)
    """)
    srv.conn.eval("""
        assert(package.loaded['mymodule'].get_state() == 'initialized')
    """)

    obj = srv.graphql("""
        {
            replicasets(uuid: "aaaaaaaa-0000-4000-b000-000000000000") {
                roles
            }
        }
    """)
    assert 'errors' not in obj
    assert obj['data']['replicasets'][0]['roles'] == \
        ['myrole-dependency', 'myrole']

    obj = srv.graphql("""
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-4000-b000-000000000000"
                roles: []
            )
        }
    """)
    assert 'errors' not in obj
    srv.conn.eval("""
        local service_registry = require('cartridge.service-registry')
        assert(service_registry.get('myrole') == nil)
    """)
    srv.conn.eval("""
        assert(package.loaded['mymodule'].get_state() == 'stopped')
    """)

def test_dependencies(cluster):
    srv = cluster['master']
    obj = srv.graphql("""
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-4000-b000-000000000000"
                roles: ["myrole"]
            )
        }
    """)
    assert 'errors' not in obj

    srv.conn.eval("""
        local service_registry = require('cartridge.service-registry')
        assert(service_registry.get('myrole-dependency') ~= nil)
    """)

def test_rename(cluster, helpers):
    """The test simulates a situation when the role is renamed in code,
    and the server is launced with old name in config.
    """

    srv = cluster['master']
    obj = srv.graphql("""
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-4000-b000-000000000000"
                roles: ["myrole"]
            )
        }
    """)

    srv.process.send_signal(signal.SIGINT)
    with open(os.path.join(srv.env['TARANTOOL_WORKDIR'], 'config.yml'), "r+") as f:
        config = yaml.load(f)
        replicasets = config['topology']['replicasets']
        replicaset = replicasets['aaaaaaaa-0000-4000-b000-000000000000']
        replicaset['roles'] = {'myrole-oldname': True}

        f.seek(0)
        yaml.dump(config, f, default_flow_style=False)
        f.truncate()
        logging.warn(('Config hacked: {}').format(f.name))

    srv.start()
    helpers.wait_for(srv.connect)

    # Presence of old role in config doesn't affect mutations
    obj = srv.graphql("""
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-4000-b000-000000000000"
                roles: ["myrole", "myrole-oldname"]
            )
        }
    """)
    assert 'errors' not in obj

    # Old name isn't displayed it webui
    obj = srv.graphql("""
        {
            replicasets(uuid: "aaaaaaaa-0000-4000-b000-000000000000") {
                roles
            }
        }
    """)
    assert 'errors' not in obj
    assert obj['data']['replicasets'][0]['roles'] == ['myrole-dependency', 'myrole']

    # Role with old name can be disabled
    obj = srv.graphql("""
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-4000-b000-000000000000"
                roles: []
            )
        }
    """)
    assert 'errors' not in obj

    # old role name can not be enabled back
    obj = srv.graphql("""
        mutation {
            edit_replicaset(
                uuid: "aaaaaaaa-0000-4000-b000-000000000000"
                roles: ["myrole-oldname"]
            )
        }
    """)
    assert obj['errors'][0]['message'] == \
        'replicasets[aaaaaaaa-0000-4000-b000-000000000000] can not enable unknown role "myrole-oldname"'

