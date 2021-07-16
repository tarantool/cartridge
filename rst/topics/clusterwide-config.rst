.. _cartridge-config:

-------------------------------------------------------------------------------
Configuring instances
-------------------------------------------------------------------------------

Cartridge orchestrates a distributed system of Tarantool instances -- a
cluster. One of the core concepts is **clusterwide configuration**.
Every instance in a cluster stores a copy of it.

Clusterwide configuration contains options that must be identical on
every cluster node, such as the topology of the cluster, failover and vshard
configuration, authentication parameters and ACLs, and user-defined
configuration.

Clusterwide configuration doesn't provide instance-specific parameters:
ports, workdirs, memory settings, etc.

.. _cartridge-config-basic:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Configuration basics
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Instance configuration includes two sets of parameters:

* :ref:`cartridge.cfg() parameters <cartridge.argparse.cluster_opts>`;
* :ref:`box.cfg() parameters <cartridge.argparse.box_opts>`.

You can set any of these parameters in:

#. Command line arguments.
#. Environment variables.
#. YAML configuration file.
#. ``init.lua`` file.

The order here indicates the priority: command-line arguments override
environment variables, and so forth.

No matter how you :ref:`start the instances <cartridge-run>`, you need to set
the following ``cartridge.cfg()`` parameters for each instance:

* ``advertise_uri`` -- either ``<HOST>:<PORT>``, or ``<HOST>:``, or ``<PORT>``.
  Used by other instances to connect to the current one.
  **DO NOT** specify ``0.0.0.0`` -- this must be
  an external IP address, not a socket bind.
* ``http_port`` -- port to open administrative web interface and API on.
  Defaults to ``8081``.
  To disable it, specify ``"http_enabled": False``.
* ``workdir`` -- a directory where all data will be stored:
  snapshots, wal logs, and ``cartridge`` configuration file.
  Defaults to ``.``.

.. _cartridge-config-cartridge-cli:
.. _cartridge-config-systemctl:

If you start instances using ``cartridge`` CLI or ``systemctl``,
save the configuration as a YAML file, for example:

.. code-block:: kconfig

    my_app.router: {"advertise_uri": "localhost:3301", "http_port": 8080}
    my_app.storage_A: {"advertise_uri": "localhost:3302", "http_enabled": False}
    my_app.storage_B: {"advertise_uri": "localhost:3303", "http_enabled": False}

With ``cartridge`` CLI, you can pass the path to this file as the ``--cfg``
command-line argument to the ``cartridge start`` command -- or specify the path
in ``cartridge`` CLI configuration (in ``./.cartridge.yml`` or ``~/.cartridge.yml``):

.. code-block:: kconfig

    cfg: cartridge.yml
    run_dir: tmp/run
    apps_path: /usr/local/share/tarantool

With ``systemctl``, save the YAML file to ``/etc/tarantool/conf.d/``
(the default ``systemd`` path) or to a location set in the ``TARANTOOL_CFG``
environment variable.

.. _cartridge-config-tarantool:

If you start instances with ``tarantool init.lua``,
you need to pass other configuration options as command-line parameters and
environment variables, for example:

.. code-block:: console

    $ tarantool init.lua --alias router --memtx-memory 100 --workdir "~/db/3301" --advertise_uri "localhost:3301" --http_port "8080"

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Internal representation of clusterwide configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In the file system, clusterwide configuration is represented by a **file tree**.
Inside ``workdir`` of any configured instance you can find the following
directory:

.. code-block:: text

    config/
    ├── auth.yml
    ├── topology.yml
    └── vshard_groups.yml

This is the clusterwide configuration with three default **config sections** --
``auth``, ``topology``, and ``vshard_groups``.

Due to historical reasons clusterwide configuration has two appearances:

* old-style single-file ``config.yml`` with all sections combined, and
* modern multi-file representation mentioned above.

Before cartridge v2.0 it used to look as follows, and this representation is
still used in HTTP API and ``luatest`` helpers.

.. code-block:: yaml

    # config.yml
    ---
    auth: {...}
    topology: {...}
    vshard_groups: {...}
    ...

Beyond these essential sections, clusterwide configuration may be used
for storing some other role-specific data. Clusterwide configuration
supports YAML as well as plain text sections. It can also be organized
in nested subdirectories.

In Lua it's represented by the ``ClusterwideConfig`` object (a table with
metamethods). Refer to the ``cartridge.clusterwide-config`` module
documentation for more details.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Two-phase commit
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Cartridge manages clusterwide configuration to be identical everywhere
using the two-phase commit algorithm implemented in the ``cartridge.twophase``
module. Changes in clusterwide configuration imply applying it on
every instance in the cluster.

Almost every change in cluster parameters triggers a two-phase commit:
joining/expelling a server, editing replica set roles, managing users,
setting failover and vshard configuration.

Two-phase commit requires all instances to be alive and healthy,
otherwise it returns an error.

For more details, please, refer to the
``cartridge.config_patch_clusterwide`` API reference.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Managing role-specific data
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Beside system sections, clusterwide configuration may be used for storing
some other **role-specific data**. It supports YAML as well as plain
text sections. And it can also be organized in nested subdirectories.

Role-specific sections are used by some third-party roles, i.e.
`sharded-queue <https://github.com/tarantool/sharded-queue>`_ and
`cartridge-extensions <https://github.com/tarantool/cartridge-extensions>`_.

A user can influence clusterwide configuration in various ways. You can
alter configuration using Lua, HTTP or GraphQL API. Also there are
`luatest <https://github.com/tarantool/luatest>`_ helpers available.

.. _cartridge-config-http-api:

*******************************************************************************
HTTP API
*******************************************************************************

It works with old-style single-file representation only. It's useful
when there are only few sections needed.

Example:

.. code-block:: console

    cat > config.yml << CONFIG
    ---
    custom_section: {}
    ...
    CONFIG

Upload new config:

.. code-block:: console

    curl -v "localhost:8081/admin/config" -X PUT --data-binary @config.yml

Download it:

.. code-block:: console

    curl -v "localhost:8081/admin/config" -o config.yml

It's suitable for role-specific sections only. System sections
(``topology``, ``auth``, ``vshard_groups``, ``users_acl``) can be neither
uploaded nor downloaded.

If authorization is enabled, use the ``curl`` option ``--user username:password``.

.. _cartridge-config-graphql-api:

*******************************************************************************
GraphQL API
*******************************************************************************

GraphQL API, by contrast, is only suitable for managing plain-text
sections in the modern multi-file appearance. It is mostly used by WebUI,
but sometimes it's also helpful in tests:

.. code-block:: lua

    g.cluster.main_server:graphql({query = [[
        mutation($sections: [ConfigSectionInput!]) {
            cluster {
                config(sections: $sections) {
                    filename
                    content
                }
            }
        }]],
        variables = {sections = {
          {
            filename = 'custom_section.yml',
            content = '---\n{}\n...',
          }
        }}
    })

Unlike HTTP API, GraphQL affects only the sections mentioned in the query. All
the other sections remain unchanged.

Similarly to HTTP API, GraphQL ``cluster {config}`` query isn't suitable for
managing system sections.

.. _cartridge-config-lua-api:

*******************************************************************************
Lua API
*******************************************************************************

It's not the most convenient way to configure third-party role, but it
may be useful for role development. Please, refer to the corresponding API
reference:

* ``cartridge.config_patch_clusterwide``
* ``cartridge.config_get_deepcopy``
* ``cartridge.config_get_readonly``

Example (from ``sharded-queue``, simplified):

.. code-block:: lua

    function create_tube(tube_name, tube_opts)
        local tubes = cartridge.config_get_deepcopy('tubes') or {}
        tubes[tube_name] = tube_opts or {}

        return cartridge.config_patch_clusterwide({tubes = tubes})
    end

    local function validate_config(conf)
        local tubes = conf.tubes or {}
        for tube_name, tube_opts in pairs(tubes) do
            -- validate tube_opts
        end
        return true
    end

    local function apply_config(conf, opts)
        if opts.is_master then
            local tubes = cfg.tubes or {}
            -- create tubes according to the configuration
        end
        return true
    end

.. _cartridge-config-luatest-api:

*******************************************************************************
Luatest helpers
*******************************************************************************

Cartridge test helpers provide methods for configuration management:

* ``cartridge.test-helpers.cluster:upload_config``,
* ``cartridge.test-helpers.cluster:download_config``.

Internally they wrap the HTTP API.

Example:

.. code-block:: lua

    g.before_all(function()
        g.cluster = helpers.Cluster.new(...)
        g.cluster:upload_config({some_section = 'some_value'})
        t.assert_equals(
            g.cluster:download_config(),
            {some_section = 'some_value'}
        )
    end)
