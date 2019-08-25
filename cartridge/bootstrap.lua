#!/usr/bin/env tarantool

local log = require('log')
local fio = require('fio')
local fun = require('fun')
local json = require('json')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local membership = require('membership')

local vars = require('cartridge.vars').new('cartridge')
local auth = require('cartridge.auth')
local utils = require('cartridge.utils')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')
local vshard_utils = require('cartridge.vshard-utils')
local cluster_cookie = require('cartridge.cluster-cookie')

local e_bootstrap = errors.new_class('Bootstrap failed')
local e_conflicting_groups = errors.new_class('Conflicting vshard_groups option')
vars:new('box_opts', nil)
vars:new('boot_opts', nil)


local function set_boot_opts(boot_opts)
    checks({
        workdir = 'string',
        binary_port = 'number',
        bucket_count = '?number',
        vshard_groups = '?table',
    })
    vars.boot_opts = boot_opts
end

local function get_boot_opts()
    return vars.boot_opts
end

local function set_box_opts(box_opts)
    checks('?table')
    vars.box_opts = box_opts
end

local function init_box(box_opts)
    checks('table')

    log.warn('Bootstrapping box.cfg...')
    box.cfg(box_opts)

    do
        local username = cluster_cookie.username()
        local password = cluster_cookie.cookie()

        log.info('Making sure user %q exists...', username)
        if not box.schema.user.exists(username) then
            error(('User %q does not exists'):format(username))
        end

        log.info('Granting replication permissions to %q...', username)
        box.schema.user.grant(
            username,
            'replication',
            nil, nil, {if_not_exists = true}
        )

        log.info('Setting password for user %q ...', username)
        box.schema.user.passwd(username, password)
    end

    membership.set_payload('uuid', box.info.uuid)

    log.info("Box initialized successfully")
    return true
end

local function validate_vshard_groups(conf)
    checks('table')
    local boot_opts = vars.boot_opts

    if (conf.vshard_groups == nil) and (boot_opts.vshard_groups == nil) then
        if (boot_opts.bucket_count ~= nil)
        and (boot_opts.bucket_count ~= conf.vshard.bucket_count)
        then
            log.warn(
                "WARNING: clusterwide config defines bucket_count=%d," ..
                " cluster.cfg value %d is ignored",
                conf.vshard.bucket_count,
                boot_opts.bucket_count
            )
        end
    elseif (conf.vshard_groups == nil) and (boot_opts.vshard_groups ~= nil) then
        return nil, e_conflicting_groups:new(
            "clusterwide config defines no vshard_groups," ..
            " which doesn't match cluster.cfg"
        )
    elseif (conf.vshard_groups ~= nil) and (boot_opts.vshard_groups == nil) then
        return nil, e_conflicting_groups:new(
            "clusterwide config defines vshard_groups=%s," ..
            " which doesn't match cluster.cfg",
            json.encode(fun.zip(conf.vshard_groups):totable())
        )
    elseif (conf.vshard_groups ~= nil) and (boot_opts.vshard_groups ~= nil) then
        for name, conf_vsgroup in pairs(conf.vshard_groups) do
            local boot_vsgroup = boot_opts.vshard_groups[name]
            if boot_vsgroup == nil then
                return nil, e_conflicting_groups:new(
                    "clusterwide config defines vsgroup %q," ..
                    " missing from cluster.cfg", name
                )
            end

            local bucket_count = boot_opts.vshard_groups[name].bucket_count
            if bucket_count == nil then
                bucket_count = boot_opts.bucket_count
            end

            if bucket_count ~= nil
            and bucket_count ~= conf_vsgroup.bucket_count then
                log.warn(
                    "WARNING: clusterwide config sets %s.bucket_count=%d," ..
                    " cluster.cfg value %d is ignored",
                    conf_vsgroup.bucket_count,
                    bucket_count
                )
            end
        end
    end

    return true
end

local function bootstrap_from_scratch(conf)
    checks('table')

    if vars.boot_opts == nil then
        return nil, e_bootstrap:new("Cluster isn't initialized")
    end

    if type(box.cfg) ~= 'function' then
        return nil, e_bootstrap:new('Cluster is already bootstrapped')
    end

    if conf.vshard == nil and conf.vshard_groups == nil then
        local bucket_count = vars.boot_opts.bucket_count or 30000
        local vshard_groups = vars.boot_opts.vshard_groups

        if vshard_groups == nil then
            conf.vshard = {
                bucket_count = bucket_count,
                bootstrapped = false,
            }
        else
            conf.vshard_groups = {}
            for name, params in pairs(vshard_groups) do
                conf.vshard_groups[name] = {
                    bucket_count = params.bucket_count or bucket_count,
                    bootstrapped = false,
                }
            end
        end
    end

    conf.auth = auth.get_params()

    local instance_uuid, replicaset_uuid = topology.get_myself_uuids(conf.topology)
    if instance_uuid == nil then
        local err = e_bootstrap:new("Instance isn't in config")
        membership.set_payload('warning', tostring(err.err or err))
        return nil, err
    end

    local _, err = topology.validate(conf.topology, {})
    if err then
        membership.set_payload('warning', tostring(err.err or err))
        return nil, err
    end

    local ok, err = validate_vshard_groups(conf)
    if not ok then
        membership.set_payload('warning', tostring(err.err or err))
        return nil, err
    end

    local ok, err = vshard_utils.validate_config(conf, {})
    if not ok then
        membership.set_payload('warning', tostring(err.err or err))
        return nil, err
    end

    local _, err = confapplier.prepare_2pc(conf)
    if err then
        membership.set_payload('warning', tostring(err.err or err))
        return nil, err
    end

    log.info('\nTrying to bootstrap from scratch...')
    local box_opts = table.deepcopy(vars.box_opts or {})
    box_opts.listen = vars.boot_opts.binary_port
    box_opts.wal_dir = vars.boot_opts.workdir
    box_opts.memtx_dir = vars.boot_opts.workdir
    box_opts.vinyl_dir = vars.boot_opts.workdir
    box_opts.instance_uuid = instance_uuid
    box_opts.replicaset_uuid = replicaset_uuid
    box_opts.replication = topology.get_replication_config(conf.topology, replicaset_uuid)

    init_box(box_opts)
    -- TODO migrations.skip()

    return confapplier.commit_2pc()
end

local function bootstrap_from_membership()
    local conf = confapplier.fetch_from_membership()

    if type(box.cfg) ~= 'function' then
        -- maybe the instance was bootstrapped
        -- from scratch in another fiber
        -- while we were sleeping or fetching
        return true
    end

    if not conf then
        return false
    end

    local instance_uuid, replicaset_uuid = topology.get_myself_uuids(conf.topology)
    if instance_uuid == nil then
        membership.set_payload('warning', 'Instance is not in config')
        return false
    end

    local _, err = topology.validate(conf.topology, {})
    if err then
        membership.set_payload('warning', tostring(err.err or err))
        return false
    end

    local ok, err = validate_vshard_groups(conf)
    if not ok then
        membership.set_payload('warning', tostring(err.err or err))
        return false
    end

    local ok, err = vshard_utils.validate_config(conf, conf)
    if not ok then
        membership.set_payload('warning', tostring(err.err or err))
        return nil, err
    end

    local _, err = confapplier.prepare_2pc(conf)
    if err then
        membership.set_payload('warning', tostring(err.err or err))
        return false
    end

    membership.set_payload('warning', nil)

    log.info('Config downloaded from membership')

    local box_opts = table.deepcopy(vars.box_opts or {})
    box_opts.listen = vars.boot_opts.binary_port
    box_opts.wal_dir = vars.boot_opts.workdir
    box_opts.memtx_dir = vars.boot_opts.workdir
    box_opts.vinyl_dir = vars.boot_opts.workdir
    box_opts.instance_uuid = instance_uuid
    box_opts.replicaset_uuid = replicaset_uuid
    box_opts.replication = topology.get_replication_config(conf.topology, replicaset_uuid)

    init_box(box_opts)
    -- TODO migrations.skip()

    return confapplier.commit_2pc()
end

local function bootstrap_from_snapshot()
    local instance_uuid
    do
        -- 1) workaround for tarantool bug gh-3098
        -- we need to call first box.cfg with replication parameters
        -- in order to generate replication parameter we need
        -- to know instance_uuid
        -- 2) workaround to check if instance was expelled
        -- before calling box.cfg
        local snapshots = fio.glob(fio.pathjoin(vars.boot_opts.workdir, '*.snap'))
        local file = io.open(snapshots[1], "r")
        repeat
            instance_uuid = file:read('*l'):match('^Instance: (.+)$')
        until instance_uuid ~= nil
        file:close()
    end

    -- unlock config if it was locked by dangling commit_2pc()
    confapplier.abort_2pc()

    local conf, err = confapplier.load_from_file()
    if conf == nil then
        return nil, err
    end

    local ok, err = validate_vshard_groups(conf)
    if not ok then
        return nil, err
    end

    local ok, err = vshard_utils.validate_config(conf, conf)
    if not ok then
        return nil, err
    end

    local ok, err = confapplier.validate_config(conf, conf)
    if not ok then
        return nil, err
    end

    local box_opts = table.deepcopy(vars.box_opts or {})
    box_opts.listen = vars.boot_opts.binary_port
    box_opts.wal_dir = vars.boot_opts.workdir
    box_opts.memtx_dir = vars.boot_opts.workdir
    box_opts.vinyl_dir = vars.boot_opts.workdir

    membership.set_payload('warning', 'Recovering from snapshot')
    init_box(box_opts)

    -- TODO local ok, err = migrations.run()
    -- if not ok then
    --     membership.set_payload('error', 'Migration failed')
    --     return nil, err
    -- end

    for _, server in pairs(conf.topology.servers) do
        if server ~= 'expelled' then
            membership.add_member(server.uri)
        end
    end

    local remote_conf = nil
    while not remote_conf do
        remote_conf = confapplier.fetch_from_membership(conf.topology)
        if not remote_conf then
            membership.set_payload('warning', 'Configuration is being verified')
            fiber.sleep(1)
        end
    end
    membership.set_payload('warning', nil)

    if remote_conf.topology.servers[box.info.uuid] == 'expelled' then
        log.error('Instance was expelled')
        membership.set_payload('error', 'Instance was expelled')
        return true
    elseif not utils.deepcmp(conf, remote_conf) then
        log.error('Configuration mismatch')
        membership.set_payload('error', 'Configuration mismatch')
        return true
    end

    local myself_uri = membership.myself().uri
    if myself_uri ~= conf.topology.servers[box.info.uuid].uri then
        log.error('Mismatching advertise_uri.' ..
            ' Configured as %q, but running as %q',
            conf.topology.servers[box.info.uuid].uri,
            myself_uri
        )
        membership.set_payload('warning',
            string.format('Mismatching advertise_uri=%q', myself_uri)
        )
        return true
    end

    return confapplier.apply_config(conf)
end

return {
    set_box_opts = set_box_opts,
    set_boot_opts = set_boot_opts,
    get_boot_opts = get_boot_opts,

    from_scratch = bootstrap_from_scratch,
    from_snapshot = bootstrap_from_snapshot,
    from_membership = bootstrap_from_membership,
}
