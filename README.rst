.. _cartridge_readme:

================================================================================
Tarantool Cartridge: a framework for distributed applications development
================================================================================

.. contents::

--------------------------------------------------------------------------------
About Tarantool Cartridge
--------------------------------------------------------------------------------

Tarantool Cartridge allows you to easily develop Tarantool-based applications
and run them on one or more Tarantool instances organized into a cluster.

This is the recommended alternative to the
`old-school practices <https://www.tarantool.io/en/doc/latest/book/app_server/>`_
of application development for Tarantool.

As a **software development kit (SDK)**, Tarantool Cartridge provides you with
utilities and an application template to help:

* easily set up a development environment for your applications;
* plug the necessary Lua modules.

The resulting package can be installed and started on one or multiple servers
as one or multiple instantiated services |--| independent or organized into a
**cluster**.

A Tarantool cluster is a collection of Tarantool instances acting in concert.
While a single Tarantool instance can leverage the performance of a single server
and is vulnerable to failure, the cluster spans multiple servers, utilizes their
cumulative CPU power, and is fault-tolerant.

To fully utilize the capabilities of a Tarantool cluster, you need to
develop applications keeping in mind they are to run in a cluster environment.

As a **cluster management tool**, Tarantool Cartridge provides your cluster-aware
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
`cartridge-cli <https://github.com/tarantool/cartridge-cli>`_ which
provides you with utilities and an application template to help:

* easily set up a development environment for your applications;
* plug the necessary Lua modules;
* pack the applications in an environment-independent way: together with
  module binaries and Tarantool executables.

--------------------------------------------------------------------------------
Getting started
--------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Prerequisites
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To get a template application that uses Tarantool Cartridge and run it,
you need to install several packages:

* ``tarantool`` and ``tarantool-dev``
  (see these `instructions <https://www.tarantool.io/en/download/>`_);
* ``cartridge-cli``
  (see these `instructions <https://github.com/tarantool/cartridge-cli#installation>`_)
* ``git``, ``gcc``, ``cmake`` and ``make``.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Create your first application
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Long story short, copy-paste this into the console:

.. code-block:: bash

    cartridge create --name myapp
    cd myapp
    cartridge build
    cartridge start

That's all! Now you can visit http://localhost:8081 and see your application's
Admin Web UI:

.. image:: https://user-images.githubusercontent.com/11336358/75786427-52820c00-5d76-11ea-93a4-309623bda70f.png
   :align: center
   :scale: 100%

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Next steps
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

See:

* A more detailed
  `getting started guide <https://www.tarantool.io/en/doc/latest/getting_started/getting_started_cartridge/>`_
* More
  `application examples <https://github.com/tarantool/examples>`_
* `Cartridge documentation <https://www.tarantool.io/en/doc/latest/book/cartridge/>`_
* `Cartridge API reference <https://www.tarantool.io/en/doc/latest/book/cartridge/cartridge_api/>`_

--------------------------------------------------------------------------------
Contribution
--------------------------------------------------------------------------------

The workflow for Cartridge contributors may be different from that for Cartridge
users as it it implies building the project from source (documentation, Web UI)
and running tests.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Building from source
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The fastest way to build the project is to skip building the Web UI:

.. code-block:: bash

    CMAKE_DUMMY_WEBUI=true tarantoolctl rocks make

But if you want to build the frontend too, you'll also need:

* ``nodejs`` >= 8 (see these `instructions <https://github.com/nodesource/distributions>`_);
* ``npm`` >= 6.

Documentation is generated from source code, but only if the ``ldoc`` and ``sphinx``
tools are installed:

.. code-block:: bash

    pip install 'sphinx==3.0.3'
    tarantoolctl rocks install \
      https://raw.githubusercontent.com/tarantool/LDoc/tarantool/ldoc-scm-2.rockspec \
      --server=http://rocks.moonscript.org
    tarantoolctl rocks make

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Running a demo cluster
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

There are several example entry points which are mostly used for testing,
but can also be useful for demo purposes or experiments:

.. code-block:: bash

    cartridge start

    # or select a specific entry point
    # cartridge start --script ./test/entrypoint/srv_vshardless.lua

It can be accessed through the Web UI (http://localhost:8081)
or via the binary protocol:

.. code-block:: bash

    tarantoolctl connect admin@localhost:3301

If you also need the stateful failover mode, launch an external state provider
|--| ``stateboard``:

.. code-block:: bash

    cartridge start --stateboard

And set failover parameters according to ``instances.yml``. The defaults are:

* State provider URI: ``localhost:4401``;
* Password: ``qwerty``.

For more details about ``cartridge-cli``, see its
`usage <https://github.com/tarantool/cartridge-cli#usage>`_.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Auto-generated sources
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

After the GraphQL API is changed, don't forget to fetch the schema
``doc/schema.graphql``:

.. code-block:: bash

    npm install graphql-cli@3.0.14
    ./fetch-schema.sh

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Running tests
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

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

.. |--| unicode:: U+2013   .. en dash
.. |---| unicode:: U+2014  .. em dash, trimming surrounding whitespace
   :trim:
