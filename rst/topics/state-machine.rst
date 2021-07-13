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
(SWIM), checks working directory and depending on enters one
of the following states:

..  uml::  ./uml/InitialState.puml

~~~~~~~~~~~~
Unconfigured
~~~~~~~~~~~~

If the working directory is clean and neither snapshots nor cluster-wide
configuration files exist, the instance enters ``Unconfigured`` state.

The instance starts to accept iproto requests (Tarantool binary
protocol) and remains in the state until the user decides to join it to a
cluster (to create replicaset or join the existing one).

After that, the instance moves to ``BootstrappingBox`` state.

..  uml::  ./uml/Unconfigured.puml


~~~~~~~~~~~
ConfigFound
~~~~~~~~~~~


The instance enters the ``ConfigFound`` state if all configuration files and
snapshots are found. The files and snapshots are not loaded.
Config is to be downloaded and validated. On success,
the state enters the ``ConfigLoaded`` state.
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


Instance initialization error can be caused by the following events:

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
state to ``BootError``. If there is no replicaset in cluster-wide
config, the instance will set the state to ``BootError``. If
everything is ok, the instance is set to ``ConnectingFullmesh``.

..  uml::  ./uml/Recovery.puml

~~~~~~~~~~~~~~~~~~
RecoveringSnapshot
~~~~~~~~~~~~~~~~~~


If snapshots are present, ``box.cfg`` will start a recovery process.
After that, the process is similar to ``BootstrappingBox``.

~~~~~~~~~
BootError
~~~~~~~~~


This state can be caused by following events:

*  Failed binding to binary port for iproto usage
*  Server is missing in cluster-wide config
*  Replicaset is missing in cluster-wide config
*  Failed replication configuration

~~~~~~~~~~~~~~~~~~
ConnectingFullmesh
~~~~~~~~~~~~~~~~~~


During this state, a configuration of servers and replicasets is being
performed. Eventually, cluster topology, which is described in config, is
implemented. But in case of an error instance the state is changed to
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


The state of role configuration. Instance can be set to this state while
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

Error while role configuration.
