# Cluster instance lifecycle.

Every instance in cluster possesses internal state machine. It helps to
manage cluster operation and makes describing distributed system
simpler.

![](images/state-machine/all.svg)

Instance lifecycle starts from `cartridge.cfg` call. Cartridge instance
during initialization binds TCP (iproto) and UDP sockets (SWIM), checks
working directory and depending on circumstances continues to one of the
following states:

![](images/state-machine/InitialState.svg)

## Unconfigured

If working directory is clean and neither snapshots nor clusterwide
configuration files exist the instance enters `Unconfigured` state.

The instance starts accepting iproto requests (Tarantool binary
protocol) and remains in the state until user decides to join it to the
cluster (either to create replicaset or join the existing one).

After that instance moves to `BootstrappingBox` state.

![](images/state-machine/Unconfigured.svg)

## ConfigFound

`ConfigFound` informs that all configuration files and snapshots are
found. They are not loaded though. Config is to be downloaded and
validated. If during these phases error occurs, then state is set to
`InitError` state. Otherwise, it  will move to `ConfigLoaded` state.

![](images/state-machine/ConfigFound.svg)

## ConfigLoaded

Config is found, loaded and validated. The next step is an instance
configuring. If snapshots are present, then instance will change its
state to `RecoveringSnapshot`.  In another case, it will move to
`BootstrappingBox`. By default all instances start in read-only mode and
don't start listening until bootstrap/recovery finishes.

![](images/state-machine/ConfigLoaded.svg)

## InitError

Instance initialization error -- a state caused by following:

- Error occurred during `cartridge.remote-control`'s connection to
  binary port
- Missing `config.yml` from workdir (`tmp/`), while snapshots are present
- Error loading configuration from disk
- Invalid config - Server is not present in the cluster configuration

## BootstrappingBox

Configuring arguments for `box.cfg`, if snapshots or config files are
not present. `box.cfg`  execution. Setting up users, and stopping
`remote-control`. Instance will try to start listening full-featured
iproto protocol. In case of failed attempt instance will change its
state to `BootError`. If replicaset is not present in clusterwide
config, then instance will set state to `BootError` as well. If
everything is ok, instance is set to `ConnectingFullmesh`.

![](images/state-machine/Recovery.svg)

## RecoveringSnapshot

If snapshots are present, `box.cfg` will start a recovery process. After
that the process is similar to `BootstrappingBox`.

## BootError

This state can be caused by following:

- Failed binding to binary port for iproto usage
- Server is missing in clusterwide config
- Replicaset is missing in clusterwide config
- Failed replication configuration

## ConnectingFullmesh

During this state a configuration of servers and replicasets is being
performed. Eventually, cluster topology, that is described in config, is
implemented. But in case of error instance state is changed to
`BootError`. Otherwise it proceeds to configuring roles.

![](images/state-machine/ConnectingFullmesh.svg)

## BoxConfigured

This state follows successful configuration of replicasets and cluster
topology. The next step is a role configuration.

## ConfiguringRoles

The state of role configuration. Instance can be set to this state while
initial setup, after failover trigger(`failover.lua`) or after altering
clusterwide config(`twophase.lua`).

![confRoles](images/state-machine/ConfiguringRoles.svg)

## RolesConfigured
Successful role configuration.

## OperationError
Error while role configuration.
