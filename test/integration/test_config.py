#!/usr/bin/env python3

import os
import json
import yaml
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
    )
]

def test_upload_good(cluster):
    srv = cluster['master']
    custom_config = {
        'custom-config': {
            'Ultimate Question of Life, the Universe, and Everything': 42
        }
    }

    resp = srv.put('/admin/config',
        files={'file': (
            'config.yaml',
            yaml.dump(custom_config),
        )}
    )

    srv.conn.eval("""
        local confapplier = package.loaded['cluster.confapplier']
        local custom_config = confapplier.get_readonly('custom-config')
        local _, answer = next(custom_config)
        assert(answer == 42, 'Answer ~= 42')
    """)

    resp = srv.get('/admin/config')
    assert yaml.safe_load(resp) == custom_config

def test_upload_fail(cluster):
    srv = cluster['master']

    resp = srv.put_raw('/admin/config', json={'topology': None})
    assert resp.status_code == 400
    assert resp.json()['err'] == 'topology_new must be a table, got nil'

    resp = srv.put_raw('/admin/config', files={'file': ','})
    assert resp.status_code == 400
    assert resp.json()['class_name'] == 'Decoding YAML failed'
    assert resp.json()['err'] == 'unexpected END event'

    resp = srv.put_raw('/admin/config', files={'file': 'Lorem ipsum dolor'})
    assert resp.status_code == 400
    assert resp.json()['class_name'] == 'Config upload failed'
    assert resp.json()['err'] == 'Config must be a table'

    resp = srv.put_raw('/admin/config', files={'file': '{ }'})
    assert resp.status_code == 400
    assert resp.json()['class_name'] == 'Config upload failed'
    assert resp.json()['err'] == 'Config must not be empty'
