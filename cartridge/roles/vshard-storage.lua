local log = require('log')
local vshard = require('vshard')
local checks = require('checks')

local vars = require('cartridge.vars').new('cartridge.roles.vshard-storage')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local hotreload = require('cartridge.hotreload')
local vshard_utils = require('cartridge.vshard-utils')

hotreload.whitelist_globals({
    "__module_vshard_lua_gc",
    "__module_vshard_router",
    "__module_vshard_storage",
    "__module_vshard_util",
    "future_storage_call_result",
    "gc_bucket_f",
})

vars:new('vshard_cfg')
vars:new('instance_uuid')
vars:new('replicaset_uuid')
local _G_vshard_backup

local function apply_config(conf, _)
    checks('table', {is_master = 'boolean'})

    local my_replicaset = conf.topology.replicasets[vars.replicaset_uuid]
    local group_name = my_replicaset.vshard_group or 'default'
    local vshard_cfg = vshard_utils.get_vshard_config(group_name, conf)
    vshard_cfg.weights = nil
    vshard_cfg.zone = nil
    vshard_cfg.collect_lua_garbage = nil
    vshard_cfg.listen = box.cfg.listen
    vshard_cfg.replication = box.cfg.replication

    if utils.deepcmp(vshard_cfg, vars.vshard_cfg) then
        -- No reconfiguration required, skip it
        return
    end

    log.info('Reconfiguring vshard.storage...')
    vshard.storage.cfg(vshard_cfg, vars.instance_uuid)
    vars.vshard_cfg = vshard_cfg
end

local function init()
    _G_vshard_backup = rawget(_G, 'vshard')
    rawset(_G, 'vshard', vshard)
    local box_info = box.info
    vars.instance_uuid = box_info.uuid
    vars.replicaset_uuid = box_info.cluster.uuid
end

local function on_apply_config(_, state)
    if state == 'RolesConfigured' then
        vshard.storage.enable()
    else
        vshard.storage.disable()
    end
    return true
end

local function stop()
    local confapplier = require('cartridge.confapplier')
    local advertise_uri = confapplier.get_advertise_uri()
    local instance_uuid = confapplier.get_instance_uuid()
    local replicaset_uuid = confapplier.get_replicaset_uuid()

    -- Vshard storage doesnt't have a `stop` function yet,
    -- but we can defuse it by setting fake empty config.
    -- See https://github.com/tarantool/vshard/issues/121
    vshard.storage.cfg({
        listen = box.cfg.listen,
        read_only = box.cfg.read_only,
        replication = box.cfg.replication,
        bucket_count = vars.vshard_cfg.bucket_count,
        sharding = {[replicaset_uuid] = {
            replicas = {[instance_uuid] = {
                uri = pool.format_uri(advertise_uri),
                name = advertise_uri,
                master = false,
            }},
        }}
    }, instance_uuid)

    -- Fake empty config drops all replicas except the current one.
    -- We have to clean it up manually.
    vshard.storage.internal.this_replica:detach_conn()

    vars.vshard_cfg = nil
    rawset(_G, 'vshard', _G_vshard_backup)
    _G_vshard_backup = nil
end

return {
    role_name = 'vshard-storage',
    implies_storage = true,

    apply_config = apply_config,
    on_apply_config = on_apply_config,
    init = init,
    stop = stop,
}
