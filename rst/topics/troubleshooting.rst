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

Here is workaround for this problem:

#.  Shut down instances, which uri must be changed
#.  Start these instances on a new IP:Port and set
    `replication_connect_quorum <https://www.tarantool.io/en/doc/1.10/reference/configuration/#cfg-replication-replication-connect-timeout>`_
    = 0 (otherwise these instances will be broken and they will stay
    at ``ConnectingFullmesh`` state - this means that quorum lost).

    There are two ways to set ``replication_connect_quorum=0``:

    * Set environment variable ``TARANTOOL_REPLICATION_CONNECT_QUORUM=0``
      before starting these instances
    * Or directly connect to these instances, after they've started through
      ``tarantoolct`` and call ``box.cfg()`` like follow:

      .. code-block:: bash

          tarantoolctl connect user:password@instance_advertise_new_uri

      .. code-block:: lua

          box.cfg({replication_connect_quorum = 0})

#.  When quorum returned, call :ref:`edit_topology <cartridge.admin_edit_topology>`
    from any instance (via lua-api or GraphQL) with uuid of changed instances and
    their new uri

    Here is an example:

    .. code-block:: lua

        cartridge = require('cartridge')
        membership = require('membership')

        -- get members list
        members = membership.members()


        -- find uuid and uri of dead instances
        dead_members = {}
        for _, member in pairs(members) do
            if member.status == 'dead' then
                dead_members[member.uri] = member.payload.uuid
            end
        end

        -- array of servers for edit_topology call
        edit_server_list = {}

        -- search instances which uri changed
        -- it's an instances which presents at members map twice
        -- (they have the same uuid, but different uri
        -- and instance with old uri has status dead)
        for dead_uri, dead_uuid in pairs(dead_members) do
            for _, member in pairs(members) do
                if member.status == 'alive'
                    and member.payload.uuid == dead_uuid
                    and member.uri ~= dead_uri
                then
                    table.insert(edit_server_list, {uuid = dead_uuid, uri = member.uri})
                end
            end
        end

        -- call edit_topology
        cartridge.admin_edit_topology({servers = edit_server_list})

    .. NOTE::
        If you restarted the whole cluster, script above won't help (membership
        table dropped and there is no payload for dead instances). Here is one
        way is to call ``edit_topology`` with manually specified uuid and new_uri of
        changed instances

    Here is expamples how to update call ``edit_topology`` after
    restarting whole cluster:

    Here is an example with lua-api:

    .. code-block:: lua

        cartridge = require('cartridge')

        cartridge.admin_edit_topology({
            servers = {
                {
                    uuid: instance1_uuid,
                    uri: instance1_new_uri,
                },
                ...
            }
        })


    Here is an example with GraphQL:

    .. code-block:: graphql

        mutation {
            cluster {
                edit_topology(servers: [{uuid: instance1_uuid, uri: instance1_new_uri} ...])
                {}
            }
        }
    

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
