#!/usr/bin/env python3

import os
import pytest
import logging
import tempfile
import py
import tarantool
import time
import requests

from socket import socket, AF_INET, SOCK_DGRAM
from socket import timeout as SocketTimeout
from subprocess import Popen, PIPE, STDOUT
from threading import Thread

logging.basicConfig(format='%(name)s > %(message)s')

srv_abspath = os.path.realpath(
    os.path.dirname(__file__)
)

TARANTOOL_CONNECTION_TIMEOUT = 5.0

COOKIE = 'cluster-cookies-for-the-cluster-monster'

class Helpers:
    @staticmethod
    def wait_for(fn, args=[], kwargs={}, timeout=1.0):
        """Repeatedly call fn(*args, **kwargs)
        until it returns something or timeout occurs"""
        time_start = time.time()
        while True:
            now = time.time()
            if now > time_start + timeout:
                break

            try:
                return fn(*args, **kwargs)
            except:
                time.sleep(0.1)

        # after timeout call fn once more to propagate exception
        return fn(*args, **kwargs)

@pytest.fixture(scope='session')
def helpers():
    return Helpers

@pytest.fixture(scope='module')
def module_tmpdir(request):
    dir = py.path.local(tempfile.mkdtemp())
    request.addfinalizer(lambda: dir.remove(rec=1))
    return str(dir)


@pytest.fixture(scope='module')
def datadir(request):
    dir = os.path.join(request.fspath.dirname, 'data')

    return str(dir)


@pytest.fixture(scope='module')
def confdir(request):
    dir = os.path.join(request.fspath.dirname, 'config')

    return str(dir)

class Server(object):
    def __init__(self, binary_port, http_port,
                alias=None, instance_uuid=None,
                replicaset_uuid=None, roles=None):

        self.alias = alias
        self.binary_port = binary_port
        self.http_port = http_port
        self.advertise_uri = 'localhost:{}'.format(self.binary_port)
        self.baseurl = 'http://localhost:{}'.format(http_port)

        self.soap_client = None
        self.conn = None
        self.thread = None
        self.env = None

        self.instance_uuid = instance_uuid
        self.replicaset_uuid = replicaset_uuid
        self.roles = roles

        pass

    def start(self, workdir=None):
        if self.env == None:
            self.env = os.environ.copy()
            self.env['ALIAS'] = str(self.alias)
            self.env['WORKDIR'] = str(workdir)
            self.env['HTTP_PORT'] = str(self.http_port)
            self.env['ADVERTISE_URI'] = str(self.advertise_uri)
            self.env['CLUSTER_COOKIE'] = COOKIE

        command = [os.path.join(srv_abspath, 'instance.lua')]

        logging.warn('export ALIAS="{}"'.format(self.env['ALIAS']))
        logging.warn('export WORKDIR="{}"'.format(self.env['WORKDIR']))
        logging.warn('export HTTP_PORT="{}"'.format(self.env['HTTP_PORT']))
        logging.warn('export ADVERTISE_URI="{}"'.format(self.env['ADVERTISE_URI']))
        logging.warn('export CLUSTER_COOKIE="{}"'.format(self.env['CLUSTER_COOKIE']))
        logging.warn(' '.join(command))

        self.process = Popen(command, env=self.env)

    def ping_udp(self):
        s = socket(AF_INET, SOCK_DGRAM)
        s.settimeout(0.1)
        try:
            addr = ('127.0.0.1', self.binary_port)
            s.connect_ex(addr)
            s.send(b'PING')
            try:
                s.recv(1024)
            except SocketTimeout as e:
                # Since the server does not reply to non-members
                # we expect recvfrom() to raise timeout error
                pass

            logging.warning('Ping UDP localhost:{} succeeded'.format(self.binary_port))
        finally:
            s.close()

    def connect(self):
        assert self.process.poll() is None
        if self.conn == None:
            self.conn = tarantool.connect(
                '127.0.0.1', self.binary_port,
                user='cluster',
                password=self.env['CLUSTER_COOKIE']
            )
        resp = self.conn.eval('return is_initialized()')
        assert not resp[1] # in case of error display faulty member
        assert resp[0]

    def kill(self):
        if self.conn != None:
            # logging.warn('Closing connection to {}'.format(self.port))
            self.conn.close()
            self.conn = None
        self.process.kill()
        logging.warn('localhost:'+str(self.binary_port)+' killed')

    def get(self, path, data=None, json=None, headers=None, **args):
        url = self.baseurl + '/' + path.lstrip('/')
        r = requests.get(url, data=data, json=json, headers=headers, **args)
        r.raise_for_status()

        return r.text

    def get_raw(self, path, data=None, json=None, headers=None, **args):
        url = self.baseurl + '/' + path.lstrip('/')
        r = requests.get(url, data=data, json=json, headers=headers, **args)
        r.raise_for_status()

        return r

    def post(self, path, data=None, json=None, headers=None, **args):
        url = self.baseurl + '/' + path.lstrip('/')
        r = requests.post(url, data=data, json=json, headers=headers, **args)
        r.raise_for_status()

        return r.text

    def post_raw(self, path, data=None, json=None, headers=None, **args):
        url = self.baseurl + '/' + path.lstrip('/')
        r = requests.post(url, data=data, json=json, headers=headers, **args)

        return r

    def graphql(self, query, variables=None, headers=None, **args):
        url = self.baseurl + '/graphql'

        request = {"query": query, "variables": variables}

        # logging.warn(request)

        r = requests.post(url, json=request, headers=headers, **args)

        r.raise_for_status()

        json = r.json()
        if 'errors' in json:
            logging.warning(json['errors'])
        return json

# @pytest.fixture(scope="module")
# def server(request, confdir, module_tmpdir, helpers):
#     srv = Server(
#         binary_port=33001,
#         http_port = 8080)
#     srv.start(confdir, module_tmpdir, bootstrap=True)
#     request.addfinalizer(srv.kill)
#     helpers.wait_for(srv.connect, timeout=TARANTOOL_CONNECTION_TIMEOUT)
#     return srv

@pytest.fixture(scope="module")
def cluster(request, confdir, module_tmpdir, helpers):
    cluster = {}
    servers = getattr(request.module, "cluster")
    bootserv = None

    for srv in servers:
        assert srv.roles != None
        assert srv.alias != None
        srv.start(
            workdir="{}/localhost-{}".format(module_tmpdir, srv.binary_port),
        )
        request.addfinalizer(srv.kill)
        helpers.wait_for(srv.ping_udp, timeout=TARANTOOL_CONNECTION_TIMEOUT)
        if len(cluster) == 0:
            bootserv = srv
            helpers.wait_for(srv.graphql, ["{}"],
                timeout=TARANTOOL_CONNECTION_TIMEOUT
            )
        else:
            helpers.wait_for(bootserv.conn.eval,
                ["assert(require('membership').probe_uri('{}'))".format(srv.advertise_uri)],
                timeout=TARANTOOL_CONNECTION_TIMEOUT
            )

        bootserv.graphql(
            query = """
                mutation(
                    $uri: String!,
                    $instance_uuid: String,
                    $replicaset_uuid: String,
                    $roles: [String!]
                ) {
                    join_server(
                        uri: $uri,
                        instance_uuid: $instance_uuid,
                        replicaset_uuid: $replicaset_uuid,
                        roles: $roles
                    )
                }
            """,
            variables = {
                "uri": srv.advertise_uri,
                "instance_uuid": srv.instance_uuid,
                "replicaset_uuid": srv.replicaset_uuid,
                "roles": srv.roles,
            }
        )

        # wait when server is bootstrapped
        helpers.wait_for(srv.connect, timeout=TARANTOOL_CONNECTION_TIMEOUT)

        if len(cluster) != 0:
            # wait for bootserv to see that the new member is alive
            helpers.wait_for(bootserv.conn.eval,
                ["assert(package.loaded['cluster'].is_healthy())"],
                timeout=TARANTOOL_CONNECTION_TIMEOUT
            )

        # speedup tests by amplifying membership message exchange
        srv.conn.eval('require("membership.options").PROTOCOL_PERIOD_SECONDS = 0.2')

        cluster[srv.alias] = srv

    logging.warn('Bootstrapping vshard.router on {}'.format(bootserv.advertise_uri))
    bootserv.conn.eval("""
        local log = require('log')
        log.info('Bootstrapping vshard.router from pytest...')
        package.loaded['cluster'].admin.bootstrap_vshard()
        """)

    return cluster
