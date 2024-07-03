local log = require('log')

local ok, vshard = pcall(require, 'vshard-ee')
if not ok then
    vshard = require('vshard')
end

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
vars:new('issues', {})
vars:new('enable_alerting', false)
local _G_vshard_backup

local function apply_config(conf, opts)
    checks('table', {is_master = 'boolean'})
    vars.issues = {}

    local my_replicaset = conf.topology.replicasets[vars.replicaset_uuid]
    local group_name = my_replicaset.vshard_group or 'default'
    local vshard_cfg = vshard_utils.get_vshard_config(group_name, conf)
    vshard_cfg.weights = nil
    vshard_cfg.zone = nil
    vshard_cfg.collect_lua_garbage = nil
    vshard_cfg.listen = box.cfg.listen
    vshard_cfg.replication = box.cfg.replication

    if my_replicaset.all_rw and opts.is_master then
        table.insert(vars.issues, {
            level = 'warning',
            topic = 'vshard',
            message = ([[Vshard storages in replicaset %s marked as "all writable". ]] ..
                [[This might not work as expected.]]):format(vars.replicaset_uuid),
        })
    end

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

    local opts, err = require('cartridge.argparse').get_opts({
        add_vshard_storage_alerts_to_issues = 'boolean',
    })
    if err == nil then
        vars.enable_alerting = opts.add_vshard_storage_alerts_to_issues
    end
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

local function get_issues()
    local issues = table.deepcopy(vars.issues)
    if vshard.storage.info == nil or not vars.enable_alerting then
        return issues
    end
    for _, alert in ipairs(vshard.storage.info().alerts) do
        if alert[2] ~= nil then
            table.insert(issues, {
                level = 'warning',
                topic = 'vshard',
                message = alert[2],
            })
        end
    end
    return issues
end

return {
    role_name = 'vshard-storage',
    implies_storage = true,

    apply_config = apply_config,
    on_apply_config = on_apply_config,
    init = init,
    stop = stop,
    get_issues = get_issues,
}
