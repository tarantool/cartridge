<a href="http://tarantool.org">
   <img src="https://avatars2.githubusercontent.com/u/2344919?v=2&s=250"
align="right">
</a>

# Tarantool Cartridge &mdash; a framework for distributed applications development

[![pipeline status](https://gitlab.com/tarantool/cartridge/badges/master/pipeline.svg)](https://gitlab.com/tarantool/cartridge/commits/master)

## Table of contents

* [About Tarantool Cartridge](#about-tarantool-cartridge)
* [Installation](#installation)
* [Usage](#usage)
* [Contribution](#contribution)
  * [Building from source](#building-from-source)
  * [Running tests](#running-tests)

## About Tarantool Cartridge

Tarantool Cartridge allows you to easily develop Tarantool-based applications
and run them on one or more Tarantool instances organized into a cluster.

As a software development kit (SDK), Tarantool Cartridge provides you with
utilities and templates to help:

* easily set up a development environment for your applications;
* plug the necessary Lua modules;
* pack the applications in an environment-independent way: together with
   module binaries and Tarantool executables.

As a cluster management tool, Tarantool Cartridge provides your cluster-aware
applications with the following key benefits:

* horizontal scalability and load balancing via built-in automatic sharding;
* asynchronous replication;
* automatic failover;
* centralized cluster control via GUI or API;
* automatic configuration synchronization;
* instance functionality segregation.

A Tarantool Cartridge cluster can segregate functionality between instances via
built-in and custom (user-defined) **cluster roles**. You can toggle instances
on and off on the fly during cluster operation. This allows you to put
different types of workloads (e.g., compute- and transaction-intensive ones) on
different physical servers with dedicated hardware.

## Installation

```shell
you@yourmachine $ tarantoolctl rocks install cartridge
```

This will install ``cartridge`` to ``~/.rocks``.

## Usage

This repository contains the framework itself.

To build a Tarantool cluster app, you'll also need the
[cartridge-cli](https://github.com/tarantool/cartridge-cli/) utility.

See a step-by-step
[getting started guide](https://github.com/tarantool/cartridge-cli/blob/master/examples/getting-started-app/README.md)
in the ``cartridge-cli`` repository.

## Contribution

### Building from source

Prerequisites:

* ``tarantool``, ``tarantool-dev`` ([instructions](https://www.tarantool.io/en/download/?v=1.10));
* ``git``, ``gcc``, ``cmake``.

To build and test ``cartridge`` locally, you'll also need:

* ``nodejs`` >= 8 ([instructions](https://github.com/nodesource/distributions));
* ``npm`` >= 6;
* ``python``, ``pip``.

To build the front end, say:

```sh
tarantoolctl rocks make
```

To build the API documentation, say:

```sh
tarantoolctl rocks install ldoc --server=http://rocks.moonscript.org
tarantoolctl rocks make BUILD_DOC=YES
```

### Running tests

First, install testing dependencies:

```sh
pip install -r test/integration/requirements.txt
tarantoolctl rocks install luacheck
tarantoolctl rocks install luacov
tarantoolctl rocks install luacov-console
tarantoolctl rocks install luatest 0.2.2
```

Then run tests:

```sh
pytest -v
./run-test.sh
```
