..  _cartridge-state-machine:

--------------------------
Cluster instance lifecycle
--------------------------

Every instance in the cluster has an internal state machine.
It helps manage cluster operation and describe a distributed system
simpler.

..  uml::  ./uml/state-machine.puml


Instance lifecycle starts with a ``cartridge.cfg`` call.
During the initialization,
Cartridge instance binds TCP (iproto) and UDP sockets
(SWIM), checks working directory.
Depending on the result, it enters one
of the following states:

..  uml::  ./uml/InitialState.puml

~~~~~~~~~~~~
Unconfigured
~~~~~~~~~~~~

If the working directory is clean and neither snapshots nor cluster-wide
configuration files exist, the instance enters the ``Unconfigured`` state.

The instance starts to accept iproto requests (Tarantool binary
protocol) and remains in the state until the user decides to join it to a
cluster (to create replicaset or join an existing one).

After that, the instance moves to the ``BootstrappingBox`` state.

..  uml::  ./uml/Unconfigured.puml


~~~~~~~~~~~
ConfigFound
~~~~~~~~~~~

If the instance finds all configuration files and snapshots, it enters the ``ConfigFound`` state.
The instance does not load the files and snapshots yet, because it will download and validate the config first.
On success, the state enters the ``ConfigLoaded`` state.
On failure, it will move to the ``InitError`` state.

..  uml::  ./uml/ConfigFound.puml


~~~~~~~~~~~~
ConfigLoaded
~~~~~~~~~~~~


Config is found, loaded and validated. The next step is instance
configuring. If there are any snapshots, the instance will change its
state to ``RecoveringSnapshot``. Otherwise, it will move to
``BootstrappingBox`` state. By default, all instances start in read-only mode
and don’t start listening until bootstrap/recovery finishes.

..  uml::  ./uml/ConfigLoaded.puml


~~~~~~~~~
InitError
~~~~~~~~~


The following events can cause instance initialization error:

*  Error occurred during ``cartridge.remote-control``’s connection to
   binary port
*  Missing ``config.yml`` from workdir (``tmp/``), while snapshots are
   present
*  Error while loading configuration from disk
*  Invalid config - Server is not present in the cluster configuration

~~~~~~~~~~~~~~~~
BootstrappingBox
~~~~~~~~~~~~~~~~


Configuring arguments for ``box.cfg`` if snapshots or config files are
not present. ``box.cfg`` execution. Setting up users and stopping
``remote-control``. The instance will try to start listening to full-featured
iproto protocol. In case of failed attempt instance will change its
state to ``BootError``. On success, the instance enters the ``ConnectingFullmesh`` state.
If there is no replicaset in cluster-wide
config, the instance will set the state to ``BootError``.

..  uml::  ./uml/Recovery.puml

~~~~~~~~~~~~~~~~~~
RecoveringSnapshot
~~~~~~~~~~~~~~~~~~


If snapshots are present, ``box.cfg`` will start a recovery process.
After that, the process is similar to ``BootstrappingBox``.

~~~~~~~~~
BootError
~~~~~~~~~


This state can be caused by the following events:

*  Failed binding to binary port for iproto usage
*  Server is missing in cluster-wide config
*  Replicaset is missing in cluster-wide config
*  Failed replication configuration

~~~~~~~~~~~~~~~~~~
ConnectingFullmesh
~~~~~~~~~~~~~~~~~~


During this state, a configuration of servers and replicasets is being
performed. Eventually, cluster topology, which is described in the config, is
implemented. But in case of an error instance, the state moves to
``BootError``. Otherwise, it proceeds to configuring roles.

..  uml::  ./uml/ConnectingFullmesh.puml


~~~~~~~~~~~~~
BoxConfigured
~~~~~~~~~~~~~


This state follows the successful configuration of replicasets and cluster
topology. The next step is a role configuration.

~~~~~~~~~~~~~~~~
ConfiguringRoles
~~~~~~~~~~~~~~~~


The state of role configuration. Instance enters this state while
initial setup, after failover trigger(``failover.lua``) or after
altering cluster-wide config(``twophase.lua``).

..  uml:: ./uml/ConfiguringRoles.puml


~~~~~~~~~~~~~~~
RolesConfigured
~~~~~~~~~~~~~~~

Successful role configuration.

~~~~~~~~~~~~~~
OperationError
~~~~~~~~~~~~~~

Error during role configuration.
