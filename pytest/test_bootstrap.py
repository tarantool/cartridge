#!/usr/bin/env python3

import json
import time
import pytest
from conftest import Server

cluster = [
    Server(
        alias = 'master',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = [],
        binary_port = 33001,
        http_port = 8081,
    ),
    Server(
        alias = 'replica',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000002',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = [],
        binary_port = 33002,
        http_port = 8082,
    ),
]

def test_restart_one(cluster, helpers):
    cluster['master'].kill()
    cluster['master'].start()

    helpers.wait_for(cluster['master'].connect, timeout=5)

def test_restart_two(cluster, helpers):
    cluster['master'].kill()
    cluster['replica'].kill()
    cluster['master'].start()
    cluster['replica'].start()

    helpers.wait_for(cluster['master'].connect, timeout=5)
    helpers.wait_for(cluster['replica'].connect, timeout=5)
