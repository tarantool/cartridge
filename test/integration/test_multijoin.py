#!/usr/bin/env python3

import pytest
import logging
from conftest import Server

cluster = [
    Server(
        alias = 'firstling',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = [],
        binary_port = 33001,
        http_port = 8081,
    )
]

unconfigured = [
    Server(
        alias = 'twin-1',
        instance_uuid = "bbbbbbbb-bbbb-4000-b000-000000000001",
        replicaset_uuid = "bbbbbbbb-0000-4000-b000-000000000000",
        roles = [],
        binary_port = 33011,
        http_port = 8181,
    ),
    Server(
        alias = 'twin-2',
        instance_uuid = "bbbbbbbb-bbbb-4000-b000-000000000002",
        replicaset_uuid = "bbbbbbbb-0000-4000-b000-000000000000",
        roles = [],
        binary_port = 33012,
        http_port = 8182,
    )
]

def test_confapplier(cluster, helpers):
    """Test simultaneous bootstrap of two instances
        with master-master replication
    """

    cluster['firstling'].conn.eval("""
        local errors = require('errors')
        local cartridge = require('cartridge')
        local membership = require('membership')

        errors.assert('ProbeError', membership.probe_uri("{twin1.advertise_uri}"))
        errors.assert('ProbeError', membership.probe_uri("{twin2.advertise_uri}"))

        local topology = cartridge.config_get_deepcopy('topology')
        topology.servers["{twin1.instance_uuid}"] = {{
            replicaset_uuid = "{twin1.replicaset_uuid}",
            uri = "{twin1.advertise_uri}",
        }}
        topology.servers["{twin2.instance_uuid}"] = {{
            replicaset_uuid = "{twin2.replicaset_uuid}",
            uri = "{twin2.advertise_uri}",
        }}
        topology.replicasets["{twin1.replicaset_uuid}"] = {{
            roles = {{}},
            master = {{
                "{twin1.instance_uuid}",
                "{twin2.instance_uuid}",
            }}
        }}
        local ok, err = cartridge.config_patch_clusterwide({{topology = topology}})
        assert(ok, tostring(err))
    """.format(
        twin1 = cluster['twin-1'],
        twin2 = cluster['twin-2']
    ))

    helpers.wait_for(cluster['twin-1'].connect)
    helpers.wait_for(cluster['twin-2'].connect)
