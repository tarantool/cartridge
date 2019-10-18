#!/usr/bin/env tarantool

--- Clusterwide configuration propagation algorithm.
-- @module cartridge.clusterwide

local log = require('log')
local fio = require('fio')
local fun = require('fun')
local yaml = require('yaml').new()
local errno = require('errno')
local errors = require('errors')
local checks = require('checks')

local vars = require('cartridge.vars').new('cartridge.clusterwide')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')

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
    local ok, err = confapplier.validate_config(conf)
    if not ok then
        return nil, err
    end

    local path = 'config.prepare.yml'
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
-- Back up the active configuration, commit changes to filesystem, release the lock, and configure roles.
-- If any errors occur, configuration is not rolled back automatically.
-- Any problem encountered during this call has to be solved manually.
--
-- @function commit_2pc
-- @local
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function commit_2pc()
    local path_prepare = 'config.prepare.yml'
    local path_backup = 'config.backup.yml'
    local path_active = 'config.yml'

    fio.unlink(path_backup)

    if fio.path.exists(path_active) then
        local ok = fio.link(path_active, path_backup)
        if ok then
            log.info('Backup of active config created: %q', path_backup)
        end
    else
        fio.link(path_prepare, path_active)
    end

    local ok = fio.rename(path_prepare, path_active)
    if not ok then
        local err = errors.new('Commit2pcError',
            'Can not move %q: %s', path_prepare, errno.strerror()
        )
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
    fio.unlink('config.prepare.yml')
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

    local conf_old = confapplier.get_readonly()
    local conf_new = confapplier.get_deepcopy()
    for k, v in pairs(patch) do
        if v == box.NULL then
            conf_new[k] = nil
        else
            conf_new[k] = v
        end
    end

    topology.probe_missing_members(conf_new.topology.servers)

    if utils.deepcmp(conf_new, conf_old) then
        log.warn("Clusterwide config didn't change, skipping")
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

    local _2pc_error
    local servers_new = conf_new.topology.servers

    -- Prepare a server group to be configured
    local uri_list = {}
    local abortion_list = {}
    for _, _, srv in fun.filter(topology.not_disabled, servers_new) do
        table.insert(uri_list, srv.uri)
    end

    -- this is mostly for testing purposes
    -- it allows to determine apply order
    -- in real world it does not affect anything
    table.sort(uri_list)

    goto prepare

::prepare::
    do
        log.warn('(2PC) Preparation stage...')

        local retmap, errmap = pool.map_call(
            '_G.__cartridge_cwcfg_prepare_2pc', {conf_new},
            {uri_list = uri_list, timeout = 5}
        )

        for _, uri in ipairs(uri_list) do
            if retmap[uri] then
                log.warn('Prepared for config update at %s', uri)
                table.insert(abortion_list, uri)
            else
                local err = errmap and errmap[uri]
                log.error('Error preparing for config update at %s: %s', uri, err)
                _2pc_error = err
            end
        end

        if errmap ~= nil then
            goto abort
        else
            goto apply
        end
    end


::apply::
    do
        log.warn('(2PC) Commit stage...')

        local retmap, errmap = pool.map_call(
            '_G.__cartridge_cwcfg_commit_2pc', nil,
            {uri_list = uri_list, timeout = 5}
        )

        for _, uri in ipairs(uri_list) do
            if retmap[uri] then
                log.warn('Committed config at %s', uri)
            else
                local err = errmap and errmap[uri]
                log.error('Error committing config at %s: %s', uri, err)
                _2pc_error = err
            end
        end

        goto finish
    end

::abort::
    do
        log.warn('(2PC) Abort stage...')

        local retmap, errmap = pool.map_call(
            '_G.__cartridge_cwcfg_abort_2pc', nil,
            {uri_list = abortion_list, timeout = 5}
        )

        for _, uri in ipairs(abortion_list) do
            if retmap[uri] then
                log.warn('Aborted config update at %s', uri)
            else
                local err = errmap and errmap[uri]
                log.error('Error aborting config update at %s: %s', uri, err)
            end
        end

        goto finish
    end

::finish::
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
        return nil, errors.new('AtomicCallError',
            'cartrige.patch_clusterwide is already running'
        )
    end

    vars.locks['clusterwide'] = true
    local ok, err = errors.pcall('PatchClusterwideError',
        _clusterwide, patch
    )
    vars.locks['clusterwide'] = false

    return ok, err
end

_G.__cartridge_prepare_2pc = prepare_2pc
_G.__cartridge_commit_2pc = commit_2pc
_G.__cartridge_abort_2pc = abort_2pc

return {
    patch_clusterwide = patch_clusterwide,
}
