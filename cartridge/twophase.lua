#!/usr/bin/env tarantool

--- Clusterwide configuration propagation two-phase algorithm.
--
-- (**Added** in v1.2.0-19)
--
-- @module cartridge.twophase

local log = require('log')
local fio = require('fio')
local yaml = require('yaml').new()
local errno = require('errno')
local errors = require('errors')
local checks = require('checks')

local vars = require('cartridge.vars').new('cartridge.twophase')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')

local e_atomic = errors.new_class('Atomic call failed')
local e_config_apply = errors.new_class('Applying configuration failed')

yaml.cfg({
    encode_load_metatables = false,
    decode_save_metatables = false,
})

vars:new('locks', {})

--- Two-phase commit - preparation stage.
--
-- Validate the configuration and acquire a lock writing `<workdir>/config.prepate.yml`.
-- If the validation fails, the lock is not acquired and does not have to be aborted.
-- @function prepare_2pc
-- @local
-- @tparam table conf
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function prepare_2pc(conf)
    local ok, err = confapplier.validate_config(conf, confapplier.get_readonly() or {})
    if not ok then
        return nil, err
    end

    local workdir = confapplier.get_workdir()
    local path = fio.pathjoin(workdir, 'config.prepare.yml')
    local ok, err = utils.file_write(
        path, yaml.encode(conf),
        {'O_CREAT', 'O_EXCL', 'O_WRONLY'}
    )
    if not ok then
        return nil, err
    end

    return true
end

--- Two-phase commit - commit stage.
--
-- Back up the active configuration, commit changes to filesystem by
-- renaming prepared file, release the lock, and configure roles.
-- If any errors occur, configuration is not rolled back automatically.
-- Any problem encountered during this call has to be solved manually.
--
-- @function commit_2pc
-- @local
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function commit_2pc()
    local workdir = confapplier.get_workdir()
    local path_prepare = fio.pathjoin(workdir, 'config.prepare.yml')
    local path_backup = fio.pathjoin(workdir, 'config.backup.yml')
    local path_active = fio.pathjoin(workdir, 'config.yml')

    fio.unlink(path_backup)
    local ok = fio.link(path_active, path_backup)
    if ok then
        log.info('Backup of active config created: %q', path_backup)
    end

    local ok = fio.rename(path_prepare, path_active)
    if not ok then
        local err = e_config_apply:new('Can not move %q: %s', path_prepare, errno.strerror())
        log.error('Error commmitting config update: %s', err)
        return nil, err
    end

    local conf, err = confapplier.load_from_file()
    if not conf then
        log.error('Error commmitting config update: %s', err)
        return nil, err
    end

    return confapplier.apply_config(conf)
end

--- Two-phase commit - abort stage.
--
-- Release the lock for further commit attempts.
-- @function abort_2pc
-- @local
-- @treturn boolean true
local function abort_2pc()
    local workdir = confapplier.get_workdir()
    local path_prepare = fio.pathjoin(workdir, 'config.prepare.yml')
    fio.unlink(path_prepare)
    return true
end

--- Edit the clusterwide configuration.
-- Top-level keys are merged with the current configuration.
-- To remove a top-level section, use
-- `patch_clusterwide{key = box.NULL}`.
--
-- The function uses a two-phase commit algorithm with the following steps:
--
-- I. Patches the current configuration.
--
-- II. Validates topology on the current server.
--
-- III. Executes the preparation phase (`prepare_2pc`) on every server excluding
-- the following servers: expelled, disabled, and
-- servers being joined during this call.
--
-- IV. If any server reports an error, executes the abort phase (`abort_2pc`).
-- All servers prepared so far are rolled back and unlocked.
--
-- V. Performs the commit phase (`commit_2pc`).
-- In case the phase fails, an automatic rollback is impossible, the
-- cluster should be repaired manually.
--
-- @function patch_clusterwide
-- @tparam table patch A patch to be applied.
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function _clusterwide(patch)
    checks('table')

    log.warn('Updating config clusterwide...')

    local conf_new = confapplier.get_deepcopy()
    local conf_old = confapplier.get_readonly()
    for k, v in pairs(patch) do
        if v == box.NULL then
            conf_new[k] = nil
        else
            conf_new[k] = v
        end
    end

    topology.probe_missing_members(conf_new.topology.servers)

    if utils.deepcmp(conf_new, conf_old) then
        return true
    end

    local ok, err = topology.validate(conf_new.topology, conf_old.topology)
    if not ok then
        return nil, err
    end

    local vshard_utils = require('cartridge.vshard-utils')
    local ok, err = vshard_utils.validate_config(conf_new, conf_old)
    if not ok then
        return nil, err
    end

    local servers_new = conf_new.topology.servers
    local servers_old = conf_old.topology.servers

    -- Prepare a server group to be configured
    local configured_uri_list = {}
    local cnt = 0
    for uuid, _ in pairs(servers_new) do
        -- luacheck: ignore 542
        if not topology.not_disabled(uuid, servers_new[uuid]) then
            -- ignore disabled servers
        elseif servers_old[uuid] == nil then
            -- new servers bootstrap themselves through membership
            -- dont call nex.box on them
        else
            local uri = servers_new[uuid].uri
            cnt = cnt + 1
            configured_uri_list[cnt] = uri
            configured_uri_list[uri] = false
        end
    end

    -- this is mostly for testing purposes
    -- it allows to determine apply order
    -- in real world it does not affect anything
    table.sort(configured_uri_list)

    -- 2PC prepare
    local _2pc_error = nil
    for _, uri in ipairs(configured_uri_list) do
        local conn, err = pool.connect(uri)
        if conn == nil then
            log.error('Error preparing for config update at %s', uri)
            _2pc_error = err
            break
        else
            local ok, err = errors.netbox_call(
                conn,
                '_G.__cluster_confapplier_prepare_2pc',
                {conf_new}, {timeout = 5}
            )
            if ok == true then
                log.warn('Prepared for config update at %s', uri)
                configured_uri_list[uri] = true
            else
                log.error('Error preparing for config update at %s: %s', uri, err)
                _2pc_error = err
                break
            end
        end
    end

    if _2pc_error == nil then
        -- 2PC commit
        for _, uri in ipairs(configured_uri_list) do
            local conn, err = pool.connect(uri)
            if conn == nil then
                log.error('Error commmitting config update at %s: %s', uri, err)
                _2pc_error = err
            else
                local ok, err = errors.netbox_call(
                    conn,
                    '_G.__cluster_confapplier_commit_2pc'
                )
                if ok == true then
                    log.warn('Committed config update at %s', uri)
                else
                    log.error('Error commmitting config update at %s: %s', uri, err)
                    _2pc_error = err
                end
            end
        end
    else
        -- 2PC abort
        for _, uri in ipairs(configured_uri_list) do
            if not configured_uri_list[uri] then
                break
            end

            local conn, err = pool.connect(uri)
            if conn == nil then
                log.error('Error aborting config update at %s: %s', uri, err)
            else
                local ok, err = errors.netbox_call(
                    conn,
                    '_G.__cluster_confapplier_abort_2pc'
                )
                if ok == true then
                    log.warn('Aborted config update at %s', uri)
                else
                    log.error('Error aborting config update at %s: %s', uri, err)
                end
            end
        end
    end

    if _2pc_error == nil then
        log.warn('Clusterwide config updated successfully')
        return true
    else
        log.error('Clusterwide config update failed')
        return nil, _2pc_error
    end
end

local function patch_clusterwide(patch)
    if vars.locks['clusterwide'] == true  then
        return nil, e_atomic:new(
            'cartridge.patch_clusterwide is already running'
        )
    end

    box.session.su('admin')
    vars.locks['clusterwide'] = true
    local ok, err = e_config_apply:pcall(_clusterwide, patch)
    vars.locks['clusterwide'] = false

    return ok, err
end

_G.__cluster_confapplier_prepare_2pc = prepare_2pc
_G.__cluster_confapplier_commit_2pc = commit_2pc
_G.__cluster_confapplier_abort_2pc = abort_2pc

return {
    prepare_2pc = prepare_2pc,
    commit_2pc = commit_2pc,
    abort_2pc = abort_2pc,

    patch_clusterwide = patch_clusterwide,
}
