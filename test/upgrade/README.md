### Notes about upgrade tests

This part of tests check that we could perform an upgrade
from a smaller tarantool schema version to more higher.

This readme demonstrates how this works.
First of all, we should prepare the data with an
initial schema version.

As example let's see on `test_master_replica`.
The main idea of the tests. At first bootstrap an
instance using Tarantool 1.10 and then upgrade it to
2.2+.

Our algorithm:
  * Bootstrap an instance using Tarantool 1.10
  * Upgrade Tarantool version to 2.2+
  * Start a cluster with upgrade procedure
  * Preform some checks.


We have a test script that could be used as an
a snippet for bootstrap.

Let's apply the following diff and run test:
```diff
--- a/test/upgrade/test_master_replica/upgrade_master_replica_1_10_test.lua
+++ b/test/upgrade/test_master_replica/upgrade_master_replica_1_10_test.lua
@@ -6,10 +6,7 @@ local helpers = require('test.helper')

 g.before_all = function()
     local cwd = fio.cwd()
-    local test_data_dir  = fio.pathjoin(cwd, 'test/upgrade/test_master_replica/data')
-    local datadir = fio.tempdir()
-    local ok, err = fio.copytree(test_data_dir, datadir)
-    assert(ok, err)
+    local datadir  = fio.pathjoin(cwd, 'test/upgrade/test_master_replica/data')

     local cookie = 'upgrade-1.10-2.2'

@@ -58,13 +55,12 @@ g.before_all = function()
     })
     -- We start cluster from existing 1.10 snapshots
     -- with schema version {'1', '10', '2'}
-    g.cluster.bootstrapped = true
+    --g.cluster.bootstrapped = true
     g.cluster:start()
 end

 g.after_all = function()
     g.cluster:stop()
-    fio.rmtree(g.cluster.datadir)
 end

 function g.test_upgrade()
```

A result will be written in `'test/upgrade/test_master_replica/data'`.
Then we could uncomment `g.cluster.bootstrapped = true` back and run
a test again to be closer to real situation.
After wals/snaps/configs are ready to be tested.
