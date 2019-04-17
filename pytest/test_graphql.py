#!/usr/bin/env python3

import json
import time
import pytest
import logging

from conftest import Server

cluster = [
    Server(
        alias = 'all',
        instance_uuid = 'aaaaaaaa-aaaa-4000-b000-000000000001',
        replicaset_uuid = 'aaaaaaaa-0000-4000-b000-000000000000',
        roles = ['vshard-router', 'vshard-storage'],
        binary_port = 33001,
        http_port = 8081,
    )
]

def test_upload_good(cluster):

    srv = cluster['all']

    srv.conn.eval("""
    package.loaded['test'] = {}
    package.loaded['test']['test'] = function(root, args)
      return args[1].value
    end

    package.loaded['test']['test2'] = function(root, args)
      local result = ''
      for _, tuple in ipairs(getmetatable(args).__index) do
        result = result .. tuple.value
      end
      return result
    end

    local graphql = require('cluster.graphql')
    local types = require('cluster.graphql.types')
    graphql.add_callback({
        name = 'test',
        doc = '',
        args = {arg=types.string.nonNull},
        kind = types.string.nonNull,
        callback = 'test.test',
    })
    graphql.add_callback({
        name = 'test2',
        doc = '',
        args = {arg=types.string.nonNull,
                arg2=types.string.nonNull,
        },
        kind = types.string.nonNull,
        callback = 'test.test2',
    })
    """)

    obj = srv.graphql("""
      {
        test(arg:"TEST")
      }
    """)

    assert obj['data']['test'] == 'TEST'

    obj = srv.graphql("""
      {
        test2(arg:"TEST", arg2:"22")
      }
    """)

    assert obj['data']['test2'] == 'TEST22'
