--- Tarantool framework for distributed applications development.
--
-- Cartridge provides you a simple way
-- to manage distributed applications operations.
-- The cluster consists of several Tarantool instances acting in concert.
-- Cartridge does not care about how the instances start,
-- it only cares about the configuration of already running processes.
--
-- Cartridge automates vshard and replication configuration,
-- simplifies custom configuration and administrative tasks.
-- @module cartridge

local title = require('title')
local fio = require('fio')
local uri = require('uri')
local log = require('log')
local errno = require('errno')
local checks = require('checks')
local errors = require('errors')
local membership = require('membership')
local membership_network = require('membership.network')
local http = require('http.server')
local fiber = require('fiber')
local socket = require('socket')
local json = require('json')
local digest = require('digest')
local tarantool_version = require('tarantool').version

local rpc = require('cartridge.rpc')
local auth = require('cartridge.auth')
local utils = require('cartridge.utils')
local roles = require('cartridge.roles')
local webui = require('cartridge.webui')
local issues = require('cartridge.issues')
local graphql = require('cartridge.graphql')
local upload = require('cartridge.upload')
local argparse = require('cartridge.argparse')
local topology = require('cartridge.topology')
local twophase = require('cartridge.twophase')
local hotreload = require('cartridge.hotreload')
local confapplier = require('cartridge.confapplier')
local vshard_utils = require('cartridge.vshard-utils')
local cluster_cookie = require('cartridge.cluster-cookie')
local service_registry = require('cartridge.service-registry')
local logging_whitelist = require('cartridge.logging_whitelist')
local pool = require('cartridge.pool')
local cartridge_utils = require('cartridge.utils')

local lua_api_topology = require('cartridge.lua-api.topology')
local lua_api_failover = require('cartridge.lua-api.failover')
local lua_api_vshard = require('cartridge.lua-api.vshard')
local lua_api_deprecated = require('cartridge.lua-api.deprecated')
local lua_api_boxinfo = require('cartridge.lua-api.boxinfo')

local ConsoleListenError = errors.new_class('ConsoleListenError')
local CartridgeCfgError = errors.new_class('CartridgeCfgError')
local HttpInitError = errors.new_class('HttpInitError')

local DEFAULT_CLUSTER_COOKIE = 'secret-cluster-cookie'

local _ = require('cartridge.feedback')
local ok, VERSION = pcall(require, 'cartridge.VERSION')
if not ok then
    VERSION = 'unknown'
end

local cartridge_opts

--- Vshard storage group configuration.
--
-- Every vshard storage must be assigned to a group.
-- @tfield
--   number bucket_count
--   Bucket count for the storage group.
-- @table VshardGroup
local function check_vshard_group(name, params)
    if type(name) ~= 'string' then
        return nil, 'bad argument options.vshard_groups' ..
            ' to cartridge.cfg (table must have string keys)'
    end

    local field = string.format('options.vshard_groups[%s]', name)

    if type(params) ~= 'table' then
        return nil, string.format(
            'bad argument %s' ..
            ' (table expected, got %s)',
            field, type(params)
        )
    end

    local bucket_count = params.bucket_count
    if bucket_count ~= nil and type(bucket_count) ~= 'number' then
        return nil, string.format(
            'bad argument %s.bucket_count' ..
            ' (?number expected, got %s)',
            field, type(bucket_count)
        )
    end

    local known_keys = {
        bucket_count = true,
    }
    for key, _ in pairs(params) do
        if not known_keys[key] then
            return string.format(
                'unexpected argument %s.%s',
                field, key
            )
        end
    end

    return true
end

--- Initialize the cartridge module.
--
-- After this call, you can operate the instance via Tarantool console.
-- Notice that this call does not initialize the database - `box.cfg` is not called yet.
-- Do not try to call `box.cfg` yourself: `cartridge` will do it when it is time.
--
-- Both `cartridge.cfg` and `box.cfg` options can be configured with
-- command-line arguments or environment variables.
--
-- @function cfg
-- @tparam table opts Available options are:
--
-- @tparam ?string opts.workdir
--  a directory where all data will be stored: snapshots, wal logs and cartridge config file.
--  (default: ".", overridden by
--  env `TARANTOOL_WORKDIR`,
--  args `--workdir`)
--
-- @tparam ?string opts.advertise_uri
--  either `"<HOST>:<PORT>"` or `"<HOST>:"` or `"<PORT>"`.
--  Used by other instances to connect to the current one.
--
--  When `<HOST>` isn't specified, it's detected as the only non-local IP address.
--  If there is more than one IP address available - defaults to "localhost".
--
--  When `<PORT>` isn't specified, it's derived as follows:
--  If the `TARANTOOL_INSTANCE_NAME` has numeric suffix `_<N>`, then `<PORT> = 3300+<N>`.
--  Otherwise default `<PORT> = 3301` is used.
--
-- @tparam ?string opts.cluster_cookie
--  secret used to separate unrelated applications, which
--  prevents them from seeing each other during broadcasts.
--  Also used as admin password in HTTP and binary connections and for
--  encrypting internal communications.
--  Allowed symbols are `[a-zA-Z0-9_.~-]`.
--  (default: "secret-cluster-cookie", overridden by
--  env `TARANTOOL_CLUSTER_COOKIE`,
--  args `--cluster-cookie`)
--
-- @tparam ?boolean opts.swim_broadcast
--  Announce own `advertise_uri` over UDP broadcast.
--
--  Cartridge health-checks are governed by SWIM protocol. To simplify
--  instances discovery on start it can UDP broadcast all networks
--  known from `getifaddrs()` C call. The broadcast is sent to several
--  ports: default 3301, the `<PORT>` from the `advertise_uri` option,
--  and its neighbours `<PORT>+1` and `<PORT>-1`.
--
--  (**Added** in v2.3.0-23,
--  default: true, overridden by
--  env `TARANTOOL_SWIM_BROADCAST`,
--  args `--swim-broadcast`)
--
-- @tparam ?number opts.bucket_count
--  bucket count for vshard cluster. See vshard doc for more details.
--  Can be set only **once**, before the first run of Cartridge application, and can't be
--  changed after that.
--  (default: 30000, overridden by
--  env `TARANTOOL_BUCKET_COUNT`,
--  args `--bucket-count`)
--
-- @tparam ?number opts.rebalancer_mode
--  rebalancer_mode for vshard cluster. See vshard doc for more details.
--  (default: "auto", overridden by
--  env `TARANTOOL_REBALANCER_MODE`,
--  args `--rebalancer-mode`)
--
-- @tparam ?table opts.vshard_groups
--  vshard storage groups.
--  `{group_name = VshardGroup, ...}`, `{'group1', 'group2', ...}` or
--  `{group1 = VshardGroup, 'group2', ...}`.
--  default group name: `default`
--
-- @tparam ?boolean opts.http_enabled
--  whether http server should be started
--  (default: true, overridden by
--  env `TARANTOOL_HTTP_ENABLED`,
--  args `--http-enabled`)
--
-- @tparam ?boolean opts.webui_enabled
--  whether WebUI and corresponding API (HTTP + GraphQL) should be
--  initialized. Ignored if `http_enabled` is `false`. Doesn't
--  affect `auth_enabled`.
--
--  (**Added** in v2.4.0-38,
--  default: true, overridden by
--  env `TARANTOOL_WEBUI_ENABLED`,
--  args `--webui-enabled`)
--
-- @tparam ?string|number opts.http_port
--  port to open administrative UI and API on
--  (default: 8081, derived from
--  `TARANTOOL_INSTANCE_NAME`,
--  overridden by
--  env `TARANTOOL_HTTP_PORT`,
--  args `--http-port`)
--
-- @tparam ?string opts.http_host
--  host to open administrative UI and API on
--  (**Added** in v2.4.0-42,
--  default: "0.0.0.0", overridden by
--  env `TARANTOOL_HTTP_HOST`,
--  args `--http-host`)
--
-- @tparam ?string opts.webui_prefix
--  modify WebUI and cartridge HTTP API routes
--  (**Added** in v2.6.0-18,
--  default: "", overridden by
--  env `TARANTOOL_WEBUI_PREFIX`,
--  args `--webui-prefix`)
--
-- @tparam ?boolean opts.webui_enforce_root_redirect
--  respond on `GET /` with a redirect to `<WEBUI_PREFIX>/admin`.
--  (**Added** in v2.6.0-18,
--  default: true, overridden by
--  env `TARANTOOL_WEBUI_ENFORCE_ROOT_REDIRECT`,
--  args `--webui-enforce-root-redirect`)
--
-- @tparam ?string opts.alias
-- human-readable instance name that will be available in administrative UI
--  (default: argparse instance name, overridden by
--  env `TARANTOOL_ALIAS`,
--  args `--alias`)
--
-- @tparam table opts.roles
--   list of user-defined roles that will be available
--   to enable on the instance_uuid
--
-- @tparam ?boolean opts.auth_enabled
--   toggle authentication in administrative UI and API
--   (default: false)
--
-- @tparam ?string opts.auth_backend_name
--   user-provided set of callbacks related to authentication
--
-- @tparam ?string opts.console_sock
--   Socket to start console listening on.
--   (default: nil, overridden by
--   env `TARANTOOL_CONSOLE_SOCK`,
--   args `--console-sock`)
--
-- @tparam ?{string,...} opts.webui_blacklist
--   List of pages to be hidden in WebUI.
--   (**Added** in v2.0.1-54, default: `{}`)
--
-- @tparam ?boolean opts.upgrade_schema
--   Run schema upgrade on the leader instance.
--   (**Added** in v2.0.2-3,
--   default: `false`, overridden by
--   env `TARANTOOL_UPGRADE_SCHEMA`
--   args `--upgrade-schema`)
--
-- @tparam ?boolean opts.roles_reload_allowed
--   Allow calling `cartridge.reload_roles`.
--   (**Added** in v2.3.0-73, default: `false`)
--
-- @tparam ?string opts.upload_prefix
--   Temporary directory used for saving files during clusterwide
--   config upload. If relative path is specified, it's evaluated
--   relative to the `workdir`.
--   (**Added** in v2.4.0-43,
--   default: `/tmp`, overridden by
--   env `TARANTOOL_UPLOAD_PREFIX`,
--   args `--upload-prefix`)
--
-- @tparam ?boolean opts.enable_failover_suppressing
--   Enable failover suppressing. It forces eventual failover
--   to stop in case of constant switching.
--   default: `false`, overridden by
--   env `TARANTOOL_ENABLE_FAILOVER_SUPPRESSING`,
--   args `--enable-failover-suppressing`)
--
-- @tparam ?boolean opts.enable_synchro_mode
--   Allow to use sync spaces in Cartridge.
--   default: `false`, overridden by
--   env `TARANTOOL_ENABLE_SYNCHRO_MODE`,
--   args `--enable-synchro-mode`)
--
-- @tparam ?boolean opts.disable_raft_on_small_clusters
--   Disable Raft Failover on small clusters (where
--   number of instances is less than 3)
--   default: `true`, overridden by
--   env `TARANTOOL_DISABLE_RAFT_ON_SMALL_CLUSTERS`,
--   args `--disable-raft-on-small-clusters`)
--
-- @tparam ?boolean opts.set_cookie_hash_membership
--   Set cookie hash instead of full cluster cookie
--   as membership encryption key.
--   default: `false`, overridden by
--   env `TARANTOOL_SET_COOKIE_HASH_MEMBERSHIP`,
--   args `--set-cookie-hash-membership`)
--
-- @tparam ?boolean opts.rebalancer_mode
--   Rebalancer mode for vshard cluster. See vshard doc for more details.
--   env `TARANTOOL_REBALANCER_MODE`,
--   args `--rebalancer-mode`)
--
-- @tparam ?table box_opts
--   tarantool extra box.cfg options (e.g. force_recovery),
--   that may require additional tuning on startup.
--
-- @return[1] true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function cfg(opts, box_opts)
    checks({
        workdir = '?string',
        advertise_uri = '?string',
        cluster_cookie = '?string',
        bucket_count = '?number',
        rebalancer_mode = '?string',
        http_port = '?string|number',
        http_host = '?string',
        http_enabled = '?boolean',
        webui_enabled = '?boolean',
        webui_prefix = '?string',
        webui_enforce_root_redirect = '?boolean',
        alias = '?string',
        roles = 'table',
        auth_backend_name = '?string',
        auth_enabled = '?boolean',
        vshard_groups = '?table',
        console_sock = '?string',
        webui_blacklist = '?table',
        upgrade_schema = '?boolean',
        swim_broadcast = '?boolean',
        roles_reload_allowed = '?boolean',
        upload_prefix = '?string',
        enable_failover_suppressing = '?boolean',
        enable_sychro_mode = '?boolean',
        enable_synchro_mode = '?boolean',
        disable_raft_on_small_clusters = '?boolean',
        set_cookie_hash_membership = '?boolean',

        transport = '?string',
        ssl_ciphers = '?string',

        ssl_server_ca_file = '?string',
        ssl_server_cert_file = '?string',
        ssl_server_key_file = '?string',
        ssl_server_password = '?string',

        ssl_client_ca_file = '?string',
        ssl_client_cert_file = '?string',
        ssl_client_key_file = '?string',
        ssl_client_password = '?string',
        disable_errstack = '?boolean',
    }, '?table')

    if tarantool_version:sub(1, 2) == '3.' then
        return nil, CartridgeCfgError:new("Unsupported Tarantool version " .. tarantool_version)
    end

    if opts.enable_sychro_mode ~= nil then
        opts.enable_synchro_mode = opts.enable_sychro_mode
        log.warn('enable_sychro_mode is deprecated. Use enable_synchro_mode instead')
    end

    if opts.webui_blacklist ~= nil then
        local i = 0
        for _, _ in pairs(opts.webui_blacklist) do
            i = i + 1
            if type(opts.webui_blacklist[i]) ~= 'string' then
                error('bad argument opts.webui_blacklist to cartridge.cfg' ..
                    ' (contiguous array of strings expected)', 2
                )
            end
        end
    end

    local args, err = argparse.parse()
    if args == nil then
        return nil, err
    end
    local _cluster_opts, err = argparse.get_cluster_opts()
    if _cluster_opts == nil then
        return nil, err
    end
    local _box_opts, err = argparse.get_box_opts()
    if _box_opts == nil then
        return nil, err
    end

    for k, v in pairs(_cluster_opts) do
        opts[k] = v
    end

    if box_opts == nil then
        box_opts = {}
    end
    for k, v in pairs(_box_opts) do
        box_opts[k] = v
    end

    if type(opts.transport) == 'string' then
        opts.transport = opts.transport:lower()
    end

    if opts.transport == 'ssl' then
        if type(cartridge_utils.feature) ~= 'table' then
            log.error('No SSL support for this tarantool version')
            return nil, CartridgeCfgError:new('No SSL support for this tarantool version')
        end
        if not cartridge_utils.feature.ssl then
            log.error('No SSL support for this tarantool version in feature list')
            return nil, CartridgeCfgError:new('No SSL support for this tarantool version in feature list')
        end
        if not cartridge_utils.feature.ssl_password
            and (opts.ssl_client_password ~= nil or opts.ssl_server_password ~= nil) then
            log.error('No SSL password support for this tarantool version in feature list')
            return nil, CartridgeCfgError:new('No SSL password support for this tarantool version in feature list')
        end
    end

    pool.init({
        transport = opts.transport,
        ssl_ca_file = opts.ssl_client_ca_file,
        ssl_cert_file = opts.ssl_client_cert_file,
        ssl_key_file = opts.ssl_client_key_file,
        ssl_password = opts.ssl_client_password,
    })

    vshard_utils.init({
        transport = opts.transport,

        ssl_server_ca_file = opts.ssl_server_ca_file,
        ssl_server_cert_file = opts.ssl_server_cert_file,
        ssl_server_key_file = opts.ssl_server_key_file,
        ssl_server_password = opts.ssl_server_password,

        ssl_client_ca_file = opts.ssl_client_ca_file,
        ssl_client_cert_file = opts.ssl_client_cert_file,
        ssl_client_key_file = opts.ssl_client_key_file,
        ssl_client_password = opts.ssl_client_password,
    })

    -- Using syslog driver, when available, by default
    if box_opts.log == nil then
        local syslog, _ = socket.connect('unix/', '/dev/log')

        -- On RHEL 7.9 and Centos 7.9 /dev/log is a UDP socket, not TCP
        if not syslog then
            local s = socket('AF_UNIX', 'SOCK_DGRAM', 0)
            if s:sysconnect('unix/', '/dev/log') then
                syslog = s
            end
        end

        if not syslog then
            syslog, _ = socket.connect('unix/', '/var/run/syslog')
        end

        if syslog then
            syslog:close()

            local identity = table.concat({
                args.app_name or 'tarantool',
                args.instance_name
            }, '.')
            box_opts.log = string.format('syslog:identity=%s', identity)
        end
    end

    if log.cfg ~= nil then
        local _, err = CartridgeCfgError:pcall(log.cfg, {
            log = box_opts.log,
            level = box_opts.log_level,
            nonblock = box_opts.log_nonblock,
        })

        if err ~= nil then
            return nil, err
        end

        -- Workaround for log_format can't be set at boot time
        -- See https://github.com/tarantool/tarantool/issues/5121
        local _, err = CartridgeCfgError:pcall(log.cfg, {
            format = box_opts.log_format,
        })

        if err ~= nil then
            return nil, err
        end
    end

    if box_opts.custom_proc_title == nil and args.instance_name ~= nil then
        if args.app_name == nil then
            box_opts.custom_proc_title = args.instance_name
        else
            box_opts.custom_proc_title = args.app_name .. '@' .. args.instance_name
        end
    end

    if box_opts.custom_proc_title ~= nil then
        title.update(box_opts.custom_proc_title)
    end

    if opts.rebalancer_mode == nil then
        opts.rebalancer_mode = 'auto'
    elseif not (opts.rebalancer_mode == 'auto'
    or opts.rebalancer_mode == 'off'
    or opts.rebalancer_mode == 'manual') then
        return nil, CartridgeCfgError:new('Invalid rebalancer_mode %q', opts.rebalancer_mode)
    end

    local vshard_groups = {}
    for k, v in pairs(opts.vshard_groups or {}) do
        local name, params
        if type(k) == 'number' and type(v) == 'string' then
            -- {'group-name'}
            name, params = v, {}
        else
            -- {['group-name'] = {bucket_count=1000}}
            name, params = k, table.copy(v)
        end

        local ok, err = check_vshard_group(name, params)
        if not ok then
            error(err, 2)
        end

        vshard_groups[name] = params
    end

    if (confapplier.get_state() ~= '') then
        return nil, CartridgeCfgError:new('Cluster is already initialized')
    end

    if opts.workdir == nil then
        opts.workdir = '.'
    end
    opts.workdir = fio.abspath(opts.workdir)

    local ok, err = utils.mktree(opts.workdir)
    if not ok then
        return nil, err
    end

    if box_opts.work_dir ~= nil then
        log.warn(
            "Box option 'work_dir' is deprecated." ..
            " Please, dont't use it"
        )
        local ok, err = utils.mktree(box_opts.work_dir)
        if not ok then
            return nil, err
        end
    end

    for _, option in pairs({'memtx_dir', 'vinyl_dir', 'wal_dir'}) do
        local path = box_opts[option]
        if path == nil then
            path = opts.workdir
        end

        if not path:startswith('/') then
            -- calc relative path
            path = fio.pathjoin(opts.workdir, path)
        end

        box_opts[option] = path

        local ok, err = utils.mktree(path)
        if not ok then
            return nil, err
        end
    end

    cluster_cookie.init(opts.workdir)
    if opts.cluster_cookie ~= nil then
        cluster_cookie.set_cookie(opts.cluster_cookie)
    end
    if cluster_cookie.cookie() == nil then
        cluster_cookie.set_cookie(DEFAULT_CLUSTER_COOKIE)
    end

    local advertise
    if opts.advertise_uri ~= nil then
        advertise = uri.parse(opts.advertise_uri)
    else
        advertise = {}
    end
    if advertise == nil then
        return nil, CartridgeCfgError:new('Invalid advertise_uri %q', opts.advertise_uri)
    end

    local port_offset
    if args.instance_name ~= nil then
        port_offset = tonumber(args.instance_name:match('_(%d+)$'))
    end

    if advertise.host == nil then
        local ip4_map = {}
        for _, ifaddr in pairs(membership_network.getifaddrs() or {}) do
            if ifaddr.name ~= 'lo' and ifaddr.inet4 ~= nil then
                ip4_map[ifaddr.name or #ip4_map+1] = ifaddr.inet4
            end
        end

        local ip_count = utils.table_count(ip4_map or {})

        if ip_count > 1 then
            log.info('This server has more than one non-local IP address:')
            for name, inet4 in pairs(ip4_map) do
                log.info('  %s: %s', name, inet4)
            end
            log.info('Auto-detection of IP address disabled. '
                .. 'Use --advertise-uri argument'
                .. ' or ADVERTISE_URI environment variable'
            )
            advertise.host = 'localhost'
        elseif ip_count == 1 then
            local _, inet4 = next(ip4_map)
            advertise.host = inet4
            log.info('Auto-detected IP to be %q', advertise.host)
        else
            advertise.host = 'localhost'
        end
    end

    if advertise.service == nil then
        if port_offset ~= nil then
            advertise.service = 3300 + port_offset
            log.info('Derived binary_port to be %d', advertise.service)
        else
            advertise.service = 3301
        end
    else
        advertise.service = tonumber(advertise.service)
    end

    if advertise.service == nil then
        return nil, CartridgeCfgError:new('Invalid port in advertise_uri %q', opts.advertise_uri)
    end

    if advertise.ipv6 then
        advertise.host = '[' .. advertise.ipv6 .. ']'
    end

    local membership_new_opts, err = argparse.get_opts({
        swim_protocol_period_seconds = 'number',
        swim_anti_entropy_period_seconds = 'number',
        swim_max_packet_size = 'number',
        swim_ack_timeout_seconds = 'number',
        swim_suspect_timeout_seconds = 'number',
        swim_num_failure_detection_subgroups = 'number',
    })
    if err ~= nil then
        return nil, err
    end

    for opt_name, opt_value in pairs(membership_new_opts) do
        local opt_name = opt_name:match('swim_(.+)'):upper()
        require("membership.options")[opt_name] = opt_value
    end

    local ok, err = CartridgeCfgError:pcall(membership.init,
        advertise.host, advertise.service
    )
    if not ok then
        return nil, err
    end
    local advertise_uri = membership.myself().uri
    log.info('Using advertise_uri %q', advertise_uri)

    if opts.alias == nil then
        opts.alias = args.instance_name
    end
    local encryption_key = cluster_cookie.cookie()

    if opts.set_cookie_hash_membership == true then
        encryption_key = digest.md5_hex(encryption_key)
    else
        log.warn(
            'Consider changing membership encryption key to cookie hash manually. ' ..
            'set_cookie_hash_membership will be true by default in next releases.'
        )
    end

    membership.set_encryption_key(encryption_key)
    membership.set_payload('alias', opts.alias)

    local probe_uri_opts, err = argparse.get_opts({probe_uri_timeout = 'number'})
    if err ~= nil then
        return nil, err
    end

    local delay = require('membership.options').ACK_TIMEOUT_SECONDS
    local deadline = fiber.clock() + (probe_uri_opts.probe_uri_timeout or 0)

    while true do
        local next_wakeup = fiber.clock() + delay
        local ok, estr = membership.probe_uri(membership.myself().uri)
        local now = fiber.clock()
        if ok then
            log.info('Probe uri was successful')
            break
        elseif now >= deadline then
            return nil, CartridgeCfgError:new('Can not ping myself: %s', estr)
        else
            log.info('Can not ping myself: %s', estr)
            fiber.sleep(next_wakeup - now)
        end
    end

    if opts.swim_broadcast == nil then
        opts.swim_broadcast = true
    end
    if opts.swim_broadcast then
        -- broadcast several popular ports
        for p, _ in pairs({
            [3301] = true,
            [advertise.service] = true,
            [advertise.service-1] = true,
            [advertise.service+1] = true,
        }) do
            membership.broadcast(p)
        end
    end

    -- Gracefully leave membership in case of stop if box.ctl.on_shutdown supported
    if box.ctl.on_shutdown ~= nil then
        box.ctl.on_shutdown(function() pcall(membership.leave) end)
    end

    if opts.auth_backend_name == nil then
        opts.auth_backend_name = 'cartridge.auth-backend'
    end

    local auth_backend, err = CartridgeCfgError:pcall(require, opts.auth_backend_name)
    if not auth_backend then
        return nil, err
    elseif type(auth_backend) ~= 'table' then
        return nil, CartridgeCfgError:new(
            "Auth backend must export a table, got %s",
            type(auth_backend)
        )
    end

    local ok, err = CartridgeCfgError:pcall(auth.set_callbacks, auth_backend)
    if not ok then
        return nil, err
    end

    local auth_enabled = opts.auth_enabled
    if auth_enabled == nil then
        auth_enabled = false
    end
    local ok, err = CartridgeCfgError:pcall(auth.set_enabled, auth_enabled)
    if not ok then
        return nil, err
    end

    if opts.http_port == nil then
        if port_offset ~= nil then
            opts.http_port = 8080 + port_offset
            log.info('Derived http_port to be %d', opts.http_port)
        else
            opts.http_port = 8081
        end
    end
    if opts.http_host == nil then
        opts.http_host = '0.0.0.0'
    end

    if opts.http_enabled == nil then
        opts.http_enabled = true
    end
    if opts.webui_enabled == nil then
        opts.webui_enabled = true
    end
    if opts.http_enabled then
        local ssl_opts, err = argparse.get_opts({
            http_ssl_cert_file = 'string',
            http_ssl_key_file = 'string',
            http_ssl_password = 'string',
            http_ssl_password_file = 'string',
            http_ssl_ca_file = 'string',
            http_ssl_ciphers = 'string',
        })
        if err ~= nil then
            return nil, err
        end
        local httpd = http.new(
            opts.http_host, opts.http_port,
            {
                log_requests = false,
                ssl_cert_file = ssl_opts.http_ssl_cert_file,
                ssl_key_file = ssl_opts.http_ssl_key_file,
                ssl_password = ssl_opts.http_ssl_password,
                ssl_password_file = ssl_opts.http_ssl_password_file,
                ssl_ca_file = ssl_opts.http_ssl_ca_file,
                ssl_ciphers = ssl_opts.http_ssl_ciphers,
            }
        )

        local ok, err = HttpInitError:pcall(httpd.start, httpd)
        if not ok then
            return nil, err
        end

        if opts.webui_prefix == nil then
            opts.webui_prefix = ''
        else
            -- Add leading '/' for frontend-core
            if not opts.webui_prefix:startswith('/') then
                opts.webui_prefix = '/' .. opts.webui_prefix
            end
            -- Remove trailing '/' because frontend-core can't handle it
            opts.webui_prefix = opts.webui_prefix:gsub('/$', '')
        end

        if opts.webui_enforce_root_redirect == nil then
            opts.webui_enforce_root_redirect = true
        end

        local ok, err = CartridgeCfgError:pcall(auth.init, httpd, {
            prefix = opts.webui_prefix,
            disable_errstack = opts.disable_errstack,
        })
        if not ok then
            return nil, err
        end

        graphql.init(httpd, {prefix = opts.webui_prefix,
            disable_errstack = opts.disable_errstack,
        })
        lua_api_boxinfo.set_webui_prefix(opts.webui_prefix)

        if opts.webui_enabled then
            local ok, err = HttpInitError:pcall(webui.init, httpd, {
                prefix = opts.webui_prefix,
                enforce_root_redirect = opts.webui_enforce_root_redirect,
            })
            if not ok then
                return nil, err
            end

            webui.set_blacklist(opts.webui_blacklist)
        end

        local srv_name = httpd.tcp_server:name()
        log.info('Listening HTTP on %s:%s', srv_name.host, srv_name.port)
        service_registry.set('httpd', httpd)
    end

    -- Set up vshard groups
    if next(vshard_groups) == nil then
        vshard_groups = nil
    else
        for _, params in pairs(vshard_groups) do
            if params.bucket_count == nil then
                params.bucket_count = opts.bucket_count
            end
        end
    end

    vshard_utils.set_known_groups(vshard_groups, opts.bucket_count, opts.rebalancer_mode)

    -- Set up issues
    local issue_limits, err = argparse.get_opts({
        fragmentation_threshold_critical = 'number',
        fragmentation_threshold_warning  = 'number',
        fragmentation_threshold_full = 'number',
        clock_delta_threshold_warning    = 'number',
    })

    if err ~= nil then
        return nil, err
    end

    local ok, err = issues.validate_limits(issue_limits)
    if not ok then
        return nil, err
    end

    issues.set_limits(issue_limits)

    local res, err = argparse.get_opts({
        disable_unrecoverable_instances = 'boolean',
        check_doubled_buckets = 'boolean',
        check_doubled_buckets_period = 'number',
    })

    if err ~= nil then
        return nil, err
    end

    issues.disable_unrecoverable(res.disable_unrecoverable_instances)
    issues.check_doubled_buckets(res.check_doubled_buckets, res.check_doubled_buckets_period)

    if opts.upload_prefix ~= nil then
        local path = opts.upload_prefix
        if not path:startswith('/') then
            -- calc relative path
            path = fio.pathjoin(opts.workdir, path)
        end

        opts.upload_prefix = path
        upload.set_upload_prefix(path)
    end

    -- Start console sock
    if opts.console_sock ~= nil then
        local console = require('console')
        local sock_name = 'unix/:' .. opts.console_sock
        local ok, sock = pcall(console.listen, sock_name)
        local _errno = errno()

        if ok then
            -- In Tarantool < 2.3.2 `console.listen` didn't raise,
            -- but created a socket with trimmed filename
            local unix_port = sock:name().port
            if #unix_port < #opts.console_sock then
                sock:close()
                fio.unlink(unix_port)
                ok = false
                _errno = assert(errno.ENOBUFS)
            end
        end

        if not ok then
            local strerror
            if _errno == assert(errno.ENOBUFS) then
                strerror = 'Too long console_sock exceeds UNIX_PATH_MAX limit'
            else
                strerror = errno.strerror(_errno)
            end

            return nil, ConsoleListenError:new('%s: %s', sock_name, strerror)
        end
    end

    -- Emulate support for NOTIFY_SOCKET in old tarantool.
    -- NOTIFY_SOCKET is fully supported in >= 2.2.2
    local tnt_version = string.split(_TARANTOOL, '.')
    local tnt_major = tonumber(tnt_version[1])
    local tnt_minor = tonumber(tnt_version[2])
    local tnt_patch = tonumber(tnt_version[3]:split('-')[1])
    if (tnt_major < 2) or (tnt_major == 2 and tnt_minor < 2) or
            (tnt_major == 2 and tnt_minor == 2 and tnt_patch < 2) then
        local notify_socket = os.getenv('NOTIFY_SOCKET')
        if notify_socket then
            local socket = require('socket')
            local sock = assert(socket('AF_UNIX', 'SOCK_DGRAM', 0), 'Can not create socket')
            sock:sendto('unix/', notify_socket, 'READY=1')
        end
    end

    -- Do last few steps
    if opts.roles_reload_allowed == true then
        hotreload.save_state()
    end

    local ok, err = roles.cfg(opts.roles)
    if not ok then
        return nil, err
    end

    -- Stop roles on shutdown
    if box.ctl.on_shutdown ~= nil then
        box.ctl.on_shutdown(roles.stop)
    end

    if opts.twophase_netbox_call_timeout then
        twophase.set_netbox_call_timeout(opts.twophase_netbox_call_timeout)
    end
    if opts.twophase_upload_config_timeout then
        twophase.set_upload_config_timeout(opts.twophase_upload_config_timeout)
    end
    if opts.twophase_validate_config_timeout then
        twophase.set_validate_config_timeout(opts.twophase_validate_config_timeout)
    end
    if opts.twophase_apply_config_timeout then
        twophase.set_apply_config_timeout(opts.twophase_apply_config_timeout)
    end

    local ok, err = confapplier.init({
        workdir = opts.workdir,
        box_opts = box_opts,
        binary_port = advertise.service,
        advertise_uri = advertise_uri,
        upgrade_schema = opts.upgrade_schema,
        enable_failover_suppressing = opts.enable_failover_suppressing,
        enable_synchro_mode = opts.enable_synchro_mode,
        disable_raft_on_small_clusters = opts.disable_raft_on_small_clusters,

        transport = opts.transport,
        ssl_ciphers = opts.ssl_ciphers,
        ssl_server_ca_file = opts.ssl_server_ca_file,
        ssl_server_cert_file = opts.ssl_server_cert_file,
        ssl_server_key_file = opts.ssl_server_key_file,
        ssl_server_password = opts.ssl_server_password,

        ssl_client_ca_file = opts.ssl_client_ca_file,
        ssl_client_cert_file = opts.ssl_client_cert_file,
        ssl_client_key_file = opts.ssl_client_key_file,
        ssl_client_password = opts.ssl_client_password,
    })
    if not ok then
        return nil, err
    end

    -- Only log boot info if box.cfg wasn't called yet
    -- Otherwise it's logged by confapplier.boot_instance
    if type(box.cfg) == 'function' then
        confapplier.log_bootinfo()
    end

    --[[global]] cartridge_opts = opts
    if rawget(_G, '__TEST') ~= true then
        local crg_opts_to_logs = table.deepcopy(opts)

        local crg_log_whitelist = logging_whitelist.cartridge_opts

        log.info('Cartridge options:')

        for _, option in ipairs(crg_log_whitelist) do
            local opt_value = crg_opts_to_logs[option]
            if type(opt_value) == 'table' then
                log.info('%s = %s', option, json.encode(opt_value))
            else
                log.info('%s = %s', option, opt_value)
            end
        end
    end

    return true
end

_G.cartridge_get_schema = twophase.get_schema
_G.cartridge_set_schema = twophase.set_schema

return {
    VERSION = VERSION,
    _VERSION = VERSION,

    cfg = cfg,

    --- .
    -- @refer cartridge.roles.reload
    -- @function reload_roles
    reload_roles = roles.reload,

    --- .
    -- @refer cartridge.topology.cluster_is_healthy
    -- @function is_healthy
    is_healthy = topology.cluster_is_healthy,

    --- Get cartridge opts.
    -- It's like calling **box.cfg** without arguments, but returns cartridge opts.
    --
    -- @function get_opts
    -- @treturn[1] table Catridge opts
    -- @treturn[2] nil If cartridge opts are not set
    get_opts = function()
        return table.deepcopy(cartridge_opts)
    end,

--- Global functions.
-- @section globals

    --- .
    -- @refer cartridge.twophase.get_schema
    -- @function _G.cartridge_get_schema

    --- .
    -- @refer cartridge.twophase.set_schema
    -- @function _G.cartridge_set_schema

--- Clusterwide DDL schema
-- @refer cartridge.twophase
-- @section schema

    --- Get clusterwide DDL schema.
    -- It's like **\_G.cartridge\_get\_schema**,
    -- but isn't a global variable.
    --
    -- (**Added** in v2.0.1-54)
    -- @function get_schema
    -- @treturn[1] string Schema in YAML format
    -- @treturn[2] nil
    -- @treturn[2] table Error description
    get_schema = _G.cartridge_get_schema,

    --- Apply clusterwide DDL schema.
    -- It's like **\_G.cartridge\_set\_schema**,
    -- but isn't a global variable.
    --
    -- (**Added** in v2.0.1-54)
    -- @function set_schema
    -- @tparam string schema in YAML format
    -- @treturn[1] string The same new schema
    -- @treturn[2] nil
    -- @treturn[2] table Error description
    set_schema = _G.cartridge_set_schema,

--- Cluster administration.
-- @section admin

    --- .
    -- @field .
    -- @refer cartridge.lua-api.get-topology.ServerInfo
    -- @table ServerInfo

    --- .
    -- @field .
    -- @refer cartridge.lua-api.get-topology.ReplicasetInfo
    -- @table ReplicasetInfo

    --- .
    -- @refer cartridge.lua-api.topology.get_servers
    -- @function admin_get_servers
    admin_get_servers = lua_api_topology.get_servers,

    --- .
    -- @refer cartridge.lua-api.topology.get_replicasets
    -- @function admin_get_replicasets
    admin_get_replicasets = lua_api_topology.get_replicasets,

    --- .
    -- @refer cartridge.lua-api.get-topology.get_uris
    -- @function admin_get_uris
    admin_get_uris = lua_api_topology.get_uris,

    --- .
    -- @refer cartridge.lua-api.topology.probe_server
    -- @function admin_probe_server
    admin_probe_server = lua_api_topology.probe_server,

    --- .
    -- @refer cartridge.lua-api.topology.enable_servers
    -- @function admin_enable_servers
    admin_enable_servers = lua_api_topology.enable_servers,

    --- .
    -- @refer cartridge.lua-api.topology.disable_servers
    -- @function admin_disable_servers
    admin_disable_servers = lua_api_topology.disable_servers,

    --- .
    -- @refer cartridge.lua-api.topology.restart_replication
    -- @function admin_restart_replication
    admin_restart_replication = lua_api_topology.restart_replication,

    --- .
    -- @refer cartridge.lua-api.vshard.bootstrap_vshard
    -- @function admin_bootstrap_vshard
    admin_bootstrap_vshard = lua_api_vshard.bootstrap_vshard,


--- Automatic failover management.
-- @section failover

    --- .
    -- @field .
    -- @refer cartridge.lua-api.failover.FailoverParams
    -- @table FailoverParams

    --- .
    -- @refer cartridge.lua-api.failover.get_params
    -- @function failover_get_params
    failover_get_params = lua_api_failover.get_params,
    --- .
    -- @refer cartridge.lua-api.failover.set_params
    -- @function failover_set_params
    failover_set_params = lua_api_failover.set_params,
    --- .
    -- @refer cartridge.lua-api.failover.promote
    -- @function failover_promote
    failover_promote = lua_api_failover.promote,
    --- .
    -- @refer cartridge.lua-api.failover.get_failover_enabled
    -- @function admin_get_failover
    admin_get_failover = lua_api_failover.get_failover_enabled,

    --- Enable failover.
    -- (**Deprecated** since v2.0.1-95 in favor of
    -- `cartridge.failover_set_params`)
    -- @function admin_enable_failover
    admin_enable_failover = function()
        return lua_api_failover.set_failover_enabled(true)
    end,

    --- Disable failover.
    -- (**Deprecated** since v2.0.1-95 in favor of
    -- `cartridge.failover_set_params`)
    -- @function admin_disable_failover
    admin_disable_failover = function()
        return lua_api_failover.set_failover_enabled(false)
    end,

--- Managing cluster topology.
-- @section topology

    --- .
    -- @refer cartridge.lua-api.edit-topology.edit_topology
    -- @function admin_edit_topology
    admin_edit_topology = lua_api_topology.edit_topology,

    --- .
    -- @field .
    -- @refer cartridge.lua-api.edit-topology.EditReplicasetParams
    -- @table EditReplicasetParams

    --- .
    -- @field .
    -- @refer cartridge.lua-api.edit-topology.EditServerParams
    -- @table EditServerParams

    --- .
    -- @field .
    -- @refer cartridge.lua-api.edit-topology.JoinServerParams
    -- @table JoinServerParams

--- Clusterwide configuration.
-- @refer cartridge.confapplier
-- @section confapplier

    --- .
    -- @refer cartridge.confapplier.get_readonly
    -- @function config_get_readonly
    config_get_readonly = confapplier.get_readonly,

    --- .
    -- @refer cartridge.confapplier.get_deepcopy
    -- @function config_get_deepcopy
    config_get_deepcopy = confapplier.get_deepcopy,

    --- .
    -- @refer cartridge.twophase.patch_clusterwide
    -- @function config_patch_clusterwide
    config_patch_clusterwide = twophase.patch_clusterwide,

    --- .
    -- @refer cartridge.twophase.force_reapply
    -- @function config_force_reapply
    config_force_reapply = twophase.force_reapply,

--- Inter-role interaction.
-- @refer cartridge.service-registry
-- @section service_registry

    --- .
    -- @refer cartridge.service-registry.get
    -- @function service_get
    service_get = service_registry.get,

    --- .
    -- @refer cartridge.service-registry.set
    -- @function service_set
    service_set = service_registry.set,

--- Cross-instance calls.
-- @refer cartridge.rpc
-- @section rpc

    --- .
    -- @refer cartridge.rpc.call
    -- @function rpc_call
    rpc_call = rpc.call,

    --- .
    -- @refer cartridge.rpc.get_candidates
    -- @function rpc_get_candidates
    rpc_get_candidates = rpc.get_candidates,

--- Authentication and authorization.
-- @section auth

    --- .
    -- @refer cartridge.auth.authorize_request
    -- @function http_authorize_request
    http_authorize_request = auth.authorize_request,

    --- .
    -- @refer cartridge.auth.render_response
    -- @function http_render_response
    http_render_response = auth.render_response,

    --- .
    -- @refer cartridge.auth.get_session_username
    -- @function http_get_username
    http_get_username = auth.get_session_username,

--- Deprecated functions.
-- @section deprecated

    --- .
    -- @refer cartridge.lua-api.deprecated.edit_replicaset
    -- @function admin_edit_replicaset
    admin_edit_replicaset = lua_api_deprecated.edit_replicaset,

    --- .
    -- @refer cartridge.lua-api.deprecated.edit_server
    -- @function admin_edit_server
    admin_edit_server = lua_api_deprecated.edit_server,

    --- .
    -- @refer cartridge.lua-api.deprecated.join_server
    -- @function admin_join_server
    admin_join_server = lua_api_deprecated.join_server,

    --- .
    -- @refer cartridge.lua-api.deprecated.expel_server
    -- @function admin_expel_server
    admin_expel_server = lua_api_deprecated.expel_server,
}
