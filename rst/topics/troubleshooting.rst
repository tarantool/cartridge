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

* Firsly need to know uuids of crashed instances
* After detecting uuids of crashed instances, disable them from alive instance.

There are two ways to get servers list and disabling them: Graphql and lua-api.

Examples:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
