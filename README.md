<a href="http://tarantool.org">
   <img src="https://avatars2.githubusercontent.com/u/2344919?v=2&s=250"
align="right">
</a>

# Tarantool Cartridge &mdash; a framework for distributed applications development

## Table of contents

* [About Tarantool Cartridge](#about-tarantool-cartridge)
* [Getting Started](#getting-started)
  * [Create first application](#create-first-application)
  * [Next stages](#next-stages)
* [Contribution](#contribution)
  * [Building from source](#building-from-source)
  * [Running demo cluster](#running-demo-cluster)
  * [Auto-generated sources](#auto-generated-sources)
  * [Running tests](#running-tests)

## About Tarantool Cartridge

Tarantool Cartridge allows you to easily develop Tarantool-based applications
and run them on one or more Tarantool instances organized into a cluster.

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

Tarantool Cartridge has an external utility called
[cartridge-cli](https://github.com/tarantool/cartridge-cli) which
provides you with utilities and templates to help:

* easily set up a development environment for your applications;
* plug the necessary Lua modules;
* pack the applications in an environment-independent way: together with
  module binaries and Tarantool executables.

## Getting Started

### Create first application

To get a template application that uses Tarantool Cartridge and run it
you need to install `cartridge-cli` utility (supposing that
[Tarantool](https://www.tarantool.io/en/download/) is already
installed).

Long story short, copy-paste it into console:

```sh
tarantoolctl rocks install cartridge-cli
.rocks/bin/cartridge create --name myapp
cd myapp
../.rocks/bin/cartridge build
../.rocks/bin/cartridge start
```

That's all! You can visit [http://localhost:8081](http://localhost:8081)
and see your application Admin Web UI:

<img width="640" alt="cartridge-ui" src="https://user-images.githubusercontent.com/11336358/75786427-52820c00-5d76-11ea-93a4-309623bda70f.png">

### Next stages

**See:**

* Step-by-step
  [getting started guide](https://github.com/tarantool/cartridge-cli/blob/master/examples/getting-started-app/README.md)
  in the ``cartridge-cli`` repository.
* [Documentation page](https://www.tarantool.io/en/doc/2.2/book/cartridge/)
* [API Reference](https://www.tarantool.io/en/rocks/cartridge/1.0/)

## Contribution

From the point of view of cartridge contributor, the workflow differs:
it implies building the project from source (documentation, webui) and
running tests.

### Building from source

Prerequisites:

* ``tarantool``, ``tarantool-dev`` (instructions:
  [https://www.tarantool.io/en/download/?v=1.10](https://www.tarantool.io/en/download/?v=1.10));
* ``git``, ``gcc``, ``cmake``.

The fastest way to build the project is to skip building Web UI:

```sh
CMAKE_DUMMY_WEBUI=true tarantoolctl rocks make
```

But if you want to build frontend too, you'll also need:

* ``nodejs`` >= 8 ([instructions](https://github.com/nodesource/distributions));
* ``npm`` >= 6.

Documentation is generated from source code, but only if `ldoc` and `sphinx` tool is
installed:

```sh
pip install 'sphinx==3.0.3'
tarantoolctl rocks install \
  https://raw.githubusercontent.com/tarantool/LDoc/tarantool/ldoc-scm-2.rockspec \
  --server=http://rocks.moonscript.org
tarantoolctl rocks make
```

### Running demo cluster

There are several example entrypoints which are mostly used for testing,
but can also be useful for demo purposes or experiments:

```sh
tarantoolctl rocks install cartridge-cli
.rocks/bin/cartridge start

# or select specific entrypoint
# .rocks/bin/cartridge start --script ./test/entrypoint/srv_basic.lua
```

It can be accessed through Web UI ([http://localhost:8081](http://localhost:8081))
or with binary protocol:

```sh
tarantoolctl connect admin@localhost:3301
```

If stateful failover mode is also needed, one should launch external
state provider - `stateboard`:

```sh
.rocks/bin/cartridge start --stateboard
```

And set failover params according to `instances.yml`. The defaults are:

* State provider URI: `localhost:4401`;
* Password: `qwerty`.

For more detailed information about `cartridge-cli`
[see here](https://github.com/tarantool/cartridge-cli#readme).

### Auto-generated sources

After GraphQL API is changed one shouldn't forget to fetch the schema
`doc/schema.graphql`:

```sh
npm install graphql-cli@3.0.14
./fetch-schema.sh
```

### Running tests

```sh
# Backend
tarantoolctl rocks install luacheck
tarantoolctl rocks install luatest 0.5.0
.rocks/bin/luacheck .
.rocks/bin/luatest -v --exclude cypress

# Frontend
npm install cypress@3.4.1
./frontend-test.sh
.rocks/bin/luatest -v -p cypress

# Collect coverage
tarantoolctl rocks install luacov
tarantoolctl rocks install luacov-console
.rocks/bin/luatest -v --coverage
.rocks/bin/luacov-console `pwd`
.rocks/bin/luacov-console -s
```
