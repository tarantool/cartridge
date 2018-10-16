#!/usr/bin/env tarantool

local log = require('log')
local fio = require('fio')
local fun = require('fun')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local vshard = require('vshard')
local uuid_lib = require('uuid')
local membership = require('membership')

local utils = require('cluster.utils')
local topology = require('cluster.topology')
local cluster_cookie = require('cluster.cluster-cookie')
-- local migrations = require('cluster.migrations')
local confapplier = require('cluster.confapplier')

local e_init_roles = errors.new_class('initialization error')
local function init_roles(conf)
    local ok, err = e_init_roles:pcall(confapplier.apply, conf)
    if not ok then
        log.error('Config apply failed: %s', err)
        membership.set_payload('error', 'Config apply failed')
    else
        membership.set_payload('ready', true)
    end
    return ok, err
end

local function init_box(box_opts)
    checks('table')

    -- call first box.cfg without listen param
    -- to avoid connecting to instance before user permissions are granted
    local box_opts = table.deepcopy(box_opts)
    local listen = box_opts.listen
    box_opts.listen = nil
    box.cfg(box_opts)

    do
        local username = cluster_cookie.username()
        local password = cluster_cookie.cookie()

        log.info('Making sure user %q exists...', username)
        box.schema.user.create(
            username,
            {
                password = password,
                if_not_exists = true,
            }
        )

        log.info('Setting password for %q...', username)
        box.schema.user.passwd(username, password)

        log.info('Granting universe permissions to %q...', username)
        box.schema.user.grant(
            username,
            'read,write,execute',
            'universe',
            nil,
            { if_not_exists = true }
        )

        log.info('Granting replication permissions to %q...', username)
        box.schema.user.grant(
            username,
            'replication',
            nil, nil, {if_not_exists = true}
        )
    end

    log.info('Start listening on %s...', tostring(listen))
    box.cfg({listen = listen})

    membership.set_payload('uuid', box.info.uuid)

    log.info("Box initialized successfully")
    return true
end


local function bootstrap_from_scratch(boot_opts, box_opts, roles)
    checks({
        workdir = 'string',
        binary_port = 'number',
        instance_uuid = '?uuid_str',
        replicaset_uuid = '?uuid_str',
    }, '?table', '?table')

    if roles == nil then
        roles = {'vshard-router', 'vshard-storage'}
    end
    if boot_opts.instance_uuid == nil then
        boot_opts.instance_uuid = uuid_lib.str()
    end
    if boot_opts.replicaset_uuid == nil then
        boot_opts.replicaset_uuid = uuid_lib.str()
    end

    log.info('\nTrying to bootstrap from scratch...')

    local conf = {
        bucket_count = 30000,
    }

    -- TODO Load conf from file

    do
        conf.servers = conf.servers or {}
        conf.servers[boot_opts.instance_uuid] = {
            uri = membership.myself().uri,
            roles = roles,
            replicaset_uuid = boot_opts.replicaset_uuid,
        }
    end

    -- conf, err = model_ddl.config_save_ddl({}, conf)
    -- if conf == nil then
    --     return nil, err
    -- end

    local instance_uuid, err = confapplier.validate(conf)
    if not instance_uuid then
        return nil, err
    end

    topology.set(conf.servers)
    -- local myself = conf.servers[instance_uuid]
    -- if myself == 'expelled' then
    --     log.error('Instance is expelled. Aborting.')
    --     os.exit(1)
    -- end

    local box_opts = table.deepcopy(box_opts or {})
    box_opts.listen = boot_opts.binary_port
    box_opts.wal_dir = boot_opts.workdir
    box_opts.memtx_dir = boot_opts.workdir
    box_opts.instance_uuid = boot_opts.instance_uuid
    box_opts.replicaset_uuid = boot_opts.replicaset_uuid
    box_opts.replication = {}
    log.info('Bootstrapping box.cfg...')
    -- box.cfg(box_opts)

    init_box(box_opts)
    -- TODO migrations.skip()

    local ok, err = init_roles(conf)
    if not ok then
        return nil, err
    end

    return true
end

local function bootstrap_from_membership(boot_opts, box_opts)
    checks({
        workdir = 'string',
        binary_port = 'number',
    }, '?table')

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

    local instance_uuid, err = confapplier.validate(conf)
    if err then
        membership.set_payload('warning', tostring(err.err or err))
        return false
    end
    local replicaset_uuid = conf.servers[instance_uuid].replicaset_uuid

    membership.set_payload('warning', nil)

    log.info('Config downloaded from membership')
    topology.set(conf.servers)

    local box_opts = table.deepcopy(box_opts or {})
    box_opts.listen = boot_opts.binary_port
    box_opts.wal_dir = boot_opts.workdir
    box_opts.memtx_dir = boot_opts.workdir
    box_opts.instance_uuid = instance_uuid
    box_opts.replicaset_uuid = replicaset_uuid
    box_opts.replication = topology.get_replication_config(replicaset_uuid)
    log.info('Bootstrapping box.cfg...')

    init_box(box_opts)
    -- TODO migrations.skip()

    local ok , err = init_roles(conf)
    if not ok then
        log.error('%s', err)
    end
    return true
end

local function bootstrap_from_snapshot(boot_opts, box_opts)
    checks({
        workdir = 'string',
        binary_port = 'number',
    }, '?table')

    local conf, err = confapplier.restore_from_workdir(opts.workdir)
    if conf == nil then
        return nil, err
    end
    -- TODO check if instance was expelled

    local instance_uuid
    do
        -- 1) workaround for tarantool bug gh-3098
        -- we need to call first box.cfg with replication parameters
        -- in order to generate replication parameter we need
        -- to know instance_uuid
        -- 2) workaround to check if instance was expelled
        -- before calling box.cfg
        local snapshots = fio.glob(boot_opts.workdir..'/*.snap')
        local file = io.open(snapshots[1], "r")
        repeat
            instance_uuid = file:read('*l'):match('^Instance: (.+)$')
        until instance_uuid ~= nil
        file:close()
    end

    local box_opts = table.deepcopy(box_opts or {})
    box_opts.listen = boot_opts.binary_port
    box_opts.wal_dir = boot_opts.workdir
    box_opts.memtx_dir = boot_opts.workdir
    log.info('Bootstrapping box.cfg...')

    membership.set_payload('warning', 'Recovering from snapshot')
    init_box(box_opts)

    -- TODO local ok, err = migrations.run()
    -- if not ok then
    --     membership.set_payload('error', 'Migration failed')
    --     return nil, err
    -- end

    for _, server in pairs(conf.servers) do
        if server ~= 'expelled' then
            membership.add_member(server.uri)
        end
    end

    local remote_conf = nil
    while not remote_conf do
        remote_conf = confapplier.fetch_from_membership()
        if not remote_conf then
            membership.set_payload('warning', 'Configuration is being verified')
            fiber.sleep(1)
        end
    end
    membership.set_payload('warning', nil)

    if remote_conf.servers[box.info.uuid] == 'expelled' then
        log.error('Instance was expelled')
        membership.set_payload('error', 'Instance was expelled')
        return true
    elseif not utils.deepcmp(conf, remote_conf) then
        log.error('Configuration mismatch')
        membership.set_payload('error', 'Configuration mismatch')
        return true
    end

    local myself_uri = membership.myself().uri
    if myself_uri ~= conf.servers[box.info.uuid].uri then
        log.error('Mismatching advertise_uri.' ..
            ' Configured as %q, but running as %q',
            conf.servers[box.info.uuid].uri,
            myself_uri
        )
        membership.set_payload('warning',
            string.format('Mismatching advertise_uri=%q', myself_uri)
        )
        return true
    end

    return init_roles(conf)
end

return {
    from_scratch = bootstrap_from_scratch,
    from_snapshot = bootstrap_from_snapshot,
    from_membership = bootstrap_from_membership,
}
