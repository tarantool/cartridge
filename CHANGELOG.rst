===============================================================================
Changelog
===============================================================================

All notable changes to this project will be documented in this file.

The format is based on `Keep a Changelog <http://keepachangelog.com/en/1.0.0/>`_
and this project adheres to
`Semantic Versioning <http://semver.org/spec/v2.0.0.html>`_.

-------------------------------------------------------------------------------
Unreleased
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
[2.16.2] - 2025-07-11
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``http`` dependency to `https://github.com/tarantool/http/releases/tag/1.8.0>`_.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- An **instance** (router or storage) could stick to a minority etcd node after a
  network partition, keep an outdated `active_leaders` key, and cause split-brain.
  Ordinary reads are now sent with `quorum=true`, and every request (reads, writes,
  long-polls) is issued to the next endpoint in a round-robin order.
  Split-brain is prevented, and long-polls eventually reach a majority node.

-------------------------------------------------------------------------------
[2.16.1] - 2025-07-04
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- New ``config_applied`` variable in ``cartridge.twophase`` module to track
  clusterwide configuration status.
- Improved failover and leader election logging:

  - Added structured logs explaining why a leader appointment was made or skipped.
  - Logs now include replicaset aliases and number of candidates evaluated.
  - Control loop logs clearer start and wait states.

-------------------------------------------------------------------------------
[2.16.0] - 2025-06-20
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- New role callback ``before_apply_config`` to run some code before applying
  configuration changes.
- New vshard option ``connection_fetch_schema``.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``vshard`` dependency to `0.1.34 <https://github.com/tarantool/vshard/releases/tag/0. 1.34>`_.
- VShard storage now is disabled before the end of the first apply_config.

-------------------------------------------------------------------------------
[2.15.4] - 2025-06-11
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Invalid leader appointment in Raft failover when there are not enough instances
  in the replicaset.

-------------------------------------------------------------------------------
[2.15.3] - 2025-04-24
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Etcd client error when connection to etcd was closed while changing leaders.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Removed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Outdated Tarantool 2.7 and 2.8 versions are no longer supported.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``vshard`` dependency to `0.1.33 <https://github.com/tarantool/vshard/releases/tag/0.1.33>`_.

-------------------------------------------------------------------------------
[2.15.2] - 2025-03-31
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``membership`` dependency to `2.5.2 <https://github.com/tarantool/membership/releases/tag/2.5.2>`_.

-------------------------------------------------------------------------------
[2.15.1] - 2025-03-12
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``vshard`` dependency to `0.1.32 <https://github.com/tarantool/vshard/releases/tag/0.1.32>`_.

-------------------------------------------------------------------------------
[2.15.0] - 2025-03-11
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``membership`` dependency to `2.5.1 <https://github.com/tarantool/membership/releases/tag/2.5.1>`_.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- New option ``exclude_expelled_members`` to exclude expelled
  instances from the membership process.

-------------------------------------------------------------------------------
[2.14.0] - 2025-02-13
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Errors from ``box.ctl.promote`` and ``box.ctl.demote`` now are logged.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``membership`` dependency to `2.4.6 <https://github.com/tarantool/membership/releases/tag/2.4.6>`_.

- Cartridge doesn't fetch schema in inner ``pool.connect`` calls.

- Update ``vshard`` dependency to `0.1.31 <https://github.com/tarantool/vshard/releases/tag/0.1.31>`_.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``fetch_schema`` option to ``rpc.get_connection``.

- Shortcut for ``get_topology`` in Cartridge API.

-------------------------------------------------------------------------------
[2.13.0] - 2024-11-28
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``vshard`` dependency to `0.1.30 <https://github.com/tarantool/vshard/releases/tag/0.1.30>`_.

- Update ``http`` dependency to `1.7.0 <https://github.com/tarantool/http/releases/tag/1.7.0>`_.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- SSL support to HTTP server.

- New issue about doubled buckets (can be enabled with TARANTOOL_CHECK_DOUBLED_BUCKETS=true).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- WebUI doesn't request statistics on the first load anymore.

-------------------------------------------------------------------------------
[2.12.4] - 2024-09-16
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``vshard`` dependency to `0.1.29 <https://github.com/tarantool/vshard/releases/tag/0.1.29>`_.

- Update ``http`` dependency to `1.6.0 <https://github.com/tarantool/http/releases/tag/1.6.0>`_.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Rocks versions are shown in the WebUI.

-------------------------------------------------------------------------------
[2.12.3] - 2024-08-16
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- VShard alerts can be displayed in issues list after enabled with env/cli args.

- New option ``TARANTOOL_DISABLE_UNRECOVERABLE_INSTANCES`` to automatically disable
  instances with state ``InitError`` or ``BootError``.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Last instance in vshard-storage replicaset can be expelled now.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Cartridge doesn't use ``vshard-ee`` instead of ``vshard``.

- Cartridge doesn't use ``ddl-ee`` instead of ``ddl``.

- uuids in issues replaces with instance names and uris.

-------------------------------------------------------------------------------
[2.12.2] - 2024-06-24
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``membership`` dependency to `2.4.5 <https://github.com/tarantool/membership/releases/tag/2.4.5>`_.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``cartirdge.get_opts()`` function to get current Cartridge options.

- More logging cartridge options on start.

-------------------------------------------------------------------------------
[2.12.1] - 2024-06-06
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``ddl-manager-ee`` now in the list of implicit roles.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``auth_enabled`` param ``test-helpers.cluster`` to enable/disable auth in tests.

-------------------------------------------------------------------------------
[2.12.0] - 2024-05-28
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- VShard and DDL versions are displayed in the WebUI.

- ``cartridge.cfg`` param ``set_cookie_hash_membership`` to set
  cluster cookie hash as encryption key in membership instead of
  plain cookie.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Cartridge now uses ``vshard-ee`` instead of ``vshard`` if available.

- Cartridge now uses ``ddl-ee`` instead of ``ddl`` if available.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Deprecated
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Usage of plain cluster cookie as a membership encryption key by default.

-------------------------------------------------------------------------------
[2.11.0] - 2024-05-15
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Disk failure check. If there is something wrong with the disk, the instance
  will be disabled automatically and the corresponding issue will be shown
  in the WebUI.

- GraphQL API to enable previously disabled instances:
  ``mutation { cluster { enable_servers(uuids: [...]) { } } }``.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Disabling/enabling instances with ``disable_servers`` / ``enable_servers``
  mutations automatically disables/enables VShard storages.

- Update ``ddl`` dependency to `1.7.1 <https://github.com/tarantool/ddl/releases/tag/1.7.1>`_.

- Update ``vshard`` dependency to `0.1.27 <https://github.com/tarantool/vshard/releases/tag/0.1.27>`_.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Fix false positive warning in migrations UI.

- Leader autoreturn doesn't try to return leadership to unhealthy leader anymore.

-------------------------------------------------------------------------------
[2.10.0] - 2024-04-10
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Add the state provider status action on the failover controller modal.

- Add the "Migrations" page.

- Add "rebalancer_mode" and "rebalancer" options on web UI.

- Twophase commit timeouts now can be set with env.

- New GraphQL API ``failover_state_provider_status`` to ping state provider connection.

- New issue about unhealthy replicasets.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- More strict validation for ``cartridge.is_healthy`` API function.

- Update ``membership`` dependency to `2.4.4 <https://github.com/tarantool/membership/releases/tag/2.4.4>`_.

- Update ``ddl`` dependency to `1.7.0 <https://github.com/tarantool/ddl/releases/tag/1.7.0>`_.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Switching leadership when disabling leader in replicaset.

-------------------------------------------------------------------------------
[2.9.0] - 2024-03-06
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Raft failover state transitions.

- Remote control socket doesn't bind to a localhost when different host is available.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- New VShard configuration options: ``rebalancer`` (on server/replicaset level)
  and ``rebalancer_mode`` (on VShard config level).

- ``rebalancer_enabled`` field to boxinfo GraphQL API.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Config section names with relative paths are prohibited.

-------------------------------------------------------------------------------
[2.8.6] - 2024-02-01
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Incorrect fragmentation issue isn't shown anymore.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``membership`` dependency to `2.4.3 <https://github.com/tarantool/membership/releases/tag/2.4.3>`_.

-------------------------------------------------------------------------------
[2.8.5] - 2024-01-18
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``election_leader_idle`` field to GraphQL API.

- new issue when ``box.info.election.leader_idle`` is too high.

- Lua API ``get_uris`` to get all instances uris.

- Filter param to Lua API ``get_servers`` to filter instances.

- new issue about vshard storages marked as ``ALL_RW``.

- ``cartridge.cfg`` option ``disable_raft_on_small_clusters`` to disable Raft
  failover on clusters with less than 3 instances (default: ``true``).

- ``argparse`` now logs if some sections in config files were ignored
  (`#2169 <https://github.com/tarantool/cartridge/issues/2169>`_).

- IPv6 support (`#2166 <https://github.com/tarantool/cartridge/issues/2166>`_).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- An error with ``cartridge.utils.version_is_at_least`` parsing.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``vshard`` dependency to `0.1.26 <https://github.com/tarantool/vshard/releases/tag/0.1.26>`_.

- Update ``membership`` dependency to `2.4.2 <https://github.com/tarantool/membership/releases/tag/2.4.2>`_.

-------------------------------------------------------------------------------
[2.8.4] - 2023-10-31
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``ddl`` dependency to `1.6.5 <https://github.com/tarantool/ddl/releases/tag/1.6.5>`_.

-------------------------------------------------------------------------------
[2.8.3] - 2023-09-28
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``membership`` dependency to `2.4.1 <https://github.com/tarantool/membership/releases/tag/2.4.1>`_.

-------------------------------------------------------------------------------
[2.8.2] - 2023-08-22
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Fix operation priority in Raft failover.

- Typo in ``cartridge.cfg`` option ``enable_synchro_mode``.

- Show issue about memory usage when using large tuples.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Deprecated
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``cartridge.cfg`` option ``enable_sychro_mode``. Use ``enable_synchro_mode``
  instead.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- New Failover API function ``set_options`` to change failover internal params.

- Issue about sync spaces usage with a wrong failover setup.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Don't perform invalid format check in Tarantool 2.10.4 and above.

- Throw an error when using Tarantool 3.

-------------------------------------------------------------------------------
[2.8.1] - 2023-07-20
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``ddl`` dependency to `1.6.4 <https://github.com/tarantool/ddl/releases/tag/1.6.4>`_.

- Update ``cartridge-metrics-role`` dependency to `0.1.1 <https://github.com/tarantool/cartridge-metrics-role/releases/tag/0.1.1>`_.

- Don't require systemd to default to syslog logging. Only check that syslog UNIX socket is available.

- Fix syslog UNIX socket check for older RHEL-based distros: check both SOCK_STREAM and SOCK_DGRAM.

-------------------------------------------------------------------------------
[2.8.0] - 2023-05-25
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``http`` dependency to `1.5.0 <https://github.com/tarantool/http/releases/tag/1.5.0>`_.

- Update ``graphql`` dependency to `0.3.0 <https://github.com/tarantool/graphql/releases/tag/0.3.0>`_.

- Update ``checks`` dependency to `3.3.0 <https://github.com/tarantool/checks/releases/tag/3.3.0>`_.

- Update ``vshard`` dependency to `0.1.24 <https://github.com/tarantool/vshard/releases/tag/0.1.24>`_.

- Call ``box.ctl.promote`` in stateful failover (`#1372 <https://github.com/tarantool/cartridge/issues/1372>`_).
  Can be enabled by ``cartridge.cfg`` option ``enable_sychro_mode``.

- Call ``box.ctl.demote`` when raft failover is disabled.

- Remove expelled instances from ``box.space._cluster`` before replication changes
  (`#1948 <https://github.com/tarantool/cartridge/issues/1948>`_).

- Allow to call ``box.ctl.promote`` on any instance
  (`#2079 <https://github.com/tarantool/cartridge/issues/2079>`_).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``cartridge.roles.metrics`` role (`tarantool#7725 <https://github.com/tarantool/tarantool/issues/7725>`_)
  added as an external dependency ``cartridge-metrics-role`` `0.1.0 <https://github.com/tarantool/cartridge-metrics-role>`_.

- Versioning support (`tarantool/roadmap-internal#204 <https://github.com/tarantool/roadmap-internal/issues/204>`_).

- ``rpc_call`` supports ``is_async`` net.box option.

- New issue about expelled instances that still in ``box.space._cluster``.

- Allow to list several instances (comma-separated) in ``bootstrap_from``.

- New argparse type ``json`` and several new parameters from Tarantool 2.11
  (`#2102 <https://github.com/tarantool/cartridge/issues/2102>`_).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Compatibility with metrics in feedback (`#2033 <https://github.com/tarantool/cartridge/issues/2033>`_).

- Display correct ``listen`` in WebUI when using iproto ssl (`#2051 <https://github.com/tarantool/cartridge/issues/2051>`_).

- Incorrect memory statistics in WebUI when using large tuples.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Removed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Previously unused labels validation. You can return logging of invalid labels
  by setting global ``__cartridge_log_invalid_labels`` to true.

-------------------------------------------------------------------------------
[2.7.9] - 2023-04-06
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``fragmentation_threshold_full`` in issues increased up to 100%. The behaviour
  can be changed with ``set_limits`` function.

- Update ``vshard`` dependency to `0.1.23 <https://github.com/tarantool/vshard/releases/tag/0.1.23>`_.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Allow to promote instances without electable configuration (`#2062 <https://github.com/tarantool/cartridge/issues/2062>`_).

- Compression suggestion: fix instances freezing. Skip indexes compressing.
  (`#2041 <https://github.com/tarantool/cartridge/issues/2041>`_).

-------------------------------------------------------------------------------
[2.7.8] - 2023-01-27 - Update to this release is broken
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Ability to limit incoming connections on ``vshard-router`` by the argparse option
  ``TARANTOOL_CONNECTIONS_LIMIT`` or ``--connections-limit``
  (`#1971 <https://github.com/tarantool/cartridge/issues/1971>`_).

- "Suggestions" button with a compression suggestions info in WebUI
  (`#1913 <https://github.com/tarantool/cartridge/issues/1913>`_).

- Add ``app_name`` and ``app_version`` to feedback.

- etcd v3 support in ``test-helpers.etcd`` (with ``ETCD_ENABLE_V2=true``).

- Show tarantool edition version in WebUI.

- ``fetch_schema`` option to ``cartridge.pool.connect``.

- ``check_cookie_hash`` parameter in stateful failover configuration
  (`#1765 <https://github.com/tarantool/cartridge/issues/1765>`_).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``http`` dependency to `1.4.0 <https://github.com/tarantool/http/releases/tag/1.4.0>`_.

- Update ``checks`` dependency to `3.2.0 <https://github.com/tarantool/checks/releases/tag/3.2.0>`_.

- Limits of memory issues decreased. Cartridge now produce an issue when at least
  one of memory ratio is higher than 95%.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Use default values of ``replication_connect_quorum`` and
  ``replication_sync_timeout`` in first ``box.cfg`` call.

- Lowercase ``transport`` param to handle different cases of value (`#2021 <https://github.com/tarantool/cartridge/issues/2021>`_).

- Check hash of cluster cookie on stateful failover configuration
  (`#1765 <https://github.com/tarantool/cartridge/issues/1765>`_).

-------------------------------------------------------------------------------
[2.7.7] - 2022-12-09 - Update to this release is broken
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``graphql`` dependency to `0.2.0 <https://github.com/tarantool/graphql/releases/tag/0.2.0>`_.

- Disable Raft failover on replicasets where number of instances less than 3
  (`#1914 <https://github.com/tarantool/cartridge/issues/1914>`_).

- Check Raft failover availability on validate_config (`#1916 <https://github.com/tarantool/cartridge/issues/1916>`_).

- Forbid to enable Raft failover with ``ALL_RW`` replicasets (`#1927 <https://github.com/tarantool/cartridge/issues/1927>`_).

- Disabled instances won't appear as leaders (`#1930 <https://github.com/tarantool/cartridge/issues/1930>`_).

- Mask failover password in WebUI and GraphQL API (`#1960 <https://github.com/tarantool/cartridge/issues/1960>`_).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Add instance labels to web UI (`#1962 <https://github.com/tarantool/cartridge/issues/1962>`_).

- Allow to make nodes unelectable (restrict it to become a leader) in WebUI,
  GraphQL and Lua API (`#1843 <https://github.com/tarantool/cartridge/issues/1843>`_).

- Allow to bootstrap cartridge from existing cluster via argparse option
  ``TARANTOOL_BOOTSTRAP_FROM`` or ``--bootstrap_from`` (`#1842 <https://github.com/tarantool/cartridge/issues/1842>`_).

- ``election_state``, ``election_mode`` and ``synchro_queue_owner`` to GraphQL
  (`#1925 <https://github.com/tarantool/cartridge/issues/1925>`_).

- ``O_SYNC`` flag for ClusterwideConfig.save (`#1939 <https://github.com/tarantool/cartridge/issues/1939>`_).

- Introduced way to filter instances by labels in rpc calls (`#1957 <https://github.com/tarantool/cartridge/issues/1957>`_).
  You can mark certain instances with the same role with different labels,
  and then make an rpc call with label. Adding labels is possible via the
  edit_topology method or via graphql.
  ``rpc.call('role', 'func', {}, { labels = { ['msk'] = 'dc' } })``
  ``rpc.get_candidates('role', { labels = { ['msk'] = 'dc', ['meta'] = 'runner' } })``
  ``rpc.get_connection('role', { labels = { ['msk'] = 'dc' } })``

- "Beta" tag for failover selector in WebUI (`#1961 <https://github.com/tarantool/cartridge/issues/1961>`_).

- Compression suggestion, see
  `#1911 <https://github.com/tarantool/cartridge/issues/1911>`_.

- Leader autoreturn feature for stateful failover (`#1942 <https://github.com/tarantool/cartridge/issues/1942>`_).

- Add password decryption for ssl private key (`#1983 <https://github.com/tarantool/cartridge/issues/1983>`_).

- Add disable flag to not passing error stack to web (`#1932 <https://github.com/tarantool/cartridge/issues/1932>`_).

- New issues about invalid space format. Check is performed while recovering from snapshot in Tarantool 2.x.x
  and can be performed manually with ``require('cartridge.invalid-format').run_check()`` in runtime
  (`#1985 <https://github.com/tarantool/cartridge/issues/1985>`_).

- Descriptions to Vinyl parameters and ``http_address`` in WebUI (`#1803 <https://github.com/tarantool/cartridge/issues/1803>`_).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Fix tarantool binds to 0.0.0.0 despite advertise_uri settings (`#1890 <https://github.com/tarantool/cartridge/issues/1890>`_).

- Reduce count of ``box.info`` calls (`#1924 <https://github.com/tarantool/cartridge/issues/1924>`_).

- Incorrect calculation of Raft leader (`#1943 <https://github.com/tarantool/cartridge/issues/1943>`_).

- Fix ``member_is_healthy`` conditions to prevent send requests to non-role-configured node (`#1949 <https://github.com/tarantool/cartridge/issues/1949>`_).

- ``vshard-storage`` ``apply_config`` won't change order in ``box.cfg.replication`` (`#1950 <https://github.com/tarantool/cartridge/issues/1950>`_).

- Allow to use ``box.NULL`` as label value.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Deprecated
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Usage of invalid labels (`#1980 <https://github.com/tarantool/cartridge/issues/1980>`_).

- Deprecate eventual failover (`#1984 <https://github.com/tarantool/cartridge/issues/1984>`_).

- Usage of invalid space formats in cartridge (`#1985 <https://github.com/tarantool/cartridge/issues/1985>`_).
  See `#1985 <https://github.com/tarantool/tarantool/wiki/Fix-illegal-field-type-in-a-space-format-when-upgrading-to-2.10.4>`_
  for details.

-------------------------------------------------------------------------------
[2.7.6] - 2022-08-22
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Add "Promote a leader" action in WebUI in Raft failover mode (`#1853 <https://github.com/tarantool/cartridge/issues/1853>`_).

- Introduced SSL support for Tarantool Enterprise from 2.10.2 (`#1838 <https://github.com/tarantool/cartridge/issues/1838>`_).

- Introduced Remote Control Suspend/Resume methods to pause producing requests
  (`#1878 <https://github.com/tarantool/cartridge/issues/1878>`_).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Fix multitype argparse params.

- Remove expelled instances from state provider (`#1875 <https://github.com/tarantool/cartridge/issues/1875>`_).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``http`` dependency to `1.3.0 <https://github.com/tarantool/http/releases/tag/1.3.0>`_.

- Update ``ddl`` dependency to `1.6.2 <https://github.com/tarantool/ddl/releases/tag/1.6.2>`_.

- Update ``vshard`` dependency to `0.1.21 <https://github.com/tarantool/vshard/releases/tag/0.1.21>`_.

- Update frontend dependencies.

-------------------------------------------------------------------------------
[2.7.5] - 2022-06-28
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Introduced new failover mode: Raft-based failover (`#1233 <https://github.com/tarantool/cartridge/issues/1233>`_).
  The replicaset leader is chosen by
  built-in Raft, then the other replicasets get information about leader change
  from membership. It's needed to use Cartridge RPC calls. The user can control
  the election mode of an instance by the argparse option ``TARANTOOL_ELECTION_MODE``
  or ``--election-mode``.

- Promotion API for Raft failover (`#1233 <https://github.com/tarantool/cartridge/issues/1233>`_):
  :ref:`cartridge.failover_promote <cartridge.failover_promote>` in Lua or
  ``mutation {cluster{failover_promote()}}`` in GraphQL,
  which calls ``box.ctl.promote`` on the specified instances.
  Note that ``box.ctl.promote`` starts fair elections, so some other instance
  may become the leader in the replicaset.

- Tarantool Raft options and Tarantool 2.10 ``box.cfg`` options are supported in argparse
  (`#1826 <https://github.com/tarantool/cartridge/issues/1826>`_).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``vshard`` dependency to `0.1.20 <https://github.com/tarantool/vshard/releases/tag/0.1.20>`_.

- Failover suppressing (`#1758 <https://github.com/tarantool/cartridge/issues/1758>`_).
  If enabled (by ``enable_failover_suppressing`` parameter
  in ``cartridge.cfg``) then allows to automatically pause failover in runtime.
  It configures with ``failover_suppress_threshold`` and
  ``failover_suppress_timeout`` options of argparse.

- Revert argparse throws an error when it encouters ``instance_name`` missing in
  instances.yml.

- Update ``ddl`` to `1.6.1 <https://github.com/tarantool/ddl/releases/tag/1.6.1>`_.

- Disable schema fetch for ``cartridge.pool`` connections (`#1750 <https://github.com/tarantool/cartridge/issues/1750>`_).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Disable ``vshard.storage`` in case of ``OperationError`` (`#1411 <https://github.com/tarantool/cartridge/issues/1411>`_).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Deprecated
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``vshard`` config option ``collect_lua_garbage`` (`#1814 <https://github.com/tarantool/cartridge/issues/1814>`_).

-------------------------------------------------------------------------------
[2.7.4] - 2022-04-11
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``swim_period`` argument to the test-helpers (`#1592 <https://github.com/tarantool/cartridge/issues/1592>`_).

- ``http_port``, ``http_host`` and ``webui_prefix`` to graphql and webui
  (`#622 <https://github.com/tarantool/cartridge/issues/622>`_,
  `#1527 <https://github.com/tarantool/cartridge/issues/1527>`_).

- Unit tests for the Failover modal.

- Add ``get_servers``, ``get_replicasets`` and ``get_enabled_roles_without_deps`` API
  (`#1624 <https://github.com/tarantool/cartridge/issues/1624>`_,
  `#1722 <https://github.com/tarantool/cartridge/issues/1722>`_).

- Logging of configuration options on start and boot instance
  (`#1557 <https://github.com/tarantool/cartridge/issues/1557>`_).

- ``app_version`` field to graphql and webui. It filled from ``VERSION.lua``
  file in the root of cartridge app (`#1367 <https://github.com/tarantool/cartridge/issues/1367>`_).

- Param ``opts`` to ``Server:upload_config`` in ``test-helpers`` and pass it
  to ``http_request`` (`#1321 <https://github.com/tarantool/cartridge/issues/1321>`_).

- Setters ans getters for timeout options in ``twophase.lua``
  (`#1440 <https://github.com/tarantool/cartridge/issues/1440>`_):
  ``netbox_call_timeout``, ``upload_config_timeout``, ``validate_config_timeout``, ``apply_config_timeout``.

- New tests cases (`#892 <https://github.com/tarantool/cartridge/issues/892>`_,
  `#944 <https://github.com/tarantool/cartridge/issues/944>`_,
  `#1473 <https://github.com/tarantool/cartridge/issues/1473>`_,
  `#1726 <https://github.com/tarantool/cartridge/issues/1726>`_).

- ``test-helpers.Cluster:server_by_role`` method (`#1615 <https://github.com/tarantool/cartridge/issues/1615>`_).

- Allow to extract filename from http request body (`#1613 <https://github.com/tarantool/cartridge/issues/1613>`_).

- Testing on Tarantool pre-release version.

- ``box.info.ro_reason`` and ``box.info.replication.X.downstream.lag``
  to boxinfo API (`#1721 <https://github.com/tarantool/cartridge/issues/1721>`_).

- Ability to set multiple types for Cartridge arguments.
  Types are split by separator ``|``,  e.g. ``string|number``
  (`#1651 <https://github.com/tarantool/cartridge/issues/1651>`_).

- Downgrade test (`#1397 <https://github.com/tarantool/cartridge/issues/1397>`_).

- Vshard weight parameter to ``test-helpers.Cluster.replicasets``
  (`#1743 <https://github.com/tarantool/cartridge/issues/1743>`_).

- Add logging for role machinery (`#1745 <https://github.com/tarantool/cartridge/issues/1745>`_).

- Export vshard config in Lua API (`#1761 <https://github.com/tarantool/cartridge/issues/1761>`_).

- New ``failover_promote`` option ``skip_error_on_change`` to skip etcd error
  when vclockkeeper was changed between ``set_vclokkeeper`` calls
  (`#1399 <https://github.com/tarantool/cartridge/issues/1399>`_).

- Allow to pause failover at runtime, with Lua API and GraphQL
  (`#1763 <https://github.com/tarantool/cartridge/issues/1763>`_).

- Allow to block roles reload at runtime, with Lua API
  (`#1219 <https://github.com/tarantool/cartridge/issues/1219>`_).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update ``http`` dependency to `1.2.0 <https://github.com/tarantool/http/releases/tag/1.2.0>`_.

- Allow to bootstrap vshard groups partially (`#1148 <https://github.com/tarantool/cartridge/issues/1148>`_).

- Use effector for business logic and storing Cluster page data (models folder).

- Rewrite all Cluster page components using typescript.

- Improve the error message in login dialog.

- Use core as a node module instead of a window scope object.

- Update ``frontend-core`` dependency to 8.1.0.

- Update ``graphql`` dependency to `0.1.4 <https://github.com/tarantool/graphql/releases/tag/0.1.4>`_ .

- Bind remote control socket to ``advertise_uri`` (`#1495 <https://github.com/tarantool/cartridge/issues/1495>`_).

- The new compact design of the Cluster page.

- Update ``vshard`` dependency to `0.1.19 <https://github.com/tarantool/graphql/vshard/tag/0.1.19>`_.

- Change type of ``replication_synchro_quorum`` in argparse to ``string|number``.

- Update ``ddl`` dependency to `1.6.0 <https://github.com/tarantool/ddl/releases/tag/1.6.0>`_.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Fix joining an instance when leader is not the first instance from leaders_order
  (`#1204 <https://github.com/tarantool/cartridge/issues/1204>`_).

- Fix the incorrect number of total buckets on the replication server in webui
  (`#1176 <https://github.com/tarantool/cartridge/issues/1176>`_).

- Fix GraphQL query ``auth_params.username`` returns empty string instead of ``username``.

- Flaky tests (`#1538 <https://github.com/tarantool/cartridge/issues/1538>`_,
  `#1569 <https://github.com/tarantool/cartridge/issues/1569>`_,
  `#1590 <https://github.com/tarantool/cartridge/issues/1590>`_,
  `#1594 <https://github.com/tarantool/cartridge/issues/1594>`_,
  `#1599 <https://github.com/tarantool/cartridge/issues/1599>`_,
  `#1602 <https://github.com/tarantool/cartridge/issues/1602>`_,
  `#1656 <https://github.com/tarantool/cartridge/issues/1656>`_,
  `#1657 <https://github.com/tarantool/cartridge/issues/1657>`_,
  `#1658 <https://github.com/tarantool/cartridge/issues/1658>`_,
  `#1664 <https://github.com/tarantool/cartridge/issues/1664>`_,
  `#1671 <https://github.com/tarantool/cartridge/issues/1671>`_,
  `#1681 <https://github.com/tarantool/cartridge/issues/1681>`_,
  `#1682 <https://github.com/tarantool/cartridge/issues/1682>`_,
  `#1683 <https://github.com/tarantool/cartridge/issues/1683>`_,
  `#1703 <https://github.com/tarantool/cartridge/issues/1703>`_,
  `#1709 <https://github.com/tarantool/cartridge/issues/1709>`_,
  `#1751 <https://github.com/tarantool/cartridge/issues/1751>`_,
  `#1756 <https://github.com/tarantool/cartridge/issues/1756>`_).

- Tests compatibility with tarantool/master (`#1619 <https://github.com/tarantool/cartridge/issues/1619>`_).

- Tests improvements on macOS (`#1638 <https://github.com/tarantool/cartridge/issues/1638>`_).

- ``fetch-schema`` script on macOS (`#1628 <https://github.com/tarantool/cartridge/issues/1628>`_).

- Stateful failover triggers when instance is in OperationError state
  (`#1139 <https://github.com/tarantool/cartridge/issues/1139>`_).

- Fix ``rpc_call`` failure in case if the role hasn't been activated yet on target instance
  (`#1575 <https://github.com/tarantool/cartridge/issues/1575>`_).

- Fixed the visibility of the configuration management page if the cluster
  is not bootstrapped yet (`#1707 <https://github.com/tarantool/cartridge/issues/1707>`_).

- Error when vclockkeeper in stateboard was changed between ``failover_promote`` calls
  (`#1399 <https://github.com/tarantool/cartridge/issues/1399>`_).

-------------------------------------------------------------------------------
[2.7.3] - 2021-10-27
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Disabled role's ``validate_config`` is not called during config validation.

- Update @tarantool.io/ui-kit and frontend-core dependencies to support
  the new design style.

-------------------------------------------------------------------------------
[2.7.2] - 2021-10-08
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- 'Make all instances writeable' configuration field can be hidden via
  frontend-core's ``set_variable`` feature or at runtime.

- New ``get_issues`` callback in role API to collect user-defined issues.
  The issues are gathered from the enabled roles only (present in
  ``service-registry``).

- Allow disabling built-in HTTP "admin" user:

  * by specifying ``auth_builtin_admin_enabled: false`` in the ``instances.yml``;

  * using ``TARANTOOL_AUTH_BUILTIN_ADMIN_ENABLED=false`` environment variable;

  * permanently in ``init.lua``:


    .. code-block:: lua

        -- init.lua

        require('cartridge.auth-backend').set_builtin_admin_enabled(false)
        cartridge.cfg({
            auth_backend_name = 'cartridge.auth-backend',
            ...
        })

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Make built-in HTTP "admin" user a part of default auth backend. Custom
  backends are free of it now.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Eliminate unnecessary transactions after the restart before the replication
  sync. This reduces the chance the hardware restart leads to WAL corruption
  (`#1546 <https://github.com/tarantool/cartridge/issues/1546>`__).

- Fix net.box clients compatibility with future tarantool 2.10 versions.

- Fix vshard rebalancer broken by roles reload.

-------------------------------------------------------------------------------
[2.7.1] - 2021-08-18
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Compatibility with Tarantool 2.9 (update ``errors`` dependency to 2.2.1).

-------------------------------------------------------------------------------
[2.7.0] - 2021-08-10
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- New suggestion to restart replication. Whenever the replication isn't running
  and the reason isn't in the dead upstream, Cartridge will show the
  corresponding banner in WebUI.

- More server details in WebUI: membership, vshard-router, and vshard-storage.

- Roles are stopped with the ``on_shutdown`` trigger where it's supported
  (in Tarantool 2.8+).

- New ``cartridge.cfg`` options:

  - ``webui_prefix`` (default: ``""``) allows to modify WebUI routes.
  - ``webui_enforce_root_redirect`` (default: ``true``) manage redirection.

  To sum up, now they look as follows:

  - ``<PREFIX>/admin/``;
  - ``<PREFIX>/admin/api``;
  - ``<PREFIX>/admin/config``;
  - ``<PREFIX>/admin/cluster/*``;
  - ``<PREFIX>/static/*``;
  - ``<PREFIX>/login``;
  - ``<PREFIX>/logout``;
  - ``/`` and ``<PREFIX>/`` redirect to ``/<PREFIX>/admin`` (if enabled).

- New ``validate_config`` method in GraphQL API.

- Add ``zone`` and ``zone_distances`` parameters to test helpers.

- Support ``rebalancer_max_sending`` vshard option.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Merge "Schema" and "Code" pages. Also, allow validating all files, not only
  the ``schema.yml``.

- Allow expelling a leader. Cartridge will appoint a new leader according to the
  failover priority from the topology.

- Add default ``pool.map_call`` timeout 10 seconds.

- Forbid starting an instance absent in ``instances.yml``.

- Update ``errors`` dependency to 2.2.0 with a new method
  ``errors.netbox_wait_async`` to wait for ``netbox.future`` result.

- Update ``membership`` dependency to 2.4.0
  (`Changelog <https://github.com/tarantool/membership/releases/tag/2.4.0>`__).

- Update ``ddl`` dependency to 1.5.0 which supplements the clusterwide config
  with an example schema (`Changelog <https://github.com/tarantool/ddl/releases/tag/1.5.0>`__).

- Update ``vshard`` to 0.1.18
  (`Changelog <https://github.com/tarantool/vshard/releases/tag/0.1.18>`__).


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Leaders replaced during stateful failover can be expelled now.

- Make failover logging more verbose.

- Fix hot-reload for roles that leave gaps in httpd routes.

- Check user e-mail uniqueness when editing.

- Expelled instances are removed from the ``_cluster`` space.

- Fix ``get_enabled_roles`` to work without arguments.

- Don't default to syslog driver unless ``/dev/log`` or ``/var/run/syslog`` are
  available.

- Fix inappropriate consistency timeout that led to "Timed out" error during
  forceful leader promotion.

- Support automatic parsing of Tarantool Enterprise box options ``audit_log``
  and ``audit_nonblock``.

- Instance won't suspect any members during ``RecoveringSnapshot`` and
  ``BootstrappingBox``.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Enhanced in WebUI
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Allow to blacklist subpages for complex modules.

- Fix notifications displaying. Close it by clicking anywhere. Keep it open
  while the mouse is over.

- Various styles enhancements.

-------------------------------------------------------------------------------
[2.6.0] - 2021-04-26
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update vshard to 0.1.17.
  (`Changelog <https://github.com/tarantool/vshard/releases/tag/0.1.17>`__).

- Update graphql to 0.1.1.
  (`Changelog <https://github.com/tarantool/graphql/releases/tag/0.1.1>`__).

- New test helper: ``cartridge.test-helpers.stateboard``.

- New ``failover`` option in the cluster test helper for easier failover setup.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Move DDL related code out of Cartridge and ship it as a permaent role in the
  ddl rock. No observable functionality is affected. The roles remains
  registered implicitly. Nonetheless it's recomended to add it explicitly to
  ``cartridge.cfg({roles = {'cartridge.roles.ddl-manager'}})`` (if it's
  actually used) as this implicity may be removed in future.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Fix unclear timeout errors in case of ``InitError`` and ``BootError`` states.

- Fix inconsistency which could occur while longpolling stateboard in unstable
  networks.

- Increase timeout for the ``validate_config`` stage from 1 to 10 seconds.
  It afftected ``config_patch_clusterwide`` in v2.5, mostly on large clusters.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Enhanced in WebUI
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Highlight if file name exists in file create/rename mode on Code page.

-------------------------------------------------------------------------------
[2.5.1] - 2021-03-24
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Extend GraphQL ``issues`` API with ``aliens`` topic. The issues warns if
  two separate clusters share the same cluster cookie.

- Enhance error messages when they're transferred over network. Supply it
  with the connection URI.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Don't skip two-phase commit prematurely. From now on, the decision to skip
  the ``apply_config`` is made by every instance individually. The validation
  step is never skipped.

- Avoid WebUI and ``pool.map_call`` requests hanging because of network
  connection problems.

- Fix unclear "Timeout exceeded" error. It affects v2.5.0 two-phase commit
  when an instance is stuck in ``ConfiguringRoles`` state.

- Make the "Replication isn't running" issue critical instead of a warning.

-------------------------------------------------------------------------------
[2.5.0] - 2021-03-05
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Issues and suggestions:

- Show an issue when ``ConfiguringRoles`` state gets stuck for more than 5s.

- New GraphQL API: ``{ cluster { suggestions { force_apply } } }`` to heal the
  cluster in case of config errors like ``Configuration checksum mismatch``,
  ``Configuration is prepared and locked``, and sometimes ``OperationError``.

- New GraphQL API: ``{ cluster { suggestions { disable_servers } } }`` to
  restore the quorum in case of some servers go offline.

Configuration options:

- New ``cartridge.cfg`` option ``webui_enabled`` (default: ``true``). Otherwise,
  HTTP server remains operable (and GraphQL too), but serves user-defined
  roles API only.

- New ``cartridge.cfg`` option ``http_host`` (default: ``0.0.0.0``) which
  allows to specify the bind address of the HTTP server.

Miscellaneous:

- Allow observing cluster from an unconfigured instance WebUI.

- Introduce a new graphql parser (``libgraphqlparser`` instead of ``lulpeg``).
  It conforms to the newer GraphQL specification and provides better error
  messages. The "null" literal is now supported. But some other GraphQL
  expressions are considered invalid (e.g. empty subselection).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Properly handle etcd index updates while polling stateful failover updates.
  The problem affected long-running clusters and resulted in flooding logs with
  the "Etcd cluster id mismatch" warnings.

- Refactor two-phase commit (``patch_clusterwide``) logics: don't use hardcoded
  timeout for the ``prepare`` stage, move ``upload`` to a separate stage.

- Eliminate GraphQL error "No value provided for non-null ReplicaStatus" when
  a replica is removed from the ``box.space._cluster``.

- Allow specifying server zone in ``join_server`` API.

- Don't make formatting ugly during config upload.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Enhanced is WebUI
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Allow disabling instances and fix their style.
- Show a suggestion to disable broken instances.
- Show a suggestion to force reapply clusterwide configuration.
- Hide the bootstrap button when it's not necessary (e.g. before the cluster
  is bootstrapped, and in vshardless cluster too).
- Properly display an error if changing server zone fails.

-------------------------------------------------------------------------------
[2.4.0] - 2020-12-29
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Zones and zone distances:

- Add support of replica weights and zones via a clusterwide config new section
  ``zone_distances`` and a server parameter ``zone``.

Fencing:

- Implement a fencing feature. It protects a replicaset from the presence of
  multiple leaders when the network is partitioned and forces the leader to
  become read-only.

- New failover parameter ``failover_timout`` specifies the time (in seconds)
  used by membership to mark ``suspect`` members as ``dead`` which triggers
  failover.

- Fencing parameters ``fencing_enabled``, ``fencing_pause``, ``fencing_timeout``
  are available for customization via Lua and GraphQL API, and in WebUI too.

Issues and suggestions:

- New GraphQL API: ``{ cluster { suggestions { refine_uri } } }`` to heal the
  cluster after relocation of servers ``advertise_uri``.

- New Lua API ``cartridge.config_force_reapply()`` and similar GraphQL mutation
  ``cluster { config_force_reapply() }`` to heal several operational errors:

  - "Prepare2pcError: Two-phase commit is locked";
  - "SaveConfigError: .../config.prepare: Directory not empty";
  - "Configuration is prepared and locked on ..." (an issue);
  - "Configuration checksum mismatch on ..." (an issue).

  It'll unlock two-phase commit (remove ``config.prepare`` lock), upload the
  active config from the current instance and reconfigure all roles.

Hot-reload:

- New feature for hot reloading roles code without restarting an instance --
  ``cartridge.reload_roles``. The feature is experimental and should be
  enabled explicitly: ``cartridge.cfg({roles_reload_allowed = true})``.

Miscellaneous:

- New ``cartridge.cfg`` option ``swim_broadcast`` to manage
  instances auto-discovery on start. Default: true.

- New argparse options support for tarantool 2.5+:
  ``replication_synchro_quorum``, ``replication_synchro_timeout``,
  ``memtx_use_mvcc_engine``.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Default value of ``failover_timeout`` increased from 3 to 20 seconds
  **(important change)**.

- RPC functions now consider ``suspect`` members as healthy to be in agreement
  with failover **(important change)**.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Don't stuck in ``ConnectingFullmesh`` state when instance is restarted with a
  different ``advertise_uri``. Also keep "Server details" dialog in WebUI
  operable in this case.

- Allow applying config when instance is in ``OperationError``. It doesn't cause
  loss of quorum anymore.

- Stop vshard fibers when the corresponding role is disabled.

- Make ``console.listen`` error more clear when ``console_sock`` exceeds
  ``UNIX_PATH_MAX`` limit.

- Fix ``upstream.idle`` issue tolerance to avoid unnecessary warnings
  "Replication: long idle (1 > 1)".

- Allow removing spaces from DDL schema for the sake of ``drop`` migrations.

- Make DDL schema validation stricter. Forbid redundant keys in schema top-level
  and make ``spaces`` mandatory.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Enhanced is WebUI
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update server details modal, add support for server zones.
- Properly display errors on WebUI pages "Users" and "Code".
- Indicate config checksum mismatch in issues list.
- Indicate the change of ``arvertise_uri`` in issues list.
- Show an issue if the clusterwide config is locked on an instance.
- Refresh interval and stat refresh period variables can be customized via
  frontend-core's ``set_variable`` feature or at runtime.

-------------------------------------------------------------------------------
[2.3.0] - 2020-08-26
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- When failover mode is stateful, all manual leader promotions will be consistent:
  every instance before becoming writable performs ``wait_lsn`` operation to
  sync with previous one. If consistency couldn't be reached due to replication
  failure, a user could either revert it (promote previous leader), or force
  promotion to be inconsistent.
- Early logger initialization (for Tarantool > 2.5.0-100, which supports it).
- Add ``probe_uri_timeout`` argparse option responsible for retrying
  "Can't ping myself" error on startup.
- New test helper: ``cartridge.test-helpers.etcd``.
- Support ``on_push`` and ``on_push_ctx`` options for ``cartridge.rpc_call()``.
- Changing users password invalidates HTTP cookie.
- Support GraphQL `default variables <https://graphql.org/learn/queries/#default-variables>`_.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Eventual failover may miss an event while roles are being reconfigured.
- Compatibility with pipe logging, see
  `tarantool/tarantool#5220 <https://github.com/tarantool/tarantool/issues/5220>`_.
- Non-informative assertion when instance is bootstrapped with a distinct
  ``advertise_uri``.
- Indexing ``nil`` value in ``get_topology()`` query.
- Initialization race of vshard storage which results in ``OperationError``.
- Lack of vshard router attempts to reconnect to the replicas.
- Make GraphQL syntax errors more clear.
- Better ``errors.pcall()`` performance, ``errors`` rock updated to v2.1.4.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Enhanced is WebUI
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Show instance names in issues list.
- Show app name in window title.
- Add the "Force leader promotion" button in the stateful failover mode.
- Indicate consistent switchover problems with a yellow leader flag.

-------------------------------------------------------------------------------
[2.2.0] - 2020-06-23
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- When running under systemd use ``<APP_NAME>.<INSTANCE_NAME>`` as
  default syslog identity.
- Support ``etcd`` as state provider for stateful failover.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Improve rocks detection for feedback daemon. Besides cartridge version it
  now parses manifest file from the ``.rocks/`` directory and collects rocks
  versions.
- Make ``uuid`` parameters optional for test helpers.
  Make ``servers`` option accept number of servers in replicaset.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Enhanced in WebUI
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Prettier errors displaying.
- Enhance replicaset filtering by role / status.
- Error stacktrace received from the backend is shown in notifications.

-------------------------------------------------------------------------------
[2.1.2] - 2020-04-24
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Avoid trimming ``console_sock`` if it's name is too long.

- Fix file descriptors leak during box recovery.

- Support ``console_sock`` option in stateboard as well as notify socket
  and other box options similar to regular cartridge instances.

-------------------------------------------------------------------------------
[2.1.1] - 2020-04-20
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Frontend core update: fix route mapping

-------------------------------------------------------------------------------
[2.1.0] - 2020-04-16
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Implement stateful failover mode. You can read more in
  ":ref:`Failover architecture <cartridge-failover>`" documentation topic.

- Respect ``box.cfg`` options ``wal_dir``, ``memtx_dir``, ``vinyl_dir``. They
  can be either absolute or relative - in the later case it's calculated
  relative to ``cartridge.workdir``.

- New option in ``cartridge.cfg({upgrade_schema=...})``
  to automatically upgrade schema to modern tarantool version
  (only for leader). It also has been added for ``argparse``.

- Extend GraphQL ``issues`` API with various topics: ``replication``,
  ``failover``, ``memory``, ``clock``. Make thresholds configurable via
  argparse.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Make GraphQL validation stricter: scalar values can't have
  sub-selections; composite types must have sub-selections; omitting
  non-nullable arguments in variable list is forbidden. Your code **may
  be affected** if it doesn't conform GraphQL specification.

- GraphQL query ``auth_params`` returns "fullname" (if it was specified)
  instead of "username".

- Update ``errors`` dependency to 2.1.3.

- Update ``ddl`` dependency to 1.1.0.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Deprecated
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Lua API:

- ``cartridge.admin_get_failover`` -> ``cartridge.failover_get_params``
- ``cartridge.admin_enable/disable_failover`` -> ``cartridge.failover_set_params``

GraphQL API:

- ``query {cluster {failover} }`` -> ``query {cluster {failover_params {...} } }``
- ``mutation {cluster {failover()} }`` -> ``mutation {cluster {failover_params() {...} } }``

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Properly handle nested input object in GraphQL:

  .. code-block:: text

      mutation($uuid: String!) {
        cluster { edit_topology(servers: [{uuid: $uuid ...}]) {} }
      }

- Show WebUI notification on successful config upload.

- Repair GraphQL queries ``add_user``, ``issues`` on uninitialized instance.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Enhanced in WebUI
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Show "You are here" marker.

- Show application and instance names in app title.

- Indicate replication and failover issues.

- Fix bug with multiple menu items selected.

- Refactor pages filtering, forbid opening blacklisted pages.

- Enable JS chunks caching.

-------------------------------------------------------------------------------
[2.0.2] - 2020-03-17
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Expose membership options in ``argparse`` module (edit them with
  environment variables and command-line arguments).

- New internal module to handle ``.tar`` files.

Lua API:

- ``cartridge.cfg({webui_blacklist = {'/admin/code', ...}})``: blacklist
  certain WebUI pages.

- ``cartridge.get_schema()`` referencing older ``_G.cartridge_get_schema``.

- ``cartridge.set_schema()`` referencing older ``_G.cartridge_set_schema``.

GraphQL API:

- Make use of GraphQL error extensions: provide additional information
  about ``class_name`` and ``stack`` of original error.

- ``cluster{ issues{ level message ... }}``: obtain more details on
  replication status

- ``cluster{ self {...} }``: new fields ``app_name``, ``instance_name``.

- ``servers{ boxinfo { cartridge {...} }}``: new fields ``version``,
  ``state``, ``error``.

Test helpers:

- Allow specifying ``all_rw`` replicaset flag in luatest helpers.

- Add ``cluster({env = ...})`` option for specifying clusterwide
  environment variables.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Remove redundant topology availability checks from two-phase commit.

- Prevent instance state transition from ``ConnectingFullmesh`` to
  ``OperationError`` if replication fails to connect or to sync. Since now
  such fails result in staying in ``ConnectingFullmesh`` state until it
  succeeds.

- Specifying ``pool.connect()`` options ``user``, ``password``,
  ``reconnect_after`` are deprecated and ignored, they never worked as
  intended and will never do. Option ``connect_timeout`` is deprecated,
  but for backward compatibility treated as ``wait_connected``.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Fix DDL failure if ``spaces`` field is ``null`` in input schema.

- Check content of ``cluster_cookie`` for absence of special
  characters so it doesn't break the authorization.
  Allowed symbols are ``[a-zA-Z0-9_.~-]``.

- Drop remote-control connections after full-featured ``box.cfg`` becomes
  available to prevent clients from using limited functionality for too
  long. During instance recovery remote-control won't accept any
  connections: clients wait for box.cfg to finish recovery.

- Update errors rock dependency to 2.1.2: eliminate duplicate stack
  trace from ``error.str`` field.

- Apply ``custom_proc_title`` setting without waiting for ``box.cfg``.

- Make GraphQL compatible with ``req:read_cached()`` call in httpd hooks.

- Avoid "attempt to index nil value" error when using rpc on an
  uninitialized instance.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Enhanced in WebUI
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Add an ability to hide certain WebUI pages.

- Validate YAML in code editor WebUI.

- Fix showing errors in Code editor page.

- Remember last open file in Code editor page.
  Open first file when local storage is empty.

- Expand file tree in Code editor page by default.

- Show Cartridge version in server info dialog.

- Server alias is clickable in replicaset list.

- Show networking errors in splash panel instead of notifications.

- Accept float values for vshard-storage weight.

-------------------------------------------------------------------------------
[2.0.1] - 2020-01-15
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Expose ``TARANTOOL_DEMO_URI`` environment variable in GraphQL query
  ``cluster{ self{demo_uri} }`` for demo purposes.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Notifications in schema editor WebUI.

- Fix GraphQL ``servers`` query compatibility with old cartridge versions.

- Two-phase commit backward compatibility with v1.2.0.

-------------------------------------------------------------------------------
[2.0.0] - 2019-12-27
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Use for frontend part single point of configuration HTTP handlers.
  As example: you can add your own client HTTP middleware for auth.

- Built-in DDL schema management. Schema is a part of clusterwide
  configuration. It's applied to every instance in cluster.

- DDL schema editor and code editor pages in WebUI.

- Instances now have internal state machine which helps to manage
  cluster operation and protect from invalid state transitions.

- WebUI checkbox to specify ``all_rw`` replicaset property.

- GraphQL API for clusterwide configuration management.

- Measure clock difference across instances and provide ``clock_delta``
  in GraphQL ``servers`` query and in ``admin.get_servers()`` Lua API.

- New option in ``rpc_call(..., {uri=...})`` to perform a call
  on a particular uri.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``cartridge.rpc_get_candidates()`` doesn't return error "No remotes with
  role available" anymore, empty table is returned instead.
  **(incompatible change)**

- Base advertise port in luatest helpers changed from 33000 to 13300,
  which is outside ``ip_local_port_range``. Using port from local range
  usually caused tests failing with an error "address already in use".
  (*incompatible change*, but affects tests only)

- Whole new way to bootstrap instances. Instead of polling membership
  for getting clusterwide config the instance now start Remote Control
  Server (with limited iproto protocol functionality) on the same port.
  Two-phase commit is then executed over net.box connection.
  (**major change**, but still compatible)

- Failover isn't triggered on ``suspect`` instance state anymore

- Functions ``admin.get_servers``, ``get_replicasets`` and similar GraphQL
  queries now return an error if the instance handling the request is in
  state ``InitError`` or ``BootError``.

- Clusterwide configuration is now represented with a file tree.
  All sections that were tables are saved to separate ``.yml`` files.
  Compatibility with the old-style configuration is preserved.
  Accessing unmarshalled sections with ``get_readonly/deepcopy`` methods
  is provided without ``.yml`` extension as earlier.
  (**major change**, but still compatible)

- After an old leader restarts it'll try to sync with an active one
  before taking the leadership again so that failover doesn't switch too
  early before leader finishes recovery. If replication setup fails the
  instance enters the ``OperationError`` state, which can be avoided by
  explicitly specifying ``replication_connect_quorum = 1`` (or 0).
  **(major change)**

- Option ``{prefer_local = false}`` in ``rpc_call`` makes it always use
  netbox connection, even to connect self. It never tries to perform
  call locally.

- Update ``vshard`` dependency to 0.1.14.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Removed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Function ``cartridge.bootstrap`` is removed. Use ``admin_edit_topology``
  interad. **(incompatible change)**

- Misspelled role callback ``validate`` is now removed completely.
  Keep using ``validate_config``.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Arrange proper failover triggering: don't miss events, don't trigger
  if nothing changed. Fix races in calling ``apply_config`` between
  failover and two-phase commit.

- Race condition when creating working directory.

- Hide users page in WebUI when auth backend implements no user
  management functions. Enable auth switcher is displayed on main
  cluster page in this case.

- Displaying boolean values in server details.

- Add deduplication for WebUI notifications: no more spam.

- Automatically choose default vshard group in create and edit
  replicaset modals.

- Enhance WebUI modals scrolling.

-------------------------------------------------------------------------------
[1.2.0] - 2019-10-21
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- 'Auto' placeholder to weight input in the Replicaset forms.

- 'Select all' and 'Deselect all' buttons to roles field in Replicaset add and edit forms.

- Refresh replicaset list in UI after topology edit actions: bootstrap, join, expel,
  probe, replicaset edit.

- New Lua API ``cartridge.http_authorize_request()`` suitable for checking
  HTTP request headers.

- New Lua API ``cartridge.http_render_response()`` for generating HTTP
  response with proper ``Set-Cookie`` headers.

- New Lua API ``cartridge.http_get_username()`` to check authorization of
  active HTTP session.

- New Lua API ``cartridge.rpc_get_candidates()`` to get list
  of instances suitable for performing a remote call.

- Network error notification in UI.

- Allow specifying vshard storage group in test helpers.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Get UI components from Tarantool UI-Kit

- When recovering from snapshot, instances are started read-only.
  It is still possible to override it by argparse (command line
  arguments or environment variables)

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Editing topology with ``failover_priority`` argument.
- Now ``cartridge.rpc.get_candidates()`` returns value as specified in doc.
  Also it accepts new option ``healthy_only`` to filter instances which
  have membership status healthy.

- Replicaset weight tooltip in replicasets list

- Total buckets count in buckets tooltip

- Validation error in user edit form

- Leader flag in server details modal

- Human-readable error for invalid GrqphQL queries:
  ``Field "x" is not defined on type "String"``

- User management error "attempt to index nil value" when one of users
  has empty e-mail value

- Catch ``rpc_call`` errors when they are performed locally

-------------------------------------------------------------------------------
[1.1.0] - 2019-09-24
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- New Lua API ``admin_edit_topology`` has been added to unite multiple others:
  ``admin_edit_replicaset``, ``admin_edit_server``, ``admin_join_server``,
  ``admin_expel_server``. It's suitable for editing multiple servers/replicasets
  at once. It can be used for bootstrapping cluster from scratch, joining a
  server to an existing replicaset, creating new replicaset with one or more
  servers, editing uri/labels of servers, disabling or expelling servers.

- Similar API is implemented in a GraphQL mutation ``cluster{edit_topology()}``.

- New GraphQL mutation ``cluster { edit_vshard_options }`` is suitable for
  fine-tuning vshard options: ``rebalancer_max_receiving``, ``collect_lua_garbage``,
  ``sync_timeout``, ``collect_bucket_garbage_interval``,
  ``rebalancer_disbalance_threshold``.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Both bootstrapping from scratch and patching topology in clusterwide config automatically probe
  servers, which aren't added to membership yet (earlier it influenced join_server mutation only).
  This is a prerequisite for multijoin api implementation.

- WebUI users page is hidden if auth_backend doesn't provide list_users callback.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Deprecated
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Lua API:

- ``cartridge.admin_edit_replicaset()``
- ``cartridge.admin_edit_server()``
- ``cartridge.admin_join_server()``
- ``cartridge.admin_expel_server()``

GraphQL API:

- ``mutation{ edit_replicaset() }``
- ``mutation{ edit_server() }``
- ``mutation{ join_server() }``
- ``mutation{ expel_server() }``

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Protect ``users_acl`` and ``auth`` sections when downloading clusterwide config.
  Also forbid uploading them.

-------------------------------------------------------------------------------
[1.0.0] - 2019-08-29
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- New parameter ``topology.replicasets[].all_rw`` in clusterwide config for configuring
  all instances in the replicaset as ``read_only = false``.
  It can be managed with both GraphQL and Lua API ``edit_replicaset``.

- Remote Control server - a replacement for the ``box.cfg({listen})``,
  with limited functionality, independent on ``box.cfg``.
  The server is only to be used internally for bootstrapping new
  instances.

- New module ``argparse`` for gathering configuration options from
  command-line arguments, environment variables, and configuration files.
  It is used internally and overrides ``cluster.cfg`` and ``box.cfg`` options.

- Auth parameter ``cookie_max_age`` is now configurable with GraphQL API.
  Also now it's stored in clusterwide config, so changing it on a single server will affect
  all others in cluster.

- Detect that we run under systemd and switch to syslog logging from
  stderr. This allows to filter log messages by severity with
  ``journalctl``

- Redesign WebUI

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- The project renamed to **cartridge**.
  Use ``require('cartridge')`` instead of ``require('cluster')``.
  All submodules are renamed too.
  **(incompatible change)**

- Submodule ``cluster.test_helpers`` renamed to ``cartridge.test-helpers`` for consistency.
  **(incompatible change)**

- Modifying auth params with GraphQL before the cluster was bootstrapped is now
  forbidden and returns an error.

- Introducing a new auth parameter ``cookie_renew_age``. When cluster handles an HTTP request
  with the cookie, whose age in older then specified, it refreshes the cookie.
  It may be useful to set ``cookie_max_age`` to a small value (for example 10 minutes),
  so the user will be logged out after ``cookie_max_age`` seconds of inactivity.
  Otherwise, if he's active, the cookie will be updated every ``cookie_renew_age`` seconds
  and the session will not be interrupted.

- Changed configuration options for ``cluster.cfg()``:
  ``roles`` now is a mandatory table, ``workdir`` is optional now (defaults to ".")

- Parameter ``advertise_uri`` is optional now, default value is derived as follows.
  ``advertise_uri`` is a compound of ``<HOST>`` and ``<PORT>``.
  When ``<HOST>`` isn't specified, it's detected as the only non-local IP address.
  If it can't be determined or there is more than one IP address available it
  defaults to ``"localhost"``.
  When ``<PORT>`` isn't specified, it's derived from numeric suffix ``_<N>`` of
  ``TARANTOOL_INSTANCE_NAME``: ``<PORT> = 3300+<N>``.
  Otherwise default ``<PORT> = 3301`` is used.

- Parameter ``http_port`` is derived from instance name too. If it can't be derived
  it defaults to 8081. New parameter ``http_enabled = false`` is used to disable it
  (by default it's enabled).

- Removed user ``cluster``, which was used internally for orchestration over netbox.
  Tarantool built-in user ``admin`` is used instead now. It can also be used for HTTP
  authentication to access WebUI. Cluster cookie is used as a password in both cases.
  **(incompatible change)**

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Removed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Two-layer table structure in API, which was deprecated earlier, is now removed completely:

- ``cartridge.service_registry.*``
- ``cartridge.confapplier.*``
- ``cartridge.admin.*``

Instead you can use top-level functions:

- ``cartridge.config_get_readonly``
- ``cartridge.config_get_deepcopy``
- ``cartridge.config_patch_clusterwide``
- ``cartridge.service_get``
- ``cartridge.admin_get_servers``
- ``cartridge.admin_get_replicasets``
- ``cartridge.admin_probe_server``
- ``cartridge.admin_join_server``
- ``cartridge.admin_edit_server``
- ``cartridge.admin_expel_server``
- ``cartridge.admin_enable_servers``
- ``cartridge.admin_disable_servers``
- ``cartridge.admin_edit_replicaset``
- ``cartridge.admin_get_failover``
- ``cartridge.admin_enable_failover``
- ``cartridge.admin_disable_failover``

-------------------------------------------------------------------------------
[0.10.0] - 2019-08-01
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Cluster can now operate without vshard roles (if you don't need sharding).
  Deprecation warning about implicit vshard roles isn't issued any more,
  they aren't registered unless explicitly specified either in ``cluster.cfg({roles=...})``
  or in ``dependencies`` to one of user-defined roles.

- New role flag ``hidden = true``. Hidden roles aren't listed in
  ``cluster.admin.get_replicasets().roles`` and therefore in WebUI.
  Hidden roles are supposed to be a dependency for another role, yet they still can be
  enabled with ``edit_replicaset`` function (both Lua and GraphQL).

- New role flag: ``permanent = true``.
  Permanent roles are always enabled. Also they are hidden implicitly.

- New functions in cluster test_helpers - ``Cluster:upload_config(config)`` and ``Cluster:download_config()``

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``cluster.call_rpc`` used to return 'Role unavailable' error as a first argument
  instead of ``nil, err``. It can appear when role is specified in clusterwide config,
  but wasn't initialized properly. There are two reasons for that: race condition,
  or prior error in either role ``init`` or ``apply_config`` methods.

-------------------------------------------------------------------------------
[0.9.2] - 2019-07-12
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Update frontend-core dependency which used to litter
  ``package.loaded`` with tons of JS code

-------------------------------------------------------------------------------
[0.9.1] - 2019-07-10
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Support for vshard groups in WebUI

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Uniform handling vshard group 'default' when
  multiple groups aren't configured
- Requesting multiple vshard groups info before the cluster
  was bootstrapped

-------------------------------------------------------------------------------
[0.9.0] - 2019-07-02
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- User management page in WebUI
- Configuring multiple isolated vshard groups in a single cluster
- Support for joining multiple instances in a single call to config_patch_clusterwide
- Integration tests helpers

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- GraphQL API ``known_roles`` format now includes roles dependencies

- ``cluster.rpc_call`` option ``remote_only`` renamed to ``prefer_local``
  with the opposite meaning

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Don't display renamed or removed roles in webui
- Uploading config without a section removes it from clusterwide config

-------------------------------------------------------------------------------
[0.8.0] - 2019-05-20
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Specifying role dependencies
- Set read-only option for slave nodes
- Labels for servers

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Admin http endpoint changed from /graphql to /admin/api
- Graphql output now contains null values for empty objects

- Deprecate implicity of vshard roles
  ``'cluster.roles.vshard-storage'``, ``'cluster.roles.vshard-router'``.
  Now they should be specified explicitly in ``cluster.cfg({roles = ...})``

- ``cluster.service_get('vshard-router')`` now returns
  ``cluster.roles.vshard-router`` module instead of ``vshard.router``
  **(incompatible change)**

- ``cluster.service_get('vshard-storage')`` now returns
  ``cluster.roles.vshard-storage`` module instead of `vshard.storage``
  **(incompatible change)**

- ``cluster.admin.bootstrap_vshard`` now can be called on any instance


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Operating vshard-storage roles before vshard was bootstrapped

-------------------------------------------------------------------------------
[0.7.0] - 2019-04-05
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Failover priority configuration using WebUI
- Remote calls across cluster instances using ``cluster.rpc`` module
- Displaying ``box.cfg`` and ``box.info`` in WebUI
- Authorization for HTTP API and WebUI
- Configuration download/upload via WebUI
- Lua API documentation, which you can read with ``tarantoolctl rocks doc cluster`` command.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Instance restart now triggers config validation before roles initialization
- Update WebUI design
- Lua API changed (old functions still work, but issue warnings):
  - ``cluster.confapplier.*`` -> ``cluster.config_*``
  - ``cluster.service_registry.*`` -> ``cluster.service_*``

-------------------------------------------------------------------------------
[0.6.3] - 2019-02-08
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Cluster used to call 'validate()' role method instead of documented
  'validate_config()', so it was added. The undocumented 'validate()'
  still may be used for the sake of compatibility, but issues a warning
  that it was deprecated.

-------------------------------------------------------------------------------
[0.6.2] - 2019-02-07
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Minor internal corner cases

-------------------------------------------------------------------------------
[0.6.1] - 2019-02-05
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- UI/UX: Replace "bootstrap vshard" button with a noticable panel
- UI/UX: Replace failover panel with a small button

-------------------------------------------------------------------------------
[0.6.0] - 2019-01-30
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Ability to disable vshard-storage role when zero-weight rebalancing finishes
- Active master indication during failover
- Other minor improvements

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- New frontend core
- Dependencies update
- Call to ``join_server`` automatically does ``probe_server``

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Servers filtering by roles, uri, alias in WebUI

-------------------------------------------------------------------------------
[0.5.1] - 2018-12-12
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- WebUI errors

-------------------------------------------------------------------------------
[0.5.0] - 2018-12-11
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Graphql mutations order

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Callbacks in user-defined roles are called with ``is_master`` parameter,
  indicating state of the instance
- Combine ``cluster.init`` and ``cluster.register_role`` api calls in single ``cluster.cfg``
- Eliminate raising exceptions
- Absorb http server in ``cluster.cfg``

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Support of vshard replicaset weight parameter
- ``join_server()`` ``timeout`` parameter to make call synchronous

-------------------------------------------------------------------------------
[0.4.0] - 2018-11-27
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Fixed/Improved
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Uncaught exception in WebUI
- Indicate when backend is unavailable
- Sort servers in replicaset, put master first
- Cluster mutations are now synchronous, except joining new servers

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Lua API for temporarily disabling servers
- Lua API for implementing user-defined roles

-------------------------------------------------------------------------------
[0.3] - 2018-10-30
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Config structure **incompatible** with v0.2

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Explicit vshard master configuration
- Automatic failover (switchable)
- Unit tests

-------------------------------------------------------------------------------
[0.2] - 2018-10-01
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Changed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Allow vshard bootstrapping from ui
- Several stability improvements

-------------------------------------------------------------------------------
[0.1] - 2018-09-25
-------------------------------------------------------------------------------

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Added
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Basic functionality
- Integration tests
- Luarock-based packaging
- Gitlab CI integration
