.. _cartridge_readme:

================================================================================
Tarantool Cartridge
================================================================================

A framework for distributed applications development.

.. raw:: html

  <div class="website-hidden">
    <a href="https://github.com/tarantool/cartridge/actions?query=workflow%3A%22Backend+Test%22">
      <img src="https://github.com/tarantool/cartridge/workflows/Backend%20Test/badge.svg">
    </a>
    <a href="https://github.com/tarantool/cartridge/actions?query=workflow%3A%22Frontend+Test%22">
      <img src="https://github.com/tarantool/cartridge/workflows/Frontend%20Test/badge.svg">
    </a>
    <br/>
    <a href="https://t.me/tarantool">
      <img src="https://img.shields.io/badge/telegram%20(EN)-tarantool-blue?logo=telegram&style=social">
    </a>
    <br/>
    <a href="https://t.me/tarantoolru">
      <img src="https://img.shields.io/badge/telegram%20(RU)-tarantoolru-blue?logo=telegram&style=social">
    </a>
  </div>

.. raw:: html

  <p align="center">
    <img
      src="https://github.com/tarantool/cartridge/raw/master/cartridge.png"
      height="400px"
    >
  </p>

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
Bootstrap with topology from remote configuration storage
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* Clone topology module: ``git clone https://github.com/tarantool/topology``
* Install topology module: ``tarantoolctl rocks install topology/topology-scm-1.rockspec``
* Install Cartridge: ``tarantoolctl rocks make``
* Start ``etcd`` instance and put topology configuration to it:
  ``ETCD_URI=http://localhost:2379 ETCD_DATA_DIR=etcd_data ETCD_LISTEN_CLIENT_URLS=${ETCD_URI} ETCD_ADVERTISE_CLIENT_URLS=${ETCD_URI} etcd``
  ``tarantool topology_cartridge.lua``
* Start instance 2: ``./test/entrypoint/srv_basic.lua --instance_name 'cartridge-srv-2' --http-port 8082 --remote_topology_name 'cartridge' --remote_topology_storage 'etcd' --remote_topology_endpoint 'localhost:2379'``
* Start instance 3: ``./test/entrypoint/srv_basic.lua --instance_name 'cartridge-srv-3' --http-port 8082 --remote_topology_name 'cartridge' --remote_topology_storage 'etcd' --remote_topology_endpoint 'localhost:2379'``

TODO:

- [x] create topology that describes configuration described in default YAML file
- [x] pass topology conn parameters via YAML
- [x] embedd topology object to ``ClusterwideConfig`` object
- [x] disable all topology validation checks
- [x] disable vshard conf validation
- [x] use topology api in ``topology.get_fullmesh_replication()``
- [x] use topology api in ``topology.find_server_by_uri()``
- [x] ``topology.cluster_is_healthy()`` -- skipped, because it is used in tests only
- [x] use topology api in ``vshard-utils.get_vshard_config()``
- [x] add support of vshard storage groups in topology module api
- [x] use topology api in ``topology.get_leaders_order()``
- [x] use topology api in ``vshard-utils.can_bootstrap()``
- [x] use topology api in ``vshard-utils.edit_vshard_options()``
- [x] add ``topology.get_instances()`` helper
- [x] add ``topology.get_replicasets()`` helper
- [x] use topology api in ``vshard-utils.get_known_groups()``
- [x] use topology api in ``vshard-utils.set_known_groups()``
- [x] use topology api in ``topology.refine_servers_uri()``
- [x] add ``get_instance_box_cfg()`` to topology module API (required for ``boot_instance()``)
- [x] rewrite ``confapplier.boot_instance()``
- use topology api in ``topology.get_failover_params()``
- use topology api in ``vshard-utils.patch_zone_distances()``
- rewrite all places where used ``get_readonly('topology')``
- rewrite all places where used raw tables like ``topology_old`` and ``topology_new``
- rewrite all places where used raw tables like ``confapplier.get_deepcopy('topology')``
- rewrite all places where used raw tables like  ``get_readonly('vshard_groups')``

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Prerequisites
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To get a template application that uses Tarantool Cartridge and run it,
you need to install several packages:

* ``tarantool`` and ``tarantool-dev``
  (see these `instructions <https://www.tarantool.io/en/download/>`__);
* ``cartridge-cli``
  (see these `instructions <https://github.com/tarantool/cartridge-cli#installation>`__)
* ``git``, ``gcc``, ``cmake`` and ``make``.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Create your first application
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Long story short, copy-paste this into the console:

.. code-block:: bash

    cartridge create --name myapp
    cd myapp
    cartridge build
    cartridge start -d
    cartridge replicasets setup --bootstrap-vshard


That's all! Now you can visit http://localhost:8081 and see your application's
Admin Web UI:

.. image:: https://user-images.githubusercontent.com/32142520/109290877-3d30a800-7839-11eb-8fcf-8b3de1237a3b.png
   :align: center

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
Contributing
--------------------------------------------------------------------------------

The most essential contribution is your *feedback*, don't hesitate to
`open an issue <https://github.com/tarantool/cartridge/issues/new>`_.
If you'd like to propose some changes in code, see the contribution
`guide <https://github.com/tarantool/cartridge/blob/master/CONTRIBUTING.rst>`_.

.. |--| unicode:: U+2013   .. en dash
.. |---| unicode:: U+2014  .. em dash, trimming surrounding whitespace
   :trim:
