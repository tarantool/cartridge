<a href="http://tarantool.org">
   <img src="https://avatars2.githubusercontent.com/u/2344919?v=2&s=250"
align="right">
</a>

# Tarantool Cartridge &mdash; a framework for distributed applications development

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
* ``npm install cypress@3.4.1``;
* ``npm install graphql-cli@3.0.14``;
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

### Runnig demo

At first, you need to install `cartridge-cli`

```sh
tarantoolctl rocks install cartridge-cli
```

Then you need to start application:

```sh
.rocks/bin/cartridge start
```

If you want to run application with another settings, you can specify `script` option:

```sh
.rocks/bin/cartridge start --script path_to_script
```

For more detailed information about `cartridge-cli` read [a link](https://github.com/tarantool/cartridge-cli#readme)


### Running tests

First, install testing dependencies:

```sh
pip install -r test/integration/requirements.txt
tarantoolctl rocks install luacheck
tarantoolctl rocks install luacov
tarantoolctl rocks install luacov-console
tarantoolctl rocks install luatest 0.4.0
```

Then run tests:

```sh
pytest -v
./run-test.sh
```
