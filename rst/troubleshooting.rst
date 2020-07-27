.. _cartridge-troubleshooting:

-------------------------------------------------------------------------------
Troubleshooting
-------------------------------------------------------------------------------

First of all, see the
`troubleshooting guide <https://www.tarantool.io/en/doc/latest/book/admin/troubleshoot/>`_.
in the Tarantool manual. Also there are other cartridge-specific
problems considered below.


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
Delete replicaset from cluster
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To delete replicaset from cluster entirely, expell all instances of this
replicaset and it will lead to deleting replicaset from cluster.
If instance has role ``vshard-storage`` then deactivate this replicaset.

.. NOTE::

    You can't delete last replicaset with ``vshard-storage`` role

Read this articles before you start:

* :ref:`Deactivating replicasets <cartridge-deactivate-replica-set>`
* :ref:`Expelling instances <cartridge-expelling-instances>`

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Resolving this problem
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#.  If replicaset has vshard-storage role (and it isn't last in cluster),
    we need :ref:`deactivate replicaset <cartridge-deactivate-replica-set>` (you
    can do it from ``webui``) and wait
    :ref:`data rebalancing <cartridge-rebalance-data>` (also you can see that
    rebalancing finised in ``webui`` - there is no buckets on replicaset
    instances). After that follow next steps.
#.  Get all servers uuid's of replicaset which must be deleted.
#.  Expell whole servers of this replicaset by their uuid's

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Here is an example of expelling servers (after rebalancing process finished):
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Via lua-api:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

.. code-block:: bash

    # connect to instance, that won't be deleted
    tarantoolctl connect user:password@instance_uri

.. code-block:: lua

    cartridge = require('cartridge')

    -- set required replicaset uuid
    replicaset_uuid = 'deleting_replicaset_uuid'

    replicaset = cartridge.admin_get_replicasets(replicaset_uuid)[1] or {}

    servers_to_expell = {}
    for _, server in pairs(replicaset.servers) do
        table.insert(servers_to_expell, {uuid = server.uuid, expelled = true})
    end

    cartridge.admin_edit_topology({servers = servers_to_expell})

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Via GraphQL:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

.. code-block:: graphql

    # Send follwing graphql requests from instance that won't be deleted

    # Get list of replicaset servers by replicaset_uuid
    query {
        replicasets(uuid: replicaset_uuid) {
            servers {
                uuid
            }
        }
    }

    # Call this mutation with servers uuid from previous request
    mutation {
	    cluster {
            edit_topology(servers: [
                {uuid: server1_uuid,  expelled: true}, ...]
                ) {}
        }
    }

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Work with cluster config
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Before you start, please read related article about :ref:`cluster config <cartridge-config>`.

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
How to update config on the whole cluster?
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Here is an examples of updating config:

* :ref:`HTTP API <cartridge-config-http-api>`
* :ref:`GraphQL API <cartridge-config-graphql-api>`
* :ref:`Lua API <cartridge-config-lua-api>`
* :ref:`Luatest API <cartridge-config-luatest-api>`

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
How to update config on a single instance?
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

There is no API for changing config for a single instance, so there is one tested
workaround for this problem

#.  Modify config of required instance (in place), which stored on filesystem
#.  Connect to console of this instance via ``tarantoolctl``,
#.  Load config from filesystem via
    :ref:`cartridge.clusterwidie_config.load() <cartridge.clusterwide-config.load>`
#.  Lock this config
#.  Apply this config on current instance via
    :ref:`cartridge.confapplier.apply_config() <cartridge.confapplier.apply_config>`

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Example reloading config from filesystem:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

.. code-block:: bash

    # for example add new_attribute.yml to instance config
    echo 'value' > instance_config_path/new_attribute.yml

    # connect to console of required instance
    tarantoolctl connect user:password@instance_advertise_uri

.. code-block:: lua

    fio = require('fio')
    confapplier = require('cartridge.confapplier')
    clusterwidie_config = require('cartridge.clusterwide-config')

    -- get instance working directory
    workdir = confapplier.get_workdir()

    -- get instance config path
    config_filename = fio.pathjoin(workdir, 'config')

    -- load config from filesystem
    loaded_config = clusterwidie_config.load(config_filename)
    -- lock config for futher apply
    loaded_config:lock()
    -- apply_config on instance
    confapplier.apply_config(loaded_config)

.. NOTE::
    After this manipulation required instance will work with new config, and cluster
    config will be at inconsistent state (config on this instance differs from config
    at other cluster instances).

    Also if current instance will initiate updating cluster config, then all cluster
    instances will have the same config as on this instance, but if another cluster
    instance initiate updating cluster config then local changes for this instance
    will be dropped.
