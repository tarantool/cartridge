# Cluster instance lifecycle.

Every instance in cluster possesses internal state machine. It helps to
manage cluster operation and makes describing distributed system
simpler.

<!-- Image: entire state machine -->

Instance lifecycle starts from `cartridge.cfg` call. Cartridge instance
during initialization binds TCP (iproto) and UDP sockets (SWIM), checks
working directory and depending on circumstances continues to one of the
following states:

<!-- Image: [*] -> Unconfigured/ConfigFound -->

## Unconfigured

If working directory is clean and neither snapshots nor clusterwide
configuration files exist the instance enters 'Unconfigured' state.

The instance starts accepting iproto requests (Tarantool binary
protocol) and remains in the state until user decides to join it to the
cluster (either to create replicaset or join the existing one).

After that instance moves to `BootstrappingBox` state.

## ConfigFound

`ConfigFound` informs that all configuration files and snapshots are
found but not loaded. If configuration load is failed, then instance
will change its state to  `InitError` or `ConfigLoaded` otherwise.

Все файлы конфигурации (`*.yml` и снапшоты) существуют и найдены, но еще
не загружены. При неудачной загрузке конфигурации инстанс переходит в
состояние `InitError`, иначе в `ConfigLoaded`.

## ConfigLoaded

Config is found, loaded and validated. The next step is an instance
configuring. If snapshots are present, then instance will change its
state to `RecoveringSnapshot` and try to recover.  In another case, it
will set state to `BootstrappingBox`.

Конфигурация найдена, загружена и валидированна. Далее предстоит
настройка инстанса. В случае наличия снапшотов инстанс переходит в
состояние `RecoveringSnapshot` и попробует восстановиться. Если их нет,
то инстанс переходит в состояние `BootstrappingBox`.

## InitError

Instance initialization error -- a state caused by following:

-  Error occurred during `cartridge.remote-control`'s connection to
binary port - Missing `config.yml` from workdir (`tmp/`), while
snapshots are present - Error loading configuration from disk - Invalid
config - Server is not present in the cluster configuration

Ошибка инициализации инстанса -- состояние, в которое попадает инстанс
из-за:

- Ошибки при подключении с помощью `cartridge.remote-control`  к
- бинарному порту Отсутствии `config.yml` в рабочей директории (`tmp/`)
- при наличии файлов снапшотов Ошибки при загрузке конфигурации кластера
- с диска Невалидной конфигурации Отсутствия сервера в конфигурации
- кластера

## BootstrappingBox

Configuring arguments for `box.cfg`, if snapshots or config files are
missing. `box.cfg`  execution. Configuring users, and stopping
`remote-control`. Instance will try to start listening full-featured
iproto protocol. In case of failed attempt instance will change its
state to `BootError`. If replicaset is not present in clusterwide
config, then instance will set state to `BootError` as well. If
everything is ok, instance is set to `ConnectingFullmesh`.

Настройка параметров для `box.cfg` в случае отсутствия снапшотов
(`ConfigLoaded->` )  или конфигурационных файлов (`Unconfigured->`) и ее
выполнение. Настройка пользователей. Отключение `remote-control`.  Если
инсансу не удалось подключиться к порту для использования протокола
iproto, то он переходит в состояние `BootError`. В случае отсутствия
репликасета к конфигурации кластера инстанс также переходит в состояние
`BootError`. Если все хорошо, то инстанс переходит в
`ConnectingFullmesh`.

## RecoveringSnapshot

If snapshots are present, `box.cfg` will start a recovery process. Then
users will be configured, and `remote-control` will be stopped. Instance
will try to start listening full-featured iproto protocol. In case of
failed attempt instance will change its state to `BootError`. If
replicaset is not present in clusterwide config, then instance will set
state to `BootError` as well. If everything is ok, instance is set to
`ConnectingFullmesh`.

В случае наличия снапшотов параметры для `box.cfg` настраиваются
соответственно, вызов `box.cfg` выполняет процесс восстановления из
снапшотов. Далее следует настройка пользователей и отключение
`remote-control`. Если инсансу не удалось подключиться к порту для
использования протокола iproto, то он переходит в состояние `BootError`.
 В случае отсутствия репликасета к конфигурации кластера инстанс также
переходит в состояние `BootError`. Если все хорошо, то инстанс переходит
в `ConnectingFullmesh`.

## BootError

This state can be caused by following:

- Failed binding to binary port for iproto usage Server is missing in
- clusterwide config Replicaset is missing in clusterwide config Failed
- replication configuration

Состояние инстанса, вызванное одной из следующих ошибок:

- Неудачное подключение к порту для использования iproto Отсутствие
- сервера в конфигурации кластера Отсутствие репликасета в конфигурации
- кластера Неудачная настройка репликации

## ConnectingFullmesh

During this state a configuration of servers and replicasets is being
performed, and cluster topology, described in config, is being
implemented.

В данном состоянии инстанс производит настройку серверов и репликасетов,
и реализуется кластерная топология, описанная в конфигурации.

## BoxConfigured

This state follows successful configuration of replicasets and cluster
topology. The next step is a role configuration.

Состояние следующее вслед за успешной настройкой репликасетов и
топологии кластера. Далее -- настройка ролей.

## ConfiguringRoles

The state of role configuration. Instance can be set to this state while
initial setup, after failover trigger(`failover.lua`) or after altering
clusterwide config(`twophase.lua`).

Состояние настройки ролей. В данное состояние инстанс может попасть при
первоначальной настройке, триггере failover (`failover.lua`) или при
изменении конфигурации кластера (`twophase.lua`).

## RolesConfigured

Successful role configuration.

Успешная настройка ролей.

## OperationError

Error while role configuration.

Ошибка при настройке ролей.



