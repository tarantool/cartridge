#!/usr/bin/env python3

import sys
import json
import pytest
import base64
import logging
import requests

from conftest import Server

cluster = [
    Server(
        alias = 'master',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = [],
        binary_port = 13301,
        http_port = 8081,
    ),
    Server(
        alias = 'replica',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000002',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = [],
        binary_port = 13302,
        http_port = 8082,
    )
]

def test_pass(cluster):
    resp = cluster['master'].graphql(query = '{}')
    assert "errors" not in resp, resp['errors'][0]['message']
