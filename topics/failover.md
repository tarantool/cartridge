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
may be races between instances, and one (and application developer)
should take then into account when designing roles and their
interaction.

## Leader appointment rules

The logics behind leader election depends on the **failover mode** which
are three: disables, eventual, and stateful.

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

TODO
