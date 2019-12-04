#!/usr/bin/env tarantool

--- Clusterwide configuration propagation two-phase algorithm.
--
-- (**Added** in v1.2.0-19)
--
-- @module cartridge.twophase

local log = require('log')
local fio = require('fio')
local fun = require('fun')
local yaml = require('yaml').new()
local errno = require('errno')
local errors = require('errors')
local checks = require('checks')

local vars = require('cartridge.vars').new('cartridge.twophase')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')
local ClusterwideConfig = require('cartridge.clusterwide-config')

local AtomicCallError = errors.new_class('AtomicCallError')
local PatchClusterwideError = errors.new_class('PatchClusterwideError')
local Prepare2pcError = errors.new_class('Prepare2pcError')
local Commit2pcError = errors.new_class('Commit2pcError')
local GetSchemaError = errors.new_class('GetSchemaError')

yaml.cfg({
    encode_load_metatables = false,
    decode_save_metatables = false,
})

vars:new('locks', {})
vars:new('prepared_config', nil)

--- Two-phase commit - preparation stage.
--
-- Validate the configuration and acquire a lock setting local variable
-- and writing "config.prepare.yml" file. If the validation fails, the
-- lock isn't acquired and doesn't have to be aborted.
--
-- @function prepare_2pc
-- @local
-- @tparam table data clusterwide config content
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function prepare_2pc(data)
    local clusterwide_config = ClusterwideConfig.new(data):lock()

    local ok, err = confapplier.validate_config(clusterwide_config)
    if not ok then
        return nil, err
    end

    local workdir = confapplier.get_workdir()
    local path_prepare = fio.pathjoin(workdir, 'config.prepare.yml')

    if vars.prepared_config ~= nil then
        local err = Prepare2pcError:new('Two-phase commit is locked')
        return nil, err
    end

    local state = confapplier.get_state()
    local valid_states = {
        ['Unconfigured'] = true,
        ['RolesConfigured'] = true,
    }
    if not valid_states[state] then
        local err = Prepare2pcError:new(
            "Instance state is %s, can't apply config in this state",
            state
        )
        return nil, err
    end

    local ok, err = ClusterwideConfig.save(clusterwide_config, path_prepare)
    if not ok then
        return nil, err
    end

    vars.prepared_config = clusterwide_config
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
    Commit2pcError:assert(
        vars.prepared_config ~= nil,
        "commit isn't prepared"
    )

    local workdir = confapplier.get_workdir()
    local path_prepare = fio.pathjoin(workdir, 'config.prepare.yml')
    local path_backup = fio.pathjoin(workdir, 'config.backup.yml')
    local path_active = fio.pathjoin(workdir, 'config.yml')

    fio.unlink(path_backup)

    if fio.path.exists(path_active) then
        local ok = fio.link(path_active, path_backup)
        if ok then
            log.info('Backup of active config created: %q', path_backup)
        else
            log.warn(
                'Creation of config backup failed: %s', errno.strerror()
            )
        end
    end

    -- Release the lock
    local prepared_config = vars.prepared_config
    vars.prepared_config = nil

    local ok = fio.rename(path_prepare, path_active)
    if not ok then
        local err = Commit2pcError:new(
            "Can't move %q: %s", path_prepare, errno.strerror()
        )
        log.error('Error commmitting config update: %s', err)
        return nil, err
    end


    if type(box.cfg) == 'function' then
        return confapplier.boot_instance(prepared_config)
    else
        return confapplier.apply_config(prepared_config)
    end
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
    vars.prepared_config = nil
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
-- III. Executes the preparation phase (`prepare_2pc`) on every server
-- excluding expelled and disabled servers.
--
-- IV. If any server reports an error, executes the abort phase (`abort_2pc`).
-- All servers prepared so far are rolled back and unlocked.
--
-- V. Performs the commit phase (`commit_2pc`).
-- In case the phase fails, an automatic rollback is impossible, the
-- cluster should be repaired manually.
--
-- @function patch_clusterwide
-- @tparam table patch
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function _clusterwide(patch)
    checks('table')
    if patch.__type == 'ClusterwideConfig' then
        local err = "Bad argument #1 to patch_clusterwide" ..
            " (table expected, got ClusterwideConfig)"
        error(err, 2)
    end

    log.warn('Updating config clusterwide...')

    local clusterwide_config_old = confapplier.get_active_config()
    local vshard_utils = require('cartridge.vshard-utils')
    if clusterwide_config_old == nil then
        local auth = require('cartridge.auth')
        clusterwide_config_old = ClusterwideConfig.new({
            auth = auth.get_params(),
            vshard_groups = vshard_utils.get_known_groups(),
        }):lock()
    end

    local clusterwide_config_new = clusterwide_config_old:copy()
    for k, v in pairs(patch) do
        clusterwide_config_new:set_content(k, v)
    end
    clusterwide_config_new:lock()
    -- log.info('%s', yaml.encode(clusterwide_config_new:get_readonly()))

    local topology_old = clusterwide_config_old:get_readonly('topology')
    local topology_new = clusterwide_config_new:get_readonly('topology')

    topology.probe_missing_members(topology_new.servers)

    if utils.deepcmp(clusterwide_config_new, clusterwide_config_old) then
        log.warn("Clusterwide config didn't change, skipping")
        return true
    end

    local ok, err = topology.validate(topology_new, topology_old)
    if not ok then
        return nil, err
    end

    local ok, err = vshard_utils.validate_config(
        clusterwide_config_new:get_readonly(),
        clusterwide_config_old:get_readonly()
    )
    if not ok then
        return nil, err
    end

    local _2pc_error

    -- Prepare a server group to be configured
    local uri_list = {}
    local abortion_list = {}
    for _, _, srv in fun.filter(topology.not_disabled, topology_new.servers) do
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
            '_G.__cartridge_clusterwide_config_prepare_2pc', {clusterwide_config_new:get_readonly()},
            {uri_list = uri_list, timeout = 5}
        )

        for _, uri in ipairs(uri_list) do
            if retmap[uri] then
                log.warn('Prepared for config update at %s', uri)
                table.insert(abortion_list, uri)
            end
        end
        for _, uri in ipairs(uri_list) do
            if retmap[uri] == nil then
                local err = errmap and errmap[uri]
                if err == nil then
                    err = Prepare2pcError:new('Unknown error at %s', uri)
                end
                log.error('Error preparing for config update at %s: %s', uri, err)
                _2pc_error = err
            end
        end

        if _2pc_error ~= nil then
            goto abort
        else
            goto apply
        end
    end


::apply::
    do
        log.warn('(2PC) Commit stage...')

        local retmap, errmap = pool.map_call(
            '_G.__cartridge_clusterwide_config_commit_2pc', nil,
            {uri_list = uri_list, timeout = 5}
        )

        for _, uri in ipairs(uri_list) do
            if retmap[uri] then
                log.warn('Committed config at %s', uri)
            end
        end
        for _, uri in ipairs(uri_list) do
            if retmap[uri] == nil then
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
            '_G.__cartridge_clusterwide_config_abort_2pc', nil,
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
        return nil, AtomicCallError:new(
            'cartridge.patch_clusterwide is already running'
        )
    end

    vars.locks['clusterwide'] = true
    local ok, err = PatchClusterwideError:pcall(_clusterwide, patch)
    vars.locks['clusterwide'] = false

    if not ok then
        return nil, err
    end

    return true
end


--- Get clusterwide DDL schema.
--
-- (**Added** in v1.2.0-28)
-- @function get_schema
-- @treturn[1] string Schema in YAML format
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_schema()
    if confapplier.get_readonly() == nil then
        return nil, GetSchemaError:new(
            "Cluster isn't bootstaraped yet"
        )
    end
    local schema_yml = confapplier.get_readonly('schema.yml')

    if schema_yml == nil then
        return '---\nspaces: {}\n...\n'
    else
        return schema_yml
    end
end

--- Apply clusterwide DDL schema.
--
-- (**Added** in v1.2.0-28)
-- @function set_schema
-- @tparam string schema in YAML format
-- @treturn[1] string The same new schema
-- @treturn[2] nil
-- @treturn[2] table Error description
local function set_schema(schema_yml)
    checks('string')

    local patch = {['schema.yml'] = schema_yml}
    local ok, err = patch_clusterwide(patch)
    if not ok then
        return nil, err.err
    end

    return get_schema()
end

_G.__cartridge_clusterwide_config_prepare_2pc = function(...) return errors.pcall('E', prepare_2pc, ...) end
_G.__cartridge_clusterwide_config_commit_2pc = function(...) return errors.pcall('E', commit_2pc, ...) end
_G.__cartridge_clusterwide_config_abort_2pc = function(...) return errors.pcall('E', abort_2pc, ...) end

return {
    get_schema = get_schema,
    set_schema = set_schema,
    patch_clusterwide = patch_clusterwide,
}
