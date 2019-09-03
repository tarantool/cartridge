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
    srv.conn.eval("""
        local auth = require('cartridge.auth')
        local res, err = auth.add_user(...)
        assert(res, tostring(err))
    """, ('guest', 'guest'))

    def upload(cfg):
        srv.put('/admin/config',
            files={'file': ('config.yaml', yaml.dump(cfg))}
        )

    custom_config = {
        'custom_config': {
            'Ultimate Question of Life, the Universe, and Everything': 42
        }
    }
    upload(custom_config)

    srv.conn.eval("""
        local confapplier = package.loaded['cartridge.confapplier']

        local custom_config = confapplier.get_readonly('custom_config')
        local _, answer = next(custom_config)
        assert(answer == 42, 'Answer ~= 42')

        local auth = confapplier.get_readonly('auth')
        assert(auth ~= nil, 'Missing auth config section')

        local users_acl = confapplier.get_readonly('users_acl')
        assert(users_acl ~= nil, 'Missing users_acl config section')
        local _, userdata = next(users_acl)
        assert(userdata ~= nil)
        assert(userdata.username == 'guest')
    """)

    resp = srv.get('/admin/config')
    assert yaml.safe_load(resp) == custom_config

    other_config = {
        'other_config': {
            'How many engineers does it take to change a light bulb': 1
        }
    }
    upload(other_config)

    resp = srv.get('/admin/config')
    conf = yaml.safe_load(resp)
    assert 'custom_config' not in conf
    assert 'other_config' in conf

def test_upload_fail(cluster):
    srv = cluster['master']

    system_sections = [
        'topology',
        'vshard', 'vshard_groups',
        'auth', 'users_acl'
    ]
    for sec in system_sections:
        resp = srv.put_raw('/admin/config', json={sec: {}})
        assert resp.status_code == 400
        assert resp.json()['class_name'] == 'Config upload failed'
        assert resp.json()['err'] == 'uploading system section "%s" is forbidden' % sec

    resp = srv.put_raw('/admin/config', files={'file': ','})
    assert resp.status_code == 400
    assert resp.json()['class_name'] == 'Decoding YAML failed'
    assert resp.json()['err'] == 'unexpected END event'

    resp = srv.put_raw('/admin/config', files={'file': 'Lorem ipsum dolor'})
    assert resp.status_code == 400
    assert resp.json()['class_name'] == 'Config upload failed'
    assert resp.json()['err'] == 'Config must be a table'
