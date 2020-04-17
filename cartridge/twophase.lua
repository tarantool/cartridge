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
vars:new('on_patch_triggers', {})

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
        log.warn('%s', err)
        return nil, err
    end

    local workdir = confapplier.get_workdir()
    local path_prepare = fio.pathjoin(workdir, 'config.prepare')

    if vars.prepared_config ~= nil then
        local err = Prepare2pcError:new('Two-phase commit is locked')
        log.warn('%s', err)
        return nil, err
    end

    local state = confapplier.wish_state('RolesConfigured')
    if state ~= 'Unconfigured' and state ~= 'RolesConfigured' then
        local err = Prepare2pcError:new(
            "Instance state is %s, can't apply config in this state",
            state
        )
        log.warn('%s', err)
        return nil, err
    end

    local ok, err = ClusterwideConfig.save(clusterwide_config, path_prepare)
    if not ok then
        log.warn('%s', err)
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
    local path_prepare = fio.pathjoin(workdir, 'config.prepare')
    local path_backup = fio.pathjoin(workdir, 'config.backup')
    local path_active = fio.pathjoin(workdir, 'config')

    ClusterwideConfig.remove(path_backup)

    if fio.path.exists(path_active) then
        local ok = fio.rename(path_active, path_backup)
        if ok then
            log.info('Backup of active config created: %q', path_backup)
        else
            log.warn('Creation of config backup failed: %s', errno.strerror())
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
        log.error('%s', err)
        return nil, err
    end


    local state = confapplier.wish_state('RolesConfigured')

    if state == 'Unconfigured' then
        return confapplier.boot_instance(prepared_config)
    elseif state == 'RolesConfigured' then
        return confapplier.apply_config(prepared_config)
    else
        local err = Commit2pcError:new(
            "Instance state is %s, can't apply config in this state",
            state
        )
        log.error('%s', err)
        return nil, err
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
    local path_prepare = fio.pathjoin(workdir, 'config.prepare')
    ClusterwideConfig.remove(path_prepare)
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
        local err = "bad argument #1 to patch_clusterwide" ..
            " (table expected, got ClusterwideConfig)"
        error(err, 2)
    end

    log.warn('Updating config clusterwide...')

    local clusterwide_config_old = confapplier.get_active_config()
    local vshard_utils = require('cartridge.vshard-utils')

    if clusterwide_config_old == nil then
        local auth = require('cartridge.auth')
        clusterwide_config_old = ClusterwideConfig.new({
            ['auth.yml'] = yaml.encode(auth.get_params()),
            ['vshard_groups.yml'] = yaml.encode(vshard_utils.get_known_groups()),
        }):lock()
    end

    local clusterwide_config_new = clusterwide_config_old:copy()
    for k, v in pairs(patch) do
        if patch[k] ~= nil and patch[k .. '.yml'] ~= nil then
            local err = PatchClusterwideError:new(
                'Ambiguous sections %q and %q',
                k, k .. '.yml'
            )
            log.error('%s', err)
            return nil, err
        end
        if v == nil then
            clusterwide_config_new:set_plaintext(k, v)
            clusterwide_config_new:set_plaintext(k .. '.yml', patch[k .. '.yml'])
        elseif type(v) == 'string' then
            clusterwide_config_new:set_plaintext(k, v)
        else
            if not string.endswith(k, '.yml') then
                clusterwide_config_new:set_plaintext(k, box.NULL)
                k = k .. '.yml'
            end

            clusterwide_config_new:set_plaintext(k, yaml.encode(v))
        end
    end

    for trigger, _ in pairs(vars.on_patch_triggers) do
        trigger(clusterwide_config_new, clusterwide_config_old)
    end

    local _, err = clusterwide_config_new:update_luatables()
    if err ~= nil then
        log.error('%s', err)
        return nil, err
    end
    clusterwide_config_new:lock()
    -- log.info('%s', yaml.encode(clusterwide_config_new:get_readonly()))

    local topology_old = clusterwide_config_old:get_readonly('topology')
    local topology_new = clusterwide_config_new:get_readonly('topology')
    if topology_new == nil then
        return nil, PatchClusterwideError:new(
            "Topology not specified, seems that cluster isn't bootstrapped"
        )
    end

    topology.probe_missing_members(topology_new.servers)

    if utils.deepcmp(
        clusterwide_config_new:get_plaintext(),
        clusterwide_config_old:get_plaintext()
    ) then
        log.warn("Clusterwide config didn't change, skipping")
        return true
    end

    local ok, err = topology.validate(topology_new, topology_old)
    if not ok then
        log.error('%s', err)
        return nil, err
    end

    local ok, err = vshard_utils.validate_config(
        clusterwide_config_new:get_readonly(),
        clusterwide_config_old:get_readonly()
    )
    if not ok then
        log.error('%s', err)
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
            '_G.__cartridge_clusterwide_config_prepare_2pc', {clusterwide_config_new:get_plaintext()},
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
                log.error('Error preparing for config update at %s:\n%s', uri, err)
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
                log.error('Error committing config at %s:\n%s', uri, err)
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
                log.error('Error aborting config update at %s:\n%s', uri, err)
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
            "Cluster isn't bootstrapped yet"
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

--- Set up trigger for for patch_clusterwide.
--
-- It will be executed **before** new new config applied.
--
-- If the parameters are `(nil, old_trigger)`, then the old trigger is
-- deleted.
--
-- The trigger function is called with two argument:
-- - `conf_new` (`ClusterwideConfig`)
-- - `conf_old` (`ClusterWideConfig`)
--
-- It is allowed to modify `conf_new`, but not `conf_old`.
-- Return values are ignored. If calling a trigger raises an error,
-- `patch_clusterwide` returns it as `nil, err`.
--
-- (**Added** in v2.1.0-4)
--
-- @usage
--    local function inject_data(conf_new, _)
--        local data_yml = yaml.encode({foo = 'bar'})
--        conf_new:set_plaintext('data.yml', data_yml)
--    end)
--
--    twophase.on_patch(inject_data) -- set custom patch modifier trigger
--    twophase.on_patch(nil, inject_data) -- drop trigger
--
-- @function on_patch
-- @tparam function trigger_new
-- @tparam function trigger_old
local function on_patch(trigger_new, trigger_old)
    checks('?function', '?function')
    if trigger_old ~= nil then
        vars.on_patch_triggers[trigger_old] = nil
    end
    if trigger_new ~= nil then
        vars.on_patch_triggers[trigger_new] = true
    end
    return trigger_new
end

_G.__cartridge_clusterwide_config_prepare_2pc = function(...) return errors.pcall('E', prepare_2pc, ...) end
_G.__cartridge_clusterwide_config_commit_2pc = function(...) return errors.pcall('E', commit_2pc, ...) end
_G.__cartridge_clusterwide_config_abort_2pc = function(...) return errors.pcall('E', abort_2pc, ...) end

-- Keep backward compatibility with the good old cartridge 1.2.0.
_G.__cluster_confapplier_prepare_2pc = function(conf)
    local tempdir = fio.tempdir()
    local path = fio.pathjoin(tempdir, 'config.yml')
    local ok, err = utils.file_write(path, yaml.encode(conf))
    if not ok then
        return nil, err
    end

    local clusterwide_config = ClusterwideConfig.load(path)
    fio.rmtree(tempdir)

    return errors.pcall('E', prepare_2pc, clusterwide_config:get_plaintext())
end
_G.__cluster_confapplier_commit_2pc = function(...) return errors.pcall('E', commit_2pc, ...) end
_G.__cluster_confapplier_abort_2pc = function(...) return errors.pcall('E', abort_2pc, ...) end

return {
    on_patch = on_patch,
    get_schema = get_schema,
    set_schema = set_schema,
    patch_clusterwide = patch_clusterwide,
}
