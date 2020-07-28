.. _cartridge-troubleshooting:

================================================================================
Troubleshooting
================================================================================

First of all, see the similar
`guide <https://www.tarantool.io/en/doc/latest/book/admin/troubleshoot/>`_
in the Tarantool manual. Below you can find other cartridge-specific
problems considered.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Editing clusterwide configuration in WebUI returns an error
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Examples**:

* ``NetboxConnectError: "localhost:3302": Connection refused``;
* ``Prepare2pcError: Instance state is OperationError, can't apply config in this state``.

**The root problem**: all cluster instances are equal, and all of them store a
copy of  clusterwide configuration, which must be the same. If an
instance degrades (can't accept new configuration) - the quorum is lost.
It prevents further config modifications to avoid inconsistency.

But sometimes inconsistency is needed to repair the system at least
partially and temporarily. It can be achieved by disabling degraded
instances.

**Solution**

#.  Connect to console of alive instance

    .. code-block:: bash

        tarantoolctl connect user:password@instance_advertise_uri

#.  Inspect what's going on

    .. code-block:: lua

        cartridge = require('cartridge')
        report = {}
        for _, srv in pairs(cartridge.admin_get_servers()) do
            report[srv.uuid] = {uri = srv.uri, status = srv.status, message = srv.message}
        end
        return report

#.  If you're ready to proceed, run the following snippet. It'll disable
    all instances which are not healthy. After that, you could operate
    WebUI as usual.

    .. code-block:: lua

        disable_list = {}
        for uuid, srv in pairs(report) do
            if srv.status ~= 'healthy' then
               table.insert(disable_list, uuid)
            end
        end
        return cartridge.admin_disable_servers(disable_list)

#.  And when it's necessary to bring disabled instances back, re-enable
    them in a similar manner:

    .. code-block:: lua

        cartridge = require('cartridge')
        enable_list = {}
        for _, srv in pairs(cartridge.admin_get_servers()) do
            if srv.disabled then
               table.insert(enable_list, srv.uuid)
            end
        end
        return cartridge.admin_enable_servers(enable_list)


.. _troubleshooting-stuck-connecting-fullmesh:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
An instance is stuck in ConnectingFullmesh state upon restart
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Example**:

.. image:: images/stuck-connecting-fullmesh.png

**The root problem**: after restart, the instance tries to connect all
its replicas and remains in ``ConnectingFullmesh`` state until it
succeeds. If it can't (due to replica URI unavailability or for any
other reason) — it's stuck forever.

**Solution**:

Set `replication_connect_quorum <https://www.tarantool.io/en/doc/latest/reference/configuration/#cfg-replication-replication-connect-quorum>`_ option to zero. In
may be accomplished in two ways:

* By restarting it with corresponding option set
  (in environment variables or in the
  :ref:`instance configuration file <cartridge-run-systemctl-config>`);
* Or without restart — by running the following one-liner:

    .. code-block:: bash

        echo "box.cfg({replication_connect_quorum = 0})" | tarantoolctl connect <advertise_uri>


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
I want to run instance with new advertise_uri
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**The root problem**: ``advertise_uri`` parameter is persisted in
clusterwide configuration. Even if it changes upon restart, the rest of
cluster keeps using an old one, and cluster may behave "strange".

**The solution**:

The clusterwide configuration should be updated.


#.  Make sure all instances are running and not stuck in ConnectingFullmesh
    state (see :ref:`above <troubleshooting-stuck-connecting-fullmesh>`).

#.  Make sure all instances have discovered each other (i.e. they look
    healthy in WebUI)

#.  Run the following snippet in tarantool console. It'll prepare a
    patch for the clusterwide configuration.

    .. code-block:: lua

        cartridge = require('cartridge')
        members = require('membership').members()

        edit_list = {}
        changelog = {}
        for _, srv in pairs(cartridge.admin_get_servers()) do
            for _, m in pairs(members) do
                if m.status == 'alive'
                and m.payload.uuid == srv.uuid
                and m.uri ~= srv.uri
                then
                    table.insert(edit_list, {uuid = srv.uuid, uri = m.uri})
                    table.insert(changelog, string.format('%s -> %s (%s)', srv.uri, m.uri, m.payload.alias))
                    break
                end
            end
        end
        return changelog

    As a result you'll see a brief summary like following:

    .. code-block:: tarantoolsession

        localhost:3301> return changelog
        ---
        - - localhost:13301 -> localhost:3301 (srv-1)
          - localhost:13302 -> localhost:3302 (srv-2)
          - localhost:13303 -> localhost:3303 (srv-3)
          - localhost:13304 -> localhost:3304 (srv-4)
          - localhost:13305 -> localhost:3305 (srv-5)
        ...

#.  Finally, apply that patch:

    .. code-block:: lua

        cartridge.admin_edit_topology({servers = edit_list})

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The cluster is doomed, I've edited config by hands. How do I reload it?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

I hope you're asure it's quite dangerous and you know what you're doing.
There's some useful information about :ref:`clusterwide configuration <cartridge-config>`
anatomy and "normal" management API. But if you still want to reload
it manually, then do (in tarantool console):

.. code-block:: lua

    -- load config from filesystem
    clusterwidie_config = require('cartridge.clusterwide-config')
    cfg = clusterwidie_config.load('./config')
    cfg:lock()

    confapplier = require('cartridge.confapplier')
    confapplier.apply_config(cfg)

This snippet reloads configuretion on a single instance. All other instances
continue operate as before.

.. NOTE::

    In case of further config modifications are made with two-phase
    commit (e.g. via WebUI or with Lua API), the active config of an
    active instance will be spread across the cluster.
