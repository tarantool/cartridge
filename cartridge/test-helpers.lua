--- Helpers for integration testing.
-- This module extends `luatest.helpers` with cartridge-specific classes and helpers.
--
-- @module cartridge.test-helpers
-- @alias helpers

local luatest = require('luatest')

local helpers = table.copy(luatest.helpers)

--- Extended luatest.server class to run tarantool instance.
-- @see cartridge.test-helpers.server
helpers.Server = require('cartridge.test-helpers.server')
--- Class to run and manage multiple tarantool instances.
-- @see cartridge.test-helpers.cluster
helpers.Cluster = require('cartridge.test-helpers.cluster')

return helpers
