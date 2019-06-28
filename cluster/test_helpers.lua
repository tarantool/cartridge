--- Helpers for integration testing.
-- This module extends `luatest.helpers` with cluster-specific classes and helpers.
--
-- @module cluster.test_helpers
-- @alias helpers

local luatest = require('luatest')

local helpers = table.copy(luatest.helpers)

--- Extended luatest.server class to run tarantool instance.
-- @see cluster.test_helpers.server
helpers.Server = require('cluster.test_helpers.server')
--- Class to run and manage multiple tarantool instances.
-- @see cluster.test_helpers.cluster
helpers.Cluster = require('cluster.test_helpers.cluster')

return helpers
