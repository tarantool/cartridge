# Cluster instance lifecycle.

Every instance in cluster possesses internal state machine. It helps to manage cluster operation and makes describing distributed system simpler.

![](https://user-images.githubusercontent.com/26364021/79237339-b9ffa100-7e76-11ea-9cd5-ebace268da36.png)

Instance lifecycle starts from `cartridge.cfg` call. Cartridge instance during initialization binds TCP (iproto) and UDP sockets (SWIM), checks working directory and depending on circumstances continues to one of the following states:

![](https://user-images.githubusercontent.com/26364021/79237248-9e949600-7e76-11ea-8a15-87cbb67c8b67.png)

## Unconfigured

If working directory is clean and neither snapshots nor clusterwide configuration files exist the instance enters `Unconfigured` state.

The instance starts accepting iproto requests (Tarantool binary protocol) and remains in the state until user decides to join it to the cluster (either to create replicaset or join the existing one).

After that instance moves to `BootstrappingBox` state.

![](https://user-images.githubusercontent.com/26364021/79238266-d9e39480-7e77-11ea-92ae-79493c7ab011.png)

## ConfigFound

`ConfigFound` informs that all configuration files and snapshots are found. They are not loaded though. Config is to be downloaded and validated. If during these phases error occurs, then state is set to `InitError` state. Otherwise, it  will move to `ConfigLoaded` state.

![](https://user-images.githubusercontent.com/26364021/79238598-42327600-7e78-11ea-8c00-10532272a88a.png)

## ConfigLoaded

Config is found, loaded and validated. The next step is an instance configuring. If snapshots are present, then instance will change its state to `RecoveringSnapshot`.  In another case, it will move to `BootstrappingBox`. By default all instances start in read-only mode and don't start listening until bootstrap/recovery finishes.

![](https://user-images.githubusercontent.com/26364021/79239415-3bf0c980-7e79-11ea-9773-b664887a9a98.png)

## InitError

Instance initialization error -- a state caused by following:

-  Error occurred during `cartridge.remote-control`'s connection to
binary port
-  Missing `config.yml` from workdir (`tmp/`), while snapshots are present 
-  Error loading configuration from disk 
-  Invalid config - Server is not present in the cluster configuration

## BootstrappingBox

Configuring arguments for `box.cfg`, if snapshots or config files are not present. `box.cfg`  execution. Setting up users, and stopping `remote-control`. Instance will try to start listening full-featured
iproto protocol. In case of failed attempt instance will change its state to `BootError`. If replicaset is not present in clusterwide config, then instance will set state to `BootError` as well. If everything is ok, instance is set to `ConnectingFullmesh`.

![](https://user-images.githubusercontent.com/26364021/79240072-f97bbc80-7e79-11ea-9f91-7c20d9fad221.png)

## RecoveringSnapshot

If snapshots are present, `box.cfg` will start a recovery process. After that the process is similar to `BootstrappingBox`.

## BootError

This state can be caused by following:

- Failed binding to binary port for iproto usage 
- Server is missing in clusterwide config 
- Replicaset is missing in clusterwide config 
- Failed replication configuration

## ConnectingFullmesh

During this state a configuration of servers and replicasets is being performed. Eventually, cluster topology, that is described in config, is implemented. But in case of error instance state is changed to `BootError`. Otherwise it proceeds to configuring roles. 

![](https://user-images.githubusercontent.com/26364021/79240433-73ac4100-7e7a-11ea-8a5f-1475991d79e6.png)

## BoxConfigured

This state follows successful configuration of replicasets and cluster topology. The next step is a role configuration.

## ConfiguringRoles

The state of role configuration. Instance can be set to this state while initial setup, after failover trigger(`failover.lua`) or after altering clusterwide config(`twophase.lua`).

![confRoles](https://user-images.githubusercontent.com/26364021/79243067-d2bf8500-7e7d-11ea-9bc5-b3be0c37a01c.png)

## RolesConfigured
Successful role configuration.

## OperationError
Error while role configuration.



