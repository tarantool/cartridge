--- Clusterwide configuration propagation two-phase algorithm.
--
-- (**Added** in v1.2.0-19)
--
-- @module cartridge.twophase

local log = require('log')
local fio = require('fio')
local fun = require('fun')
local fiber = require('fiber')
local yaml = require('yaml').new()
local errno = require('errno')
local errors = require('errors')
local checks = require('checks')

local vars = require('cartridge.vars').new('cartridge.twophase')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local upload = require('cartridge.upload')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')
local service_registry = require('cartridge.service-registry')
local ClusterwideConfig = require('cartridge.clusterwide-config')

local AtomicCallError = errors.new_class('AtomicCallError')
local PatchClusterwideError = errors.new_class('PatchClusterwideError')
local Prepare2pcError = errors.new_class('Prepare2pcError')
local Commit2pcError = errors.new_class('Commit2pcError')
local ForceReapplyError = errors.new_class('ForceReapplyError')
local GetSchemaError = errors.new_class('GetSchemaError')

yaml.cfg({
    encode_load_metatables = false,
    decode_save_metatables = false,
})

vars:new('locks', {})
vars:new('prepared_config', nil)
vars:new('prepared_config_release_notification', fiber.cond())
vars:new('on_patch_triggers', {})

vars:new('options', {
    netbox_call_timeout = 1,
    upload_config_timeout = 30,
    validate_config_timeout = 10,
    apply_config_timeout = 10,
})

local function get_ddl_manager()
    local ddl_manager
    local ok, _ = pcall(require, 'ddl-ee')
    if not ok then
        ddl_manager = service_registry.get('ddl-manager')
    else
        ddl_manager = service_registry.get('ddl-manager-ee')
    end
    return ddl_manager
end

local function release_config_lock()
    local prepared_config = vars.prepared_config
    vars.prepared_config = nil
    vars.prepared_config_release_notification:broadcast()
    return prepared_config
end

local function set_netbox_call_timeout(timeout)
    checks('number')
    vars.options.netbox_call_timeout = timeout
end

local function get_netbox_call_timeout()
    return vars.options.netbox_call_timeout
end

local function set_upload_config_timeout(timeout)
    checks('number')
    vars.options.upload_config_timeout = timeout
end

local function get_upload_config_timeout()
    return vars.options.upload_config_timeout
end

local function set_validate_config_timeout(timeout)
    checks('number')
    vars.options.validate_config_timeout = timeout
end

local function get_validate_config_timeout()
    return vars.options.validate_config_timeout
end

local function set_apply_config_timeout(timeout)
    checks('number')
    vars.options.apply_config_timeout = timeout
end

local function get_apply_config_timeout()
    return vars.options.apply_config_timeout
end

--- Wait until config won't released.
--
-- Two-phase commit starts with config preparation. It's just
-- config pin into "vars.prepared_config". After it using this value
-- we could determine is two-phase commit is started or not.
-- This function allows to wait when two-phase commit will be
-- finished (successfully or not).
--
-- @function wait_config_release
-- @local
-- @tparam number timeout
-- @treturn[1] boolean true in case of success and false otherwise
local function wait_config_release(timeout)
    if timeout == nil then
        timeout = vars.options.apply_config_timeout
    end

    local deadline = fiber.clock() + timeout
    while fiber.clock() < deadline do
        if vars.prepared_config == nil then
            -- Released
            break
        end
        local t = deadline - fiber.clock()
        if t < 0 then
            t = 0
        end
        vars.prepared_config_release_notification:wait(t)
    end
    return vars.prepared_config == nil
end

--- Two-phase commit - preparation stage.
--
-- Validate the configuration and acquire a lock setting local variable
-- and writing "config.prepare.yml" file. If the validation fails, the
-- lock isn't acquired and doesn't have to be aborted.
--
-- @function prepare_2pc
-- @local
-- @tparam string upload_id
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function prepare_2pc(upload_id)
    local data
    if type(upload_id) == 'table' then
        -- Preserve compatibility with older versions.
        -- Until cartridge 2.4.0-43 it was `prepare_2pc(data)`.
        data = upload_id
    else
        data = upload.inbox[upload_id]
        upload.inbox[upload_id] = nil
        if not data then
            return nil, Prepare2pcError:new(
                'Upload not found, see earlier logs for the details'
            )
        end
    end

    local state = confapplier.get_state()
    if state ~= 'Unconfigured'
    and state ~= 'RolesConfigured'
    and state ~= 'OperationError'
    then
        local err = Prepare2pcError:new(
            "Instance state is %s, can't apply config in this state",
            state
        )
        log.warn('%s', err)
        return nil, err
    end

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

    local ok, err = ClusterwideConfig.save(clusterwide_config, path_prepare)
    if not ok and fio.path.exists(path_prepare) then
        err = Prepare2pcError:new('Two-phase commit is locked')
    end

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

    local err
    local ok = fio.rename(path_prepare, path_active)
    if not ok then
        err = Commit2pcError:new(
            "Can't move %q: %s", path_prepare, errno.strerror()
        )
        log.error('%s', err)
    end

    -- Release the lock
    local prepared_config = release_config_lock()
    if err ~= nil then
        return nil, err
    end

    local state = confapplier.wish_state('RolesConfigured')

    if state == 'Unconfigured' then
        return confapplier.boot_instance(prepared_config)
    elseif state == 'RolesConfigured' or state == 'OperationError' then

        local current_config = confapplier.get_active_config()
        if state == 'RolesConfigured' and utils.deepcmp(
            prepared_config:get_plaintext(),
            current_config:get_plaintext()
        ) then
            log.warn("Clusterwide config didn`t change, skipping")
            return true
        end

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
    release_config_lock()
    return true
end

local function reapply(data)
    local clusterwide_config = ClusterwideConfig.new(data):lock()
    vars.prepared_config = clusterwide_config -- lock before wishing state

    local state = confapplier.wish_state('RolesConfigured')
    if state ~= 'Unconfigured'
    and state ~= 'RolesConfigured'
    and state ~= 'OperationError'
    then
        local err = ForceReapplyError:new(
            "Instance state is %s, can't reapply config in this state",
            state
        )
        log.warn('%s', err)
        return nil, err
    end

    local workdir = confapplier.get_workdir()
    local path_prepare = fio.pathjoin(workdir, 'config.prepare')
    local path_backup = fio.pathjoin(workdir, 'config.backup')
    local path_active = fio.pathjoin(workdir, 'config')
    ClusterwideConfig.remove(path_prepare)

    local ok, err = ClusterwideConfig.save(clusterwide_config, path_prepare)
    if not ok then
        log.warn('%s', err)
        return nil, err
    end

    ClusterwideConfig.remove(path_backup)

    if fio.path.exists(path_active) then
        local ok = fio.rename(path_active, path_backup)
        if ok then
            log.info('Backup of active config created: %q', path_backup)
        else
            log.warn('Creation of config backup failed: %s', errno.strerror())
        end
    end

    release_config_lock()

    local ok = fio.rename(path_prepare, path_active)
    if not ok then
        local err = ForceReapplyError:new(
            "Can't move %q: %s", path_prepare, errno.strerror()
        )
        log.error('%s', err)
        return nil, err
    end

    local state = confapplier.wish_state('RolesConfigured')

    if state == 'Unconfigured' then
        return confapplier.boot_instance(clusterwide_config)
    elseif state == 'RolesConfigured' or state == 'OperationError' then
        return confapplier.apply_config(clusterwide_config)
    else
        local err = ForceReapplyError:new(
            "Instance state is %s, can't reapply config in this state",
            state
        )
        log.error('%s', err)
        return nil, err
    end
end

--- Execute the two-phase commit algorithm.
--
-- * (*upload*) If `opts.upload_data` isn't `nil`, spread it across
-- the servers from `opts.uri_list`.
--
-- * (*prepare*) Run the `opts.fn_prepare` function.
--
-- * (*commit*) If all the servers do `return true`,
-- call `opts.fn_commit` on every server.
--
-- * (*abort*) Otherwise, if at least one server does `return nil, err`
-- or throws an exception, call `opts.fn_abort` on servers which were
-- prepared successfully.
--
-- @function twophase_commit
-- @tparam table opts
-- @tparam {string,...} opts.uri_list
--   array of URIs for performing twophase commit
-- @param opts.upload_data
--   any Lua object to be uploaded
-- @tparam ?string opts.activity_name
--   understandable name of activity used for logging
--   (default: "twophase_commit")
-- @tparam string opts.fn_prepare
-- @tparam string opts.fn_commit
-- @tparam string opts.fn_abort
--
-- @usage
--    local my_2pc_data = nil
--
--    function _G.my_2pc_prepare(upload_id)
--        local data = upload.inbox[upload_id]
--        upload.inbox[upload_id] = nil
--        if my_2pc_data ~= nil then
--            error('Two-phase commit is locked')
--        end
--        my_2pc_data = data
--    end
--
--    function _G.my_2pc_commit()
--        -- Apply my_2pc_data
--        ...
--    end
--
--    function _G.my_2pc_abort()
--        twophase_data = nil
--    end
--
-- @usage
--    require('cartridge.twophase').twophase_commit({
--        uri_list = {...},
--        upload_data = ...,
--        activity_name = 'my_2pc',
--        fn_prepare = '_G.my_2pc_prepare',
--        fn_commit = '_G.my_2pc_commit',
--        fn_abort = '_G.my_2pc_abort',
--    })
--
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function twophase_commit(opts)
    checks({
        uri_list = 'table',
        upload_data = '?',
        fn_prepare = 'string',
        fn_abort = 'string',
        fn_commit = 'string',
        activity_name = '?string'
    })

    local i = 0
    local uri_map = {}
    for _, _ in pairs(opts.uri_list) do
        i = i + 1
        local uri = opts.uri_list[i]
        if type(uri) ~= 'string' then
            error('bad argument opts.uri_list' ..
                ' to ' .. (debug.getinfo(1, 'nl').name or 'twophase_commit') ..
                ' (contiguous array of strings expected)', 2
            )
        end
        if uri_map[uri] then
            error('bad argument opts.uri_list' ..
                ' to ' .. (debug.getinfo(1, 'nl').name or 'twophase_commit') ..
                ' (duplicates are prohibited)', 2
            )
        end
        uri_map[uri] = true
    end

    local _2pc_error
    local abortion_list = {}
    local activity_name = opts.activity_name or 'twophase_commit'

    goto prepare

::prepare::
    do
        local upload_id, err
        if opts.upload_data then
            log.warn('(2PC) %s upload phase...', activity_name)

            upload_id, err = upload.upload(opts.upload_data, {
                uri_list = opts.uri_list,
                netbox_call_timeout = vars.options.netbox_call_timeout,
                transmission_timeout = vars.options.upload_config_timeout,
            })
            if not upload_id then
                _2pc_error = err
                goto finish
            end
        end

        log.warn('(2PC) %s prepare phase...', activity_name)

        local retmap, errmap = pool.map_call(opts.fn_prepare, {upload_id}, {
            uri_list = opts.uri_list,
            timeout = vars.options.validate_config_timeout,
        })

        for _, uri in ipairs(opts.uri_list) do
            if retmap[uri] then
                log.warn('Prepared for %s at %s', activity_name, uri)
                table.insert(abortion_list, uri)
            end
        end
        for _, uri in ipairs(opts.uri_list) do
            if retmap[uri] == nil then
                local err = errmap and errmap[uri]
                if err == nil then
                    err = Prepare2pcError:new('Unknown error at %s', uri)
                end
                log.error('Error preparing for %s at %s:\n%s', activity_name, uri, err)
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
        log.warn('(2PC) %s commit phase...', activity_name)

        local retmap, errmap = pool.map_call(opts.fn_commit, nil, {
            uri_list = opts.uri_list,
            timeout = vars.options.apply_config_timeout,
        })

        for _, uri in ipairs(opts.uri_list) do
            if retmap[uri] then
                log.warn('Committed %s at %s', activity_name, uri)
            end
        end
        for _, uri in ipairs(opts.uri_list) do
            if retmap[uri] == nil then
                local err = errmap and errmap[uri]
                log.error('Error committing %s at %s:\n%s', activity_name, uri, err)
                _2pc_error = err
            end
        end

        goto finish
    end

::abort::
    do
        log.warn('(2PC) %s abort phase...', activity_name)

        local retmap, errmap = pool.map_call(opts.fn_abort, nil,{
            uri_list = abortion_list,
            timeout = vars.options.netbox_call_timeout,
        })

        for _, uri in ipairs(abortion_list) do
            if retmap[uri] then
                log.warn('Aborted %s at %s', activity_name, uri)
            else
                local err = errmap and errmap[uri]
                log.error('Error aborting %s at %s:\n%s', activity_name, uri, err)
            end
        end

        goto finish
    end

::finish::
    if _2pc_error ~= nil then
        return nil, _2pc_error
    end
    return true
end

--- Edit the clusterwide configuration.
-- Top-level keys are merged with the current configuration.
-- To remove a top-level section, use
-- `patch_clusterwide{key = box.NULL}`.
--
-- The function executes following steps:
--
-- I. Patches the current configuration.
--
-- II. Validates topology on the current server.
--
-- III. Executes two-phase commit on all servers in the cluster
-- excluding expelled and disabled ones.
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

    local clusterwide_config_new, err = clusterwide_config_old:copy_and_patch(patch)
    if err then
        return nil, err
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

    local topology_old = clusterwide_config_old:get_readonly('topology')
    local topology_new = clusterwide_config_new:get_readonly('topology')
    if topology_new == nil then
        return nil, PatchClusterwideError:new(
            "Current instance isn't bootstrapped yet"
        )
    end

    topology.probe_missing_members(topology_new.servers)

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

    -- Prepare a server group to be configured
    local uri_list = {}
    local refined_uri_list = topology.refine_servers_uri(topology_new)
    for _, uuid, _ in fun.filter(topology.not_disabled, topology_new.servers) do
        table.insert(uri_list, refined_uri_list[uuid])
    end

    -- this is mostly for testing purposes
    -- it allows to determine apply order
    -- in real world it does not affect anything
    table.sort(uri_list)

    local _, err = twophase_commit({
        uri_list = uri_list,
        fn_prepare = '_G.__cartridge_clusterwide_config_prepare_2pc',
        fn_commit = '_G.__cartridge_clusterwide_config_commit_2pc',
        fn_abort = '_G.__cartridge_clusterwide_config_abort_2pc',
        upload_data = clusterwide_config_new:get_plaintext(),
        activity_name = 'patch_clusterwide'
    })

    if err == nil then
        log.warn('Clusterwide config updated successfully')
        return true
    else
        log.error('Clusterwide config update failed')
        return nil, err
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


--- Forcefully apply config to the given instances.
--
-- In particular:
--
-- - Abort two-phase commit (remove `config.prepare` lock)
-- - Upload the active config from the current instance.
-- - Apply it (reconfigure all roles)
--
-- (**Added** in v2.3.0-68)
--
-- @function force_reapply
-- @tparam {string,...} uuids
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function _force_reapply(uuids)
    checks('table')

    local clusterwide_config = confapplier.get_active_config()
    local current_topology = clusterwide_config:get_readonly('topology')

    local _reapply_error

    -- Prepare a server group to be configured
    local uri_list = {}
    local refined_uri_list = topology.refine_servers_uri(current_topology)
    for _, uuid in ipairs(uuids) do
        local srv = current_topology.servers[uuid]
        if not srv then
            return nil, ForceReapplyError:new(
                'Server %s not in clusterwide config', uuid
            )
        elseif not topology.not_disabled(uuid, srv) then
            return nil, ForceReapplyError:new(
                'Server %s is disabled, not suitable' ..
                ' for reapplying config', uuid
            )
        end

        table.insert(uri_list, refined_uri_list[uuid])
    end

    do
        log.warn('Reapplying clusterwide config forcefully...')

        local retmap, errmap = pool.map_call(
            '_G.__cartridge_clusterwide_config_reapply',
            {clusterwide_config:get_plaintext()},
            {
                uri_list = uri_list,
                timeout = vars.options.apply_config_timeout,
            }
        )

        for _, uri in ipairs(uri_list) do
            if retmap[uri] then
                log.warn('Reapplied config forcefully at %s', uri)
            end
        end
        for _, uri in ipairs(uri_list) do
            if retmap[uri] == nil then
                local err = errmap and errmap[uri]
                if err == nil then
                    err = ForceReapplyError:new('Unknown error at %s', uri)
                end
                log.error('Error reapplying config at %s:\n%s', uri, err)
                _reapply_error = err
            end
        end

    end

    if _reapply_error == nil then
        log.warn('Clusterwide config reapplied successfully')
        return true
    else
        log.error('Clusterwide config reapply failed')
        return nil, _reapply_error
    end
end

local function force_reapply(uuids)
    if vars.locks['clusterwide'] == true  then
        return nil, AtomicCallError:new(
            'cartridge.patch_clusterwide is already running'
        )
    end

    vars.locks['clusterwide'] = true
    local ok, err = PatchClusterwideError:pcall(_force_reapply, uuids)
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
            "Current instance isn't bootstrapped yet"
        )
    end

    local ddl_manager = assert(get_ddl_manager())
    return ddl_manager.get_clusterwide_schema_yaml()
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
    if confapplier.get_readonly() == nil then
        return nil, GetSchemaError:new(
            "Current instance isn't bootstrapped yet"
        )
    end

    local ddl_manager = assert(get_ddl_manager())
    local ok, err = ddl_manager.set_clusterwide_schema_yaml(schema_yml)
    if ok == nil then
        return nil, err
    end

    return ddl_manager.get_clusterwide_schema_yaml()
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
_G.__cartridge_clusterwide_config_reapply = function(...) return errors.pcall('E', reapply, ...) end


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
    force_reapply = force_reapply,
    twophase_commit = twophase_commit,
    set_netbox_call_timeout = set_netbox_call_timeout,
    get_netbox_call_timeout = get_netbox_call_timeout,
    set_upload_config_timeout = set_upload_config_timeout,
    get_upload_config_timeout = get_upload_config_timeout,
    set_validate_config_timeout = set_validate_config_timeout,
    get_validate_config_timeout = get_validate_config_timeout,
    set_apply_config_timeout = set_apply_config_timeout,
    get_apply_config_timeout = get_apply_config_timeout,
    wait_config_release = wait_config_release,
    -- Cartridge supports backward compatibility but not the forward
    -- one. Thus operations that modify clusterwide config should be
    -- performed by instances with the lowest twophase version. This
    -- principal is used in the rolling update scenario via
    -- ansible-cartridge.
    VERSION = 2,
}
