--- Gather configuration options.
--
-- The module reads configuration options from multiple sources
-- and then merges the options together according to source priority:
--
-- 1. `--<VARNAME>` command line arguments.
-- 2. `TARANTOOL_<VARNAME>` environment variables.
-- 3. Configuration files.
--
-- To specify a configuration file, use the `--cfg <CONFIG_FILE>` option
-- or the `TARANTOOL_CFG=<CONFIG_FILE>` environment variable.
--
-- Configuration files are `.yaml` files, divided into
-- sections like the following:
--
--     default:
--       memtx_memory: 10000000
--       some_option: "default value"
--     myapp.router:
--       memtx_memory: 1024000000
--       some_option: "router-specific value"
--
--  Within the configuration file, `argparse` looks for multiple matching sections:
--
-- 1. The section named `<APP_NAME>.<INSTANCE_NAME>` is parsed first.
--   The application name is derived automatically from the rockspec filename in the
--   project directory. Alternatively, you can specify it manually via the `--app-name`
--   command line argument or the `TARANTOOL_APP_NAME` environment variable.
--   The instance name can be specified the same way, either as `--instance-name`
--   or `TARANTOOL_INSTANCE_NAME`.
-- 2. The common `<APP_NAME>` section is parsed next.
-- 3. Finally, the section `[default]` with the global configuration is parsed
--   with the lowest priority.
--
-- An instance name may consist of multiple period-separated parts,
-- for example, `--app-name "myapp" --instance-name "router.1"`.
-- In this case, sections with names that include these parts are also parsed:
-- first `[myapp.router.1]`, then `[myapp.router]`, then `[myapp]`.
--
-- Instead of a single configuration file, you can use a directory.
-- In this case, all files in the directory are parsed.
-- To avoid conflicts, the same section mustn't repeat across different files.
--
-- Argparse logs if there were some ignored sections in configuration files.
-- All sections should be key-value pairs as in example, otherwise you'll get an error.
--
-- @module cartridge.argparse

local fio = require('fio')
local yaml = require('yaml')
local json = require('json')
local checks = require('checks')
local errors = require('errors')
local log = require('log')
-- local base_dir = fio.abspath(fio.dirname(arg[0]))

local vars = require('cartridge.vars').new('cartridge.argparse')
local utils = require('cartridge.utils')
vars:new('args', nil)

local ParseConfigError = errors.new_class('ParseConfigError')
local DecodeYamlError = errors.new_class('DecodeYamlError')
local TypeCastError = errors.new_class('TypeCastError')

local function toboolean(val)
    if type(val) == 'boolean' then
        return val
    elseif type(val) ~= 'string' then
        return nil
    end

    val = val:lower()

    if val == 'true' then
        return true
    elseif val == 'false' then
        return false
    end
end

--- Common `cartridge.cfg` options.
--
-- Any options not listed below (like the `roles` option)
-- can't be modified with `argparse` and should be configured in code.
--
-- @table cluster_opts
local cluster_opts = {
    alias = 'string', -- **string**
    workdir = 'string', -- **string**
    http_port = 'number', -- **number**
    http_host = 'string', -- **string**
    http_enabled = 'boolean', -- **boolean**
    webui_enabled = 'boolean', -- **boolean**
    webui_prefix = 'string', -- **string**
    webui_enforce_root_redirect = 'boolean', -- **boolean**
    advertise_uri = 'string', -- **string**
    cluster_cookie = 'string', -- **string**
    console_sock = 'string', -- **string**
    auth_enabled = 'boolean', -- **boolean**
    bucket_count = 'number', -- **number**
    rebalancer_mode = 'string', -- **string**
    upgrade_schema = 'boolean', -- **boolean**
    swim_broadcast = 'boolean', -- **boolean**
    upload_prefix = 'string', -- **string**
    transport = 'string', -- **string**
    ssl_ciphers = 'string', -- **string**
    ssl_server_ca_file = 'string', -- **string**
    ssl_server_cert_file = 'string', -- **string**
    ssl_server_key_file = 'string', -- **string**
    ssl_server_password = 'string', -- **string**
    ssl_client_ca_file = 'string', -- **string**
    ssl_client_cert_file = 'string', -- **string**
    ssl_client_key_file = 'string', -- **string**
    ssl_client_password = 'string', -- **string**
    disable_errstack = 'boolean', -- **boolean**
    enable_synchro_mode = 'boolean', -- **boolean**
    disable_raft_on_small_clusters = 'boolean', -- **boolean**
    enable_failover_suppressing = 'boolean', -- **boolean**
    set_cookie_hash_membership = 'boolean', -- **boolean**

    twophase_netbox_call_timeout = 'number', -- **number**
    twophase_upload_config_timeout = 'number', -- **number**
    twophase_validate_config_timeout = 'number', -- **number**
    twophase_apply_config_timeout = 'number', -- **number**
}

--- Common `box.cfg <https://www.tarantool.io/en/doc/latest/reference/configuration/>`_ tuning options.
-- @table box_opts
local box_opts = {
    listen                   = 'string|number', -- **string|number**
    memtx_memory             = 'number', -- **number**
    memtx_allocator          = 'string', -- **string**
    strip_core               = 'boolean', -- **boolean**
    memtx_min_tuple_size     = 'number', -- **number**
    memtx_max_tuple_size     = 'number', -- **number**
    memtx_use_mvcc_engine    = 'boolean', -- **boolean**
    txn_isolation            = 'string|number', -- **string|number**
    slab_alloc_factor        = 'number', -- **number**
    slab_alloc_granularity   = 'number', -- **number**
    work_dir                 = 'string', -- **string** (**deprecated**)
    memtx_dir                = 'string', -- **string**
    wal_dir                  = 'string', -- **string**
    vinyl_dir                = 'string', -- **string**

    vinyl_memory             = 'number', -- **number**
    vinyl_cache              = 'number', -- **number**
    vinyl_max_tuple_size     = 'number', -- **number**
    vinyl_read_threads       = 'number', -- **number**
    vinyl_write_threads      = 'number', -- **number**
    vinyl_timeout            = 'number', -- **number**
    vinyl_defer_deletes      = 'boolean', -- **boolean**
    vinyl_run_count_per_level = 'number', -- **number**
    vinyl_run_size_ratio     = 'number', -- **number**
    vinyl_range_size         = 'number', -- **number**
    vinyl_page_size          = 'number', -- **number**
    vinyl_bloom_fpr          = 'number', -- **number**

    log                      = 'string', -- **string**
    log_nonblock             = 'boolean', -- **boolean**
    log_level                = 'string|number', -- **string|number**
    log_modules              = 'json', -- **json**
    log_format               = 'string', -- **string**

    audit_log                = 'string', -- **string**
    audit_nonblock           = 'boolean', -- **boolean**
    audit_format             = 'string', -- **string**
    audit_filter             = 'string', -- **string**

    auth_type                       = 'string', -- **string**
    auth_delay                      = 'number', -- **number**
    disable_guest                   = 'boolean', -- **boolean**
    password_lifetime_days          = 'number', -- **number**
    password_min_length             = 'number', -- **number**
    password_enforce_uppercase      = 'boolean', -- **boolean**
    password_enforce_lowercase      = 'boolean', -- **boolean**
    password_enforce_digits         = 'boolean', -- **boolean**
    password_enforce_specialchars   = 'boolean', -- **boolean**
    password_history_length         = 'number', -- **number**

    flightrec_enabled        = 'boolean', -- **boolean**
    flightrec_logs_size      = 'number', -- **number**
    flightrec_logs_max_msg_size = 'number', -- **number**
    flightrec_logs_log_level = 'number', -- **number**
    flightrec_metrics_interval = 'number', -- **number**
    flightrec_metrics_period = 'number', -- **number**
    flightrec_requests_size = 'number', -- **number**
    flightrec_requests_max_req_size = 'number', -- **number**
    flightrec_requests_max_res_size = 'number', -- **number**

    io_collect_interval      = 'number', -- **number**
    readahead                = 'number', -- **number**
    snap_io_rate_limit       = 'number', -- **number**
    too_long_threshold       = 'number', -- **number**
    wal_mode                 = 'string', -- **string**
    rows_per_wal             = 'number', -- **number**  (**deprecated**)
    wal_max_size             = 'number', -- **number**
    wal_queue_max_size       = 'number', -- **number**
    wal_dir_rescan_delay     = 'number', -- **number**
    wal_cleanup_delay        = 'number', -- **number**
    wal_ext                  = 'json',   -- **json**
    force_recovery           = 'boolean', -- **boolean**
    replication              = 'string', -- **string**
    instance_uuid            = 'string', -- **string**
    replicaset_uuid          = 'string', -- **string**
    custom_proc_title        = 'string', -- **string**
    pid_file                 = 'string', -- **string**
    background               = 'boolean', -- **boolean**
    username                 = 'string', -- **string**
    coredump                 = 'boolean', -- **boolean**
    checkpoint_interval      = 'number', -- **number**
    checkpoint_wal_threshold = 'number', -- **number**
    checkpoint_count         = 'number', -- **number**
    read_only                = 'boolean', -- **boolean**
    hot_standby              = 'boolean', -- **boolean**
    worker_pool_threads      = 'number', -- **number**
    replication_threads      = 'number', -- **number**
    replication_timeout      = 'number', -- **number**
    replication_sync_lag     = 'number', -- **number**
    replication_sync_timeout = 'number', -- **number**
    replication_connect_timeout = 'number', -- **number**
    replication_connect_quorum = 'number', -- **number**
    replication_skip_conflict = 'boolean', -- **boolean**
    replication_synchro_quorum = 'string|number', -- **string|number**
    replication_synchro_timeout = 'number', -- **number**
    feedback_enabled         = 'boolean', -- **boolean**
    feedback_host            = 'string', -- **string**
    feedback_interval        = 'number', -- **number**
    feedback_crashinfo       = 'boolean', -- **boolean**
    feedback_send_metrics    = 'boolean', -- **boolean**
    feedback_metrics_collect_interval = 'number', -- **number**
    feedback_metrics_limit   = 'number', -- **number**
    net_msg_max              = 'number', -- **number**
    iproto_threads           = 'number', -- **number**
    sql_cache_size           = 'number', -- **number**
    txn_timeout              = 'number', -- **number**
    election_mode            = 'string', -- **string**
    election_timeout         = 'number', -- **number**
    election_fencing_mode    = 'string', -- **string**
    metrics                  = 'json', -- **json**
}

local function load_file(filename)
    checks('string')
    local data, err = utils.file_read(filename)
    if data == nil then
        return nil, err
    end

    local file_sections, err
    if filename:endswith('.yml') or filename:endswith('.yaml') then
        local ok, ret = pcall(yaml.decode, data)
        if ok then
            file_sections = ret
        else
            err = DecodeYamlError:new('%s: %s', filename, ret)
        end
    else
        err = ParseConfigError:new('%s: Unsupported file type', filename)
    end

    if file_sections == nil then
        return nil, err
    end

    return file_sections
end

local function load_dir(dirname)
    local files = {}
    utils.table_append(files, fio.glob(fio.pathjoin(dirname, '*.yml')))
    utils.table_append(files, fio.glob(fio.pathjoin(dirname, '*.yaml')))
    table.sort(files)

    local ret = {}
    local origin = {}

    for _, f in pairs(files) do
        local file_sections, err = load_file(f)
        if file_sections == nil then
            return nil, err
        end

        for section_name, content in pairs(file_sections) do
            if ret[section_name] == nil then
                ret[section_name] = {}
                origin[section_name] = fio.basename(f)
            else
                return nil, ParseConfigError:new(
                    'collision of section %q in %s between %s and %s',
                    section_name, dirname, origin[section_name], fio.basename(f)
                )
            end
            if type(content) ~= 'table' then
                log.warn(
                    'invalid content ignored in file %s in section %s: '..
                    'expected a table of key-value pairs, got %s',
                    fio.basename(f), section_name, type(content)
                )
                goto next
            end
            for argname, argvalue in pairs(content) do
                ret[section_name][argname:lower()] = argvalue
            end
            ::next::
        end
    end

    return ret
end

local function parse_args()
    local ret = {}

    local stop = false
    local i = 0
    while i < #arg do
        i = i + 1

        if arg[i] == '--' then
            stop = true
        elseif stop then
            table.insert(ret, arg[i])
        elseif arg[i]:startswith('--') then
            local argname = arg[i]:lower():gsub('^%-%-', ''):gsub('-', '_')
            local argvalue = arg[i+1]
            i = i + 1
            ret[argname] = argvalue or ''
        else
            table.insert(ret, arg[i])
        end
    end

    return ret
end

local function parse_env()
    local ret = {}
    for argname, argvalue in pairs(os.environ()) do
        argname = string.lower(argname)

        if argname:startswith('tarantool_') then
            argname = argname:gsub("^tarantool_", ''):gsub("-", "_")
            ret[argname] = argvalue
        end
    end

    return ret
end

local function parse_file(filename, search_name)
    checks('string', 'string')

    local file_sections, err

    if filename:endswith('/') then
        file_sections, err = load_dir(filename)
    else
        file_sections, err = load_file(filename)
    end

    if file_sections == nil then
        return nil, err
    end

    local section_names = {'default'}
    local search_name_parts = search_name:split('.')
     for n = 1, #search_name_parts do
         local section_name = table.concat(search_name_parts, '.', 1, n)
         table.insert(section_names, section_name)
    end

    local ret = {}
    local sections = {}
    for section_name, _ in pairs(file_sections) do
        sections[section_name] = true
    end
    for _, section_name in ipairs(section_names) do
        local content = file_sections[section_name] or {}
        if type(content) ~= 'table' then
            log.warn(
                'invalid content ignored in file %s in section %s: '..
                'expected a table of key-value pairs, got %s',
                filename, section_name, type(content)
            )
            goto next
        end
        sections[section_name] = false
        for argname, argvalue in pairs(content) do
            ret[argname:lower()] = argvalue
        end
        ::next::
    end
    local names = {}
    for section_name, ignored in pairs(sections) do
        if ignored then
           table.insert(names, section_name)
        end
    end
    if #names > 0 then
        log.warn('Some sections in config file %s were ignored: %s',
            filename, table.concat(names, ', '))
    end

    return ret
end

local function supplement(to, from)
    checks('table', 'table')
    for argname, argvalue in pairs(from) do
        if to[argname] == nil then
            to[argname] = argvalue
        end
    end

    return to
end

--- Parse command line arguments, environment variables, and configuration files.
--
-- For example, running an application as follows:
--    TARANTOOL_MY_CUSTOM_ARG='value' ./init.lua --alias router --memtx-memory 33554432
-- results in:
--    local argparse = require('cartridge.argparse')
--    argparse.parse()
--    ---
--    - memtx_memory: 33554432
--      my_custom_arg: value
--      alias: router
--    ...
--
-- @function parse
-- @treturn {argname=value,...}
local function _parse()
    local args = {}

    supplement(args, parse_args())
    supplement(args, parse_env())

    if args.app_name == nil then
        local app_dir = fio.dirname(arg[0])
        local rockspecs = fio.glob(fio.pathjoin(app_dir, '*-scm-1.rockspec'))

        if #rockspecs == 1 then
            args.app_name = string.match(fio.basename(rockspecs[1]), '^(%g+)%-scm%-1%.rockspec$')
        end
    end

    if args.cfg == nil then
        return args
    end

    if fio.path.is_dir(args.cfg) and not args.cfg:endswith('/') then
        args.cfg = args.cfg .. '/'
    end

    local search_name = args.instance_name or ''
    if args.app_name ~= nil then
        search_name = args.app_name .. '.' .. search_name
    end

    local cfg, err = parse_file(args.cfg, search_name)
    if not cfg then
        return nil, err
    else
        supplement(args, cfg)
    end

    return args
end

local function parse()
    if vars.args ~= nil then
        return vars.args
    end

    local args, err = _parse()
    if args == nil then
        return nil, err
    end

    vars.args = args
    return args
end

--- Filter the results of parsing and cast variables to a given type.
--
-- From all the configuration options gathered by `parse`, select only those
-- specified in the filter.
--
-- For example, running an application as follows:
--    TARANTOOL_ARG1='value' tarantool ./init.lua --arg2 100 --arg3 true
-- results in:
--    local opts, err = argparse.get_opts({
--        arg1 = 'string',
--        arg2 = 'number',
--        arg3 = 'boolean'
--        missing_arg = 'string', -- no such arg, argparse returns nothing for this arg
--    })
--    ---
--    - arg1: value
--      arg2: 100
--      arg3: true
--    ...
--
-- Each option have a type: string, boolean, number.
-- There is an ability to set multiple types for one option.
-- Types are split by separator `|`,  e.g. `string|number`.
--
-- @function get_opts
-- @tparam {argname=type,...} filter
-- @treturn {argname=value,...}
local function get_opts(opts)
    local args = parse()

    local ret = {}
    for optname, opttype in pairs(opts) do
        local opttype_str = false
        local opttype_num = false
        local opttype_bool = false
        local opttype_json = false
        for _, _opttype in pairs(string.split(opttype, '|')) do
            if _opttype == 'string' then
                opttype_str = true
            elseif _opttype == 'number' then
                opttype_num = true
            elseif _opttype == 'boolean' then
                opttype_bool = true
            elseif _opttype == 'json' then
                opttype_json = true
            else
                return nil, TypeCastError:new(
                    "can't typecast %s to %s (unsupported type)",
                    optname, _opttype
                )
            end
        end

        local value = args[optname]
        if value == nil then -- luacheck: ignore 542
            -- ignore
        elseif type(value) == opttype then
            ret[optname] = value
        elseif type(value) == 'number' and ( opttype_num or opttype_str ) then
            ret[optname] = value
        elseif type(value) == 'string' then
            local _value

            if opttype_num then
                _value = tonumber(value)
            end
            if _value == nil and opttype_bool then
                _value = toboolean(value)
            end
            if _value == nil and opttype_str then
                _value = value
            elseif _value == nil and opttype_json then
                local ok, res = pcall(json.decode, value)
                if ok then
                    _value = res
                else
                    return nil, TypeCastError:new(
                        "invalid json parameter %s: %q",
                        optname, value
                    )
                end
            end
            if not opttype_num and not opttype_bool and not opttype_str and not opttype_json then
                return nil, TypeCastError:new(
                    "can't typecast %s to %s (unsupported type)",
                    optname, opttype
                )
            end

            if _value == nil then
                return nil, TypeCastError:new(
                    "can't typecast %s=%q to %s",
                    optname, value, opttype
                )
            end

            ret[optname] = _value
        else
            return nil, TypeCastError:new(
                "invalid configuration parameter %s (%s expected, got %s)",
                optname, opttype, type(value)
            )
        end
    end

    return ret
end

return {
    parse = parse,

    get_opts = get_opts,

    get_params = function()
        return box_opts
    end,

    --- Shorthand for `get_opts(box_opts)`.
    -- @function get_box_opts
    get_box_opts = function()
        return get_opts(box_opts)
    end,

    --- Shorthand for `get_opts(cluster_opts)`.
    -- @function get_cluster_opts
    get_cluster_opts = function()
        return get_opts(cluster_opts)
    end,
}
