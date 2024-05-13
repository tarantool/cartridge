.. _cartridge-failover:

-------------------------------------------------------------------------------
Failover architecture
-------------------------------------------------------------------------------

An important concept in cluster topology is appointing **a leader**.
Leader is an instance which is responsible for performing key
operations. To keep things simple, you can think of a leader as of the only
writable master. Every replica set has its own leader, and there's usually not
more than one.

Which instance will become a leader depends on topology settings and
failover configuration.

An important topology parameter is the **failover priority** within
a replica set. This is an ordered list of instances. By default, the first
instance in the list becomes a leader, but with the failover enabled it
may be changed automatically if the first one is malfunctioning.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Instance configuration upon a leader change
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

When Cartridge configures roles, it takes into account the **leadership map**
(consolidated in the ``failover.lua`` module). The leadership map is composed when
the instance enters the ``ConfiguringRoles`` state for the first time. Later
the map is updated according to the failover mode.

Every change in the leadership map is accompanied by instance
re-configuration. When the map changes, Cartridge updates the ``read_only``
setting and calls the ``apply_config`` callback for every role. It also
specifies the ``is_master`` flag (which actually means ``is_leader``, but hasn't
been renamed yet due to historical reasons).

It's important to say that we discuss a *distributed* system where every
instance has its own opinion. Even if all opinions coincide, there still
may be races between instances, and you (as an application developer)
should take them into account when designing roles and their
interaction.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Leader appointment rules
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The logic behind leader election depends on the **failover mode**:
disabled, eventual, or stateful.

*******************************************************************************
Disabled mode
*******************************************************************************

This is the simplest case. The leader is always the first instance in
the failover priority. No automatic switching is performed. When it's dead,
it's dead.

*******************************************************************************
Eventual failover
*******************************************************************************

In the ``eventual`` mode, the leader isn't elected consistently. Instead, every
instance in the cluster thinks that the leader is the first **healthy** instance
in the failover priority list, while instance health is determined according to
the membership status (the SWIM protocol).
**Not recommended** to use on large clusters in production. If you have highload
production cluster, use stateful failover with ``etcd`` instead.

The member is considered healthy if both are true:

1. It reports either ``ConfiguringRoles`` or ``RolesConfigured`` state;
2. Its SWIM status is either ``alive`` or ``suspect``.

A ``suspect`` member becomes ``dead`` after the ``failover_timout`` expires.

Leader election is done as follows.
Suppose there are two replica sets in the cluster:

* a single router "R",
* two storages, "S1" and "S2".

Then we can say: all the three instances (R, S1, S2) agree that S1 is the leader.

The SWIM protocol guarantees that *eventually* all instances will find a
common ground, but it's not guaranteed for every intermediate moment of
time. So we may get a conflict.

For example, soon after S1 goes down, R is already informed and thinks
that S2 is the leader, but S2 hasn't received the gossip yet and still thinks
he's not. This is a conflict.

Similarly, when S1 recovers and takes the leadership, S2 may be unaware of
that yet. So, both S1 and S2 consider themselves as leaders.

Moreover, SWIM protocol isn't perfect and still can produce
false-negative gossips (announce the instance is dead when it's not).
It may cause "failover storms", when failover triggers too many times per minute
under a high load. You can pause failover at runtime using Lua API
(``require('cartridge.lua-api.failover').pause()``) or GraphQL mutation
(``mutation { cluster { failover_pause } }``). Those functions will pause
failover on every instance they can reach. To see if failover is paused,
check the logs or use the function ``require('cartridge.failover').is_paused()``.
Don't forget to resume failover using Lua API
(``require('cartridge.lua-api.failover').resume()``) or GraphQL mutation
(``mutation { cluster { failover_resume } }``).

You can also enable failover suppressing by ``cartridge.cfg`` parameter
``enable_failover_suppressing``. It allows to automatically pause failover
in runtime if failover triggers too many times per minute. It could be
configured by argparse parameters ``failover_suppress_threshold``
(count of times than failover triggers per ``failover_suppress_timeout`` to
be suppressed) and ``failover_suppress_timeout`` (time in seconds, if failover
triggers more than ``failover_suppress_threshold``, it'll be suppressed and
released after ``failover_suppress_timeout`` sec).

..  _cartridge-stateful_failover:

*******************************************************************************
Stateful failover
*******************************************************************************

Similarly to the eventual mode, every instance composes its own leadership map,
but now the map is fetched from an **external state provider**
(that's why this failover mode called "stateful"). Nowadays there are two state
providers supported -- ``etcd`` and ``stateboard`` (standalone Tarantool instance).
State provider serves as a domain-specific key-value storage (simply
``replicaset_uuid -> leader_uuid``) and a locking mechanism.

Changes in the leadership map are obtained from the state provider with the
`long polling technique <https://en.wikipedia.org/wiki/Push_technology#Long_polling>`_.

All decisions are made by **the coordinator** -- the one that holds the
lock. The coordinator is implemented as a built-in Cartridge role. There may
be many instances with the coordinator role enabled, but only one of
them can acquire the lock at the same time. We call this coordinator the "active"
one.

The lock is released automatically when the TCP connection is closed, or it
may expire if the coordinator becomes unresponsive (in ``stateboard`` it's set
by the stateboard's ``--lock_delay`` option, for ``etcd`` it's a part of
clusterwide configuration), so the coordinator renews the lock from
time to time in order to be considered alive.

The coordinator makes a decision based on the SWIM data, but the decision
algorithm is slightly different from that in case of eventual failover:

* Right after acquiring the lock from the state provider, the coordinator
  fetches the leadership map.

* If there is no leader appointed for the replica set, the coordinator
  appoints the first leader according to the failover priority, regardless of
  the SWIM status.

* If a leader becomes ``dead``, the coordinator makes a decision. A new
  leader is the first healthy instance from the failover priority list.
  If an old leader recovers, no leader change is made until the current
  leader down. Changing failover priority doesn't affect this.

* Every appointment (self-made or fetched) is immune for a while
  (controlled by the ``IMMUNITY_TIMEOUT`` option).

You can also enable ``leader_autoreturn`` to return leadership to the
first leader in ``failover_priority`` list after failover was triggered.
It might be useful when you have active and passive data centers.
The time before failover will try to return the leader is configured by
``autoreturn_delay`` option in a failover configuration. Note that
``leader_autoreturn`` won't work if the prime leader is unhealthy.

Stateful failover automatically checks if there is a registered cluster
in a state provider. Check is performed on a first stateful failover
configuration and every time when cluster is restarted. You can disable that
option by using ``check_cookie_hash = false`` in failover configuration.

Stateful failover may call ``box.ctl.promote`` on the leader instance.
It doesn't work with ``ALL_RW`` replicasets and replicasets with
one existing or enabled node. It works on any Tarantool versions where
``box.ctl.promote`` is available. If you face any issue with promoting,
you can try call it manually on ``leader``. If you want to enable this
functionality, you should enable it in your ``init.lua`` file:

.. code-block:: lua

   cartridge.cfg({
      ...
      enable_synchro_mode = true,
  })


^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Case: external provider outage
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

In this case, instances do nothing: the leader remains a leader,
read-only instances remain read-only. If any instance restarts during an
external state provider outage, it composes an empty leadership map:
it doesn't know who actually is a leader and thinks there is none.

^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Case: coordinator outage
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

An active coordinator may be absent in a cluster either because of a failure
or due to disabling the role on all instances. Just like in the previous case,
instances do nothing about it: they keep fetching the leadership map from the
state provider. But it will remain the same until a coordinator appears.

..  _cartridge-raft_failover:

*******************************************************************************
Raft failover (beta)
*******************************************************************************

Raft failover in Cartridge based on built-in Tarantool Raft failover, the
``box.ctl.on_election`` trigger that was introduced in Tarantool 2.10.0, and
eventual failover mechanisms. The replicaset leader is chosen by built-in Raft,
then the other replicasets get information about leader change from membership.
It's needed to use Cartridge RPC calls. The user can control an instance's
election mode using the argparse option ``TARANTOOL_ELECTION_MODE`` or
``--election-mode`` or use ``box.cfg{election_mode = ...}`` API in runtime.

Raft failover can be enabled only on replicasets of 3 or more instances
(you can change the behavior by using ``cartridge.cfg`` option
``disable_raft_on_small_clusters``) and can't be enabled with ``ALL_RW`` replicasets.

..  important::

    Raft failover in Cartridge is in beta. Don't use it in production.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Manual leader promotion
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

It differs a lot depending on the failover mode.

In the disabled and eventual modes, you can only promote a leader by changing
the failover priority (and applying a new clusterwide configuration).

In the stateful mode, the failover priority doesn't make much sense (except for
the first appointment). Instead, you should use the promotion API
(the Lua :ref:`cartridge.failover_promote <cartridge.failover_promote>` or
the GraphQL ``mutation {cluster{failover_promote()}}``)
which pushes manual appointments to the state provider.

The stateful failover mode implies **consistent promotion**: before becoming
writable, each instance performs the ``wait_lsn`` operation to sync up with the
previous one.

Information about the previous leader (we call it a *vclockkeeper*) is also
stored on the external storage. Even when the old leader is demoted, it remains the
vclockkeeper until the new leader successfully awaits and persists its vclock on
the external storage.

If replication is stuck and consistent promotion isn't possible, a user has two
options: to revert promotion (to re-promote the old leader) or to force it
inconsistently (all kinds of ``failover_promote`` API has
``force_inconsistency`` flag).

Consistent promotion doesn't work for replicasets with `all_rw` flag enabled
and for single-instance replicasets. In these two cases an instance doesn't
even try to query `vclockkeeper` and to perform `wait_lsn`. But the coordinator
still appoints a new leader if the current one dies.

In the Raft failover mode, the user can also use the promotion API:
:ref:`cartridge.failover_promote <cartridge.failover_promote>` in Lua or
``mutation {cluster{failover_promote()}}`` in GraphQL,
which calls ``box.ctl.promote`` on the specified instances.
Note that ``box.ctl.promote`` starts fair elections, so some other instance may
become the leader in the replicaset.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Unelectable nodes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You can restrict the election of a particular node in the ``stateful``
failover mode by GraphQL or Lua API. An "unelectable" node can't become a
leader in a replicaset. It could be useful for nodes that could only be used
for election process and for routers that shouldn't store the data.

In ``edit_topology``:

.. code-block:: json

   {
      "replicasets": [
        {
            "alias": "storage",
            "uuid": "aaaaaaaa-aaaa-0000-0000-000000000000",
            "join_servers": [
                {
                    "uri": "localhost:3301",
                    "uuid": "aaaaaaaa-aaaa-0000-0000-000000000001",
                    "electable": false
                }
            ],
            "roles": []
        }
      ]
    }

In Lua API:

.. code-block:: lua

   -- to make nodes unelectable:
   require('cartridge.lua-api.topology').api_topology.set_unelectable_servers(uuids)
   -- to make nodes electable:
   require('cartridge.lua-api.topology').api_topology.set_electable_servers(uuids)

You can also make a node unelectable in WebUI:

..  image:: ./images/set_non_electable.png
    :align: left
    :scale: 40%

|nbsp|

If everything is ok, you will see a crossed-out crown to the left of the instance name.

..  image:: ./images/non_electable.png
    :align: left
    :scale: 40%

|nbsp|

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fencing
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Neither ``eventual`` nor ``stateful`` failover mode protects a replicaset
from the presence of multiple leaders when the network is partitioned.
But fencing does. It enforces at-most-one leader policy in a replicaset.

Fencing operates as a fiber that occasionally checks connectivity with
the state provider and with replicas. Fencing fiber runs on
vclockkeepers; it starts right after consistent promotion succeeds.
Replicasets which don't need consistency (single-instance and
``all_rw``) don't defend, though.

The condition for fencing actuation is the loss of both the state
provider quorum and at least one replica. Otherwise, if either state
provider is healthy or all replicas are alive, the fencing fiber waits
and doesn't intervene.

When fencing is actuated, it generates a fake appointment locally and
sets the leader to ``nil``. Consequently, the instance becomes
read-only. Subsequent recovery is only possible when the quorum
reestablishes; replica connection isn't a must for recovery. Recovery is
performed according to the rules of consistent switchover unless some
other instance has already been promoted to a new leader.

Raft failover supports fencing too. Check ``election_fencing_mode`` parameter
of ``box.cfg{}``

..  _failover-configuration:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Failover configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

These are clusterwide parameters:

* ``mode``: "disabled" / "eventual" / "stateful" / "raft".
* ``state_provider``: "tarantool" / "etcd".
* ``failover_timeout`` -- time (in seconds) to mark ``suspect`` members
  as ``dead`` and trigger failover (default: 20).
* ``tarantool_params``: ``{uri = "...", password = "..."}``.
* ``etcd2_params``: ``{endpoints = {...}, prefix = "/", lock_delay = 10, username = "", password = ""}``.
* ``fencing_enabled``: ``true`` / ``false`` (default: false).
* ``fencing_timeout`` -- time to actuate fencing after the check fails (default: 10).
* ``fencing_pause`` -- the period of performing the check (default: 2).
* ``leader_autoreturn``: ``true`` / ``false`` (default: false).
* ``autoreturn_delay`` -- the time before failover will try to return leader
  in replicaset to the first instance in ``failover_priority`` list (default: 300).
* ``check_cookie_hash`` -- enable check that nobody else uses this stateboard.

It's required that ``failover_timeout > fencing_timeout >= fencing_pause``.

*******************************************************************************
Lua API
*******************************************************************************

See:

* :ref:`cartridge.failover_get_params <cartridge.failover_get_params>`,
* :ref:`cartridge.failover_set_params <cartridge.failover_set_params>`,
* :ref:`cartridge.failover_promote <cartridge.failover_promote>`.

*******************************************************************************
GraphQL API
*******************************************************************************

Use your favorite GraphQL client (e.g.
`Altair <https://altair.sirmuel.design/>`_) for requests introspection:

- ``query {cluster{failover_params{}}}``,
- ``mutation {cluster{failover_params(){}}}``,
- ``mutation {cluster{failover_promote()}}``.

Here is an example of how to setup stateful failover:

.. code-block:: graphql

    mutation {
      cluster { failover_params(
        mode: "stateful"
        failover_timeout: 20
        state_provider: "etcd2"
        etcd2_params: {
            endpoints: ["http://127.0.0.1:4001"]
            prefix: "etcd-prefix"
        }) {
            mode
            }
        }
    }

..  _stateboard-configuration:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Stateboard configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Like other Cartridge instances, the stateboard supports ``cartridge.argprase``
options:

* ``listen``
* ``workdir``
* ``password``
* ``lock_delay``

Similarly to other ``argparse`` options, they can be passed via
command-line arguments or via environment variables, e.g.:

..  code-block:: bash

    .rocks/bin/stateboard --workdir ./dev/stateboard --listen 4401 --password qwerty

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fine-tuning failover behavior
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Besides failover priority and mode, there are some other private options
that influence failover operation:

* ``LONGPOLL_TIMEOUT`` (``failover``) -- the long polling timeout (in seconds) to
  fetch new appointments (default: 30);

* ``NETBOX_CALL_TIMEOUT`` (``failover/coordinator``) -- stateboard client's
  connection timeout (in seconds) applied to all communications (default: 1);

* ``RECONNECT_PERIOD`` (``coordinator``) -- time (in seconds) to reconnect to the
  state provider if it's unreachable (default: 5);

* ``IMMUNITY_TIMEOUT`` (``coordinator``) -- minimal amount of time (in seconds)
  to wait before overriding an appointment (default: 15).
