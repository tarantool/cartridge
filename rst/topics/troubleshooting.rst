.. _cartridge-troubleshooting:

-------------------------------------------------------------------------------
Troubleshooting
-------------------------------------------------------------------------------

First of all, see the
`troubleshooting guide <https://www.tarantool.io/en/doc/latest/book/admin/troubleshoot/>`_.
in the Tarantool manual. Also there are other cartridge-specific
problems considered below.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
What to do if there are two or more crashed instances in cluster and quorum lost?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

What is ``quorum``: each cluster instance is a member of cluster quorum,
so cluster quorum is a set of it's instances.

What is ``lost quorum`` problem: quorum requires all of it's instances to
be alive, so if one of instance is broken (for example instance was crashed/stopped
or there is lost connection to instance) then quorum becomes lost.

To reslove ``lost quorum`` problem follow next steps:

* Firsly need to know uuids of crashed instances
* After detecting uuids of crashed instances, disable them from alive instance.

There are two ways to get servers list and disabling them: Graphql and lua-api.

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Examples:
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Resolving this problem via Graphql:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

.. code-block:: graphql

    # Send follwing graphql requests to alive instance

    # Get list uuid and statuses of cluster servers
    query {
        servers {
            status
            uuid
        }
    }

    # After that we need to copy uuid of crashed servers
    # and paste them to following mutation

    # Disable servers
    mutation {
        cluster {
            disable_servers(uuids: ["uuid1", ...]) {}
        }
    }

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Resolving this problem via lua-api:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

.. code-block:: bash

    # connect to console of alive instance
    tarantoolctl connect user:password@instance_advertise_uri

.. code-block:: lua

    cartridge = require('cartridge')
    servers = cartridge.admin_get_servers()
    uuids = {} -- array of broken servers
    for _, server in ipairs(servers) do
        if server.status == 'unreachable' then
           table.insert(uuids, server.uuid)
        end
    end
    cartridge.admin_disable_servers(uuids)

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changing IP:Port configuration of instances in cluster
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Currently cartridge doesn't provide api for changing instance IP:Port, so there is
only one method - do it manually.

There are two ways to do it:

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
First way is slow, because it needs to stop whole cluster:
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#.  Stop whole cluster
#.  Go to cluster config folder
#.  Change topology section of instance config for each instacne
    of cluster (``cluster_cfg_dir/instance_n_cfg/topology.yml``).
    Modify ``servers`` section of topology.yml by seting new IP:Port
    for required servers.

    .. code-block:: yaml

        # topology.yml
        replicasets:
            ...
        servers:
            uuid1:
                uri: # change this field

#.  Start all cluster (and don't forget to start required instances
    on a new IP:Port)

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Second way needs to stop only one instance of cluster:
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#.  Stop an instance which uri need to be changed
#.  Change it's config file ``topology.yml`` (as described above)
#.  Start this instance on a new IP:Port,
#.  Call :ref:`cartridge.admin_edit_topology <cartridge.admin_edit_topology>`
    from this instance with ``uuid`` of this instance and it's new ``IP:Port``.

.. NOTE::

    Be aware, while you have stopped instance, quorum is broken (so you can't apply
    config on cluster), but when instance become alive quorum becomes alive too

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Here is an examples, how to call ``admin_edit_topology``:
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Through Graphql:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

.. code-block:: graphql

    # Send follwing graphql requests from modified instance

    mutation {
        cluster {
            edit_topology(servers: [{uuid: instance_uuid, uri: instance_uri}])
            {}
        }
    }

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Through lua-api:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

.. code-block:: bash

    # connect to console to instance, which uri changed
    tarantoolctl connect user:password@instance_advertise_uri

.. code-block:: lua

    cartridge = require('cartridge')
    cartridge.admin_edit_topology({
        servers = {{
            uuid = box.info.uuid, # instance_uuid
            uri = new_instance_uri
        }}
    })

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Delete repliscaset from cluster
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To delete replicaset from cluster entirely, expell all instances of this
replicaset and it will lead to deleting replicaset from cluster.
If instance has role ``vshard-storage`` then deactivate this replicaset.

.. NOTE::

    You can't delete last replicaset with ``vshard-storage`` role

Read next articles about:

* :ref:`Deactivating replicasets <cartridge-deactivate-replica-set>`
* :ref:`Expelling instances <cartridge-expelling-instances>`

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

There is no API for changing config for a single instance, so there will be workaround for 
this problem:

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
**Update config through instance console**
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

#.  Connect to instance console via ``tarantoolctl``
#.  Get an active instance config via ``cartridge.confapplier.get_active_config()``
    to see :ref:`cartridge.confapplier <cartridge.confapplier>`
#.  Make a copy of active_config
#.  Modify config as it's needed, use ``cfg:set_plaintext('key', value)`` method
#.  Lock this config ``cfg:lock()`` (because it's needed to apply)
#.  Call ``confapplier.apply_config()`` to apply new config on this instance
#.  If you want to save your new config, just call ``cartridge.clusterwidie_config.save(cfg, path)``


For example:

.. code-block:: bash

    # connect to console of required instance
    tarantoolctl connect user:password@instance_advertise_uri

.. code-block:: lua

    confapplier = require('cartridge.confapplier')
    cfg = confapplier.get_active_config()
    -- get copy of active config
    new_cfg = cfg:copy()
    -- set new attribute to config copy
    new_cfg:set_plaintext('new_attribute.yml', 10)
    -- lock config for futher apply
    new_cfg:lock()
    -- apply_config on instance
    confapplier.apply_config(new_cfg);

    -- for example save config on filesystem
    clusterwidie_config = require('cartridge.clusterwidie-config')
    clusterwidie_config.save(new_cfg, some_path)

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
**Update config by changing it's on filesystem**
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

If you've changed config on filesystem and want to load config do next steps

#. Connect to instance console via ``tarantoolctl``,
#. Load config from filesystem via ``cartridge.clusterwidie_config.load(path)``
#. Lock this config
#. Apply this config on current instance via ``confapplier.apply_config(new_cfg)``

For example:

.. code-block:: bash

    # connect to console of required instance
    tarantoolctl connect user:password@instance_advertise_uri

.. code-block:: lua

    confapplier = require('cartridge.confapplier')
    clusterwidie_config = require('cartridge.clusterwidie-config')
    -- load config from filesystem
    loaded_config = clusterwidie_config.load(some_path)
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
