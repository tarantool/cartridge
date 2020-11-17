local log = require('log')
local vshard = require('vshard')
local checks = require('checks')

local vars = require('cartridge.vars').new('cartridge.roles.vshard-storage')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local vshard_utils = require('cartridge.vshard-utils')

vars:new('vshard_cfg')
local _G_vhsard_backup

local function apply_config(conf, _)
    checks('table', {is_master = 'boolean'})

    local my_replicaset = conf.topology.replicasets[box.info.cluster.uuid]
    local group_name = my_replicaset.vshard_group or 'default'
    local vshard_cfg = vshard_utils.get_vshard_config(group_name, conf)
    vshard_cfg.weights = nil
    vshard_cfg.zone = nil
    vshard_cfg.listen = box.cfg.listen

    if utils.deepcmp(vshard_cfg, vars.vshard_cfg) then
        -- No reconfiguration required, skip it
        return
    end

    log.info('Reconfiguring vshard.storage...')
    vshard.storage.cfg(vshard_cfg, box.info.uuid)
    vars.vshard_cfg = vshard_cfg
end

local function init()
    _G_vhsard_backup = rawget(_G, 'vshard')
    rawset(_G, 'vshard', vshard)
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
        sharding = {[replicaset_uuid] = {
            replicas = {[instance_uuid] = {
                uri = pool.format_uri(advertise_uri),
                name = advertise_uri,
                master = false,
            }},
        }}
    }, instance_uuid)
    vars.vshard_cfg = nil
    rawset(_G, 'vshard', _G_vhsard_backup)
end

return {
    role_name = 'vshard-storage',
    apply_config = apply_config,
    init = init,
    stop = stop,
}
