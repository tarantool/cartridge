# Failover architecture

One of important concepts in cluster topology is **the leader** setting.
Leader is an instance, which is responsible for performing key
operations, for simplicity one can think of it as of the only writable
master. Every replica set has it's own leader, and there's usually not
more than one.

Which instance will become a leader depends on topology settings and
failover configuration.

One of important topology parameters is the **failover priority** within
replica set. It's an ordered list of instances. By default, the first
instance in the list will become a leader, but with failover enabled it
may be changed automatically if the first one is malfunctioning.

## Instance configuration upon leadership change

When cartridge configures roles it takes into account **leadership map**
(consolidated in `failover.lua` module). Leadership map is composed when
the instance enters `ConfiguringRoles` state for the first time. Later
the map is updated according to the failover mode.

Every change is leadership map is accompanied by the instance
re-configuration. When the map changes the cartridge updates `read_only`
setting and calls `apply_config` callback for every role. It also
specifies `is_master` flag (which actually means `is_leader`, but wasn't
renamed yet due to historical reasons).

It's important to say, that we discuss distributed system. And every
instance has it's own opinion. Even if all opinions coincide there still
may be races between instances, and one (an application developer)
should take them into account when designing roles and their
interaction.

## Leader appointment rules

The logics behind leader election depends on the **failover mode** which
are three: disabled, eventual, and stateful.

### Disabled mode

This is the simplest case. The leader is always the first instance in
failover priority. No automatic switching is performed. When it's dead,
it's dead.

### Eventual failover

In `eventual` mode the leader isn't elected consistently. Instead, every
instance in cluster thinks the leader is the first **healthy** server in
replicaset, while instance health is determined according to membership
status (the SWIM protocol).

Leader election in eventual failover mode should be spoken of as
follows. Suppose there are two replica sets in cluster - a single router
"R" and a pair of storages "S1" and "S2". Than we can say:
all three R, S1, S2 agree that S1 is the leader.

SWIM protocol makes us sure that *eventually* all instances will find
common ground, but it's not guaranteed for every intermediate moment of
time. So we may come into situation soon after S1 dies, when R already
informed and thinks S2 is a leader, but S2 didn't receive the gossip yet
and still thinks he's not. The similar situation can result in both S1
and S2 considering themselves to be leaders.

Moreover, SWIM protocol isn't perfect and still can produce
false-negative gossips (announce the instance is dead when it's not).

### Stateful failover

This mode relies on two new actors. As before, every instance composes
his own leadership map, but now it's fetched from **external state
provider** (that's why it's called stateful). In future cartridge is
going to support different providers, such as consul or etcd, but
nowadays there's only one - `stateboard`. It's a stand-alone Tarantool
instance which implements domain specific key-value storage (simply
`replicaset_uuid -> leader_uuid`) and a locking mechanism.

Changes in leadership map are obtained form stateboard with the long
polling technique.

All decisions are made by **the coordinator** - the one who holds the
lock. Coordinator is implemented as a built-in cartridge role. There may
be many instances with the coordinator role enabled, but only one of
them could acquire the lock at the same time. We call him the active
one.

The lock is released automatically when TCP connection is closed, or it
may expire if coordinator becomes unresponsive (the timeout is set by
stateboard `--lock_delay` option), so the coordinator renews it from
time to time.

Coordinator makes his decision basing on SWIM data, but he does it
slightly differently than eventual failover does:

- Right after acquiring the lock in the state provider, coordinator
  fetches leadership map.

- If there is no appointment for a replicaset, coordinator appoints the
  first leader according to failover priority notwithstanding it's
  SWIM status.

- If a leader becomes degraded, coordinator makes another decision. New
  leader is the first healthy instance from failover priority list.
  Healthy leaders aren't switched automatically even if it's not first.
  Changing failover priority doesn't affect it too.

- Every appointment (self-made or fetched) is immune for the first time
  (which is controlled with `IMMUNITY_TIMEOUT` option).

#### The case: external provider outage

In this case instances do nothing: who was a leader remains a leader,
who was read-only remains read-only. If any instance restarts during
external state provider outage, it composes empty leadership map, i.e.
it doesn't know who's actually a leader and thinks there a none of
them.

#### The case: coordinator outage

Active coordinator may be absent in cluster either because of a failure
or due to disabling the role everywhere. Just like previously, instances
do nothing about it - they keep fetching leadership map from the state
provider. But it will remain the same until a coordinator appears.

## Manual leader promotion

It differs a lot depending on the failover mode.

In disabled and eventual modes one can only promote a leader by changing
failover priority (apply new clusterwide configuration).

In stateful mode failover priority doesn't make much sence (except for
the first appointment). Instead, one should use separate promotion API
which pushes manual appointment to the state provider.

## Failover configuration

These are cluster-wide parameters:

* `mode`: "disabled" / "eventual" / "stateful".
* `state_provider`: only "tarantool" is supported for now.
* `tarantool_params`: `{uri = "...", password = "..."}`.

### Lua API

See:

- `cartridge.failover_get_params`,
- `cartridge.failover_set_params`,
- `cartridge.failover_promote`.

### GraphQL API

Use your favorite GraphQL client (e.g.
[Altair](https://altair.sirmuel.design/)) to see requests introspection:

- `query {cluster{failover_params{}}}`,
- `mutation {cluster{failover_params(){}}}`,
- `mutation {cluster{failover_promote()}}`.

## Stateboard configuration

Stateboard does support `cartridge.argprase` options similar to other
cartridge instances:

* `listen`
* `workdir`
* `password`
* `lock_delay`

And, similar to other argparse options, they can be passed via
command-line arguments or via environment variables, e.g.:

```bash
.rocks/bin/stateboard --workdir ./dev/stateboard --listen 4401 --password qwerty
```

## Fine-tuning failover behavior

Besides failover priority and mode there are few other private options
that influence failover operation.

* `failover` `LONGPOLL_TIMEOUT` (default: 30) -
  the long polling algorithm timeout;
* `failover/coordinator` `NETBOX_CALL_TIMEOUT` (default: 1) -
  `stateboard` client connection timeout;
* `coordinator` `RECONNECT_PERIOD` (default: 5) -
  time to reconnect if `stateboard` is unreachable;
* `coordinator` `IMMUNITY_TIMEOUT` (default: 15) -
  minimal amount of time to wait before overriding an appointment.

