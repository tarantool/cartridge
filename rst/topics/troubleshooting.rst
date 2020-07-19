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
