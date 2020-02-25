--- User-defined role API.
-- If you want to implement your own role it must conform this API.
--
-- @module custom-role

--- Displayed role name.
-- When absent, module name is used instead.
-- @tfield string role_name

--- Hidden role flag. aren't listed in
-- `cartridge.admin_get_replicasets().roles` and therefore in WebUI.
-- Hidden roled are supposed to be a dependency for another role.
-- @tfield boolean hidden

--- Permanent role flag.
-- Permanent roles will be enabled on every instance in cluster.
-- Implies `hidden = true`.
-- @tfield boolean permanent


--- Role initialization callback.
-- Called when role is enabled on an instance.
-- Caused either by editing topology or instance restart.
--
-- @function init
-- @tparam table opts
-- @tparam boolean opts.is_master

--- Role shutdown callback.
-- Called when role is disabled on an instance.
-- @function stop
-- @tparam table opts
-- @tparam boolean opts.is_master


--- Validate clusterwide configuration callback.
--
-- @function validate_config
-- @tparam table conf_new
-- @tparam table conf_old

--- Apply clusterwide configuration callback.
-- @function apply_config
-- @tparam table conf Clusterwide configuration
-- @tparam table opts
-- @tparam boolean opts.is_master
