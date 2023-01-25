local module_name = 'cartridge.webui.api-failover'

local gql_types = require('graphql.types')
local lua_api_failover = require('cartridge.lua-api.failover')


local gql_type_tarantool_cfg = gql_types.object {
    name = 'FailoverStateProviderCfgTarantool',
    description = 'State provider configuration (Tarantool)',
    fields = {
        uri = gql_types.string.nonNull,
        password = gql_types.string.nonNull,
    }
}

local gql_type_tarantool_cfg_input = gql_types.inputObject {
    name = 'FailoverStateProviderCfgInputTarantool',
    description = 'State provider configuration (Tarantool)',
    fields = {
        uri = gql_types.string.nonNull,
        password = gql_types.string.nonNull,
    }
}

local gql_type_etcd2_cfg = gql_types.object {
    name = 'FailoverStateProviderCfgEtcd2',
    description = 'State provider configuration (etcd-v2)',
    fields = {
        prefix = gql_types.string.nonNull,
        lock_delay = gql_types.float.nonNull,
        endpoints = gql_types.list(gql_types.string.nonNull).nonNull,
        username = gql_types.string.nonNull,
        password = gql_types.string.nonNull,
    }
}

local gql_type_etcd2_cfg_input = gql_types.inputObject {
    name = 'FailoverStateProviderCfgInputEtcd2',
    description = 'State provider configuration (etcd-v2)',
    fields = {
        prefix = gql_types.string,
        lock_delay = gql_types.float,
        endpoints = gql_types.list(gql_types.string.nonNull),
        username = gql_types.string,
        password = gql_types.string,
    }
}

local gql_type_userapi = gql_types.object({
    name = 'FailoverAPI',
    description = 'Failover parameters managent',
    fields = {
        mode = {
            kind = gql_types.string.nonNull,
            description = 'Supported modes are "disabled",' ..
                ' "eventual", "stateful" or "raft".',
        },
        state_provider = {
            kind = gql_types.string,
            description = 'Type of external storage for the stateful' ..
                ' failover mode. Supported types are "tarantool" and' ..
                ' "etcd2".',
        },
        failover_timeout = gql_types.float.nonNull,
        tarantool_params = gql_type_tarantool_cfg,
        etcd2_params = gql_type_etcd2_cfg,
        fencing_enabled = gql_types.boolean.nonNull,
        fencing_timeout = gql_types.float.nonNull,
        fencing_pause = gql_types.float.nonNull,
        leader_autoreturn = gql_types.boolean.nonNull,
        autoreturn_delay = gql_types.float.nonNull,
        check_cookie_hash = gql_types.boolean.nonNull,
    }
})

local function get_failover_params(_, _)
    local failover_params = lua_api_failover.get_params()
    local masked_pwd = '******'
    failover_params.tarantool_params.password = masked_pwd
    failover_params.etcd2_params.password = masked_pwd
    return failover_params
end

local function set_failover_params(_, args)
    local ok, err = lua_api_failover.set_params(args)
    if ok == nil then
        return nil, err
    end

    return get_failover_params()
end

local function get_failover_enabled(_, _)
    return lua_api_failover.get_failover_enabled()
end

local function set_failover_enabled(_, args)
    return lua_api_failover.set_failover_enabled(args.enabled)
end

local function pause()
    return lua_api_failover.pause()
end
local function resume()
    return lua_api_failover.resume()
end

local function promote(_, args)
    local replicaset_uuid = args['replicaset_uuid']
    local instance_uuid = args['instance_uuid']
    local opts = {
        force_inconsistency = args['force_inconsistency'],
        skip_error_on_change = args['skip_error_on_change'],
    }

    return lua_api_failover.promote({[replicaset_uuid] = instance_uuid}, opts)
end

local function init(graphql)

    graphql.add_callback({
        prefix = 'cluster',
        name = 'failover',
        doc = 'Get current failover state.'
            .. ' (Deprecated since v2.0.2-2)',
        args = {},
        kind = gql_types.boolean.nonNull,
        callback = module_name .. '.get_failover_enabled',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'failover',
        doc = 'Enable or disable automatic failover. '
            .. 'Returns new state.'
            .. ' (Deprecated since v2.0.2-2)',
        args = {
            enabled = gql_types.boolean.nonNull,
        },
        kind = gql_types.boolean.nonNull,
        callback = module_name .. '.set_failover_enabled',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'failover_params',
        doc = 'Get automatic failover configuration.',
        args = {},
        kind = gql_type_userapi.nonNull,
        callback = module_name .. '.get_failover_params',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'failover_params',
        doc = 'Configure automatic failover.',
        args = {
            mode = gql_types.string,
            state_provider = gql_types.string,
            failover_timeout = gql_types.float,
            tarantool_params = gql_type_tarantool_cfg_input,
            etcd2_params = gql_type_etcd2_cfg_input,
            fencing_enabled = gql_types.boolean,
            fencing_timeout = gql_types.float,
            fencing_pause = gql_types.float,
            leader_autoreturn = gql_types.boolean,
            autoreturn_delay = gql_types.float,
            check_cookie_hash = gql_types.boolean,
        },
        kind = gql_type_userapi.nonNull,
        callback = module_name .. '.set_failover_params',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'failover_promote',
        doc = 'Promote the instance to the leader of replicaset',
        args = {
            replicaset_uuid = gql_types.string.nonNull,
            instance_uuid = gql_types.string.nonNull,
            force_inconsistency = gql_types.boolean,
            skip_error_on_change = gql_types.boolean,
        },
        kind = gql_types.boolean.nonNull,
        callback = module_name .. '.promote',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'failover_pause',
        doc = 'Pause failover',
        args = {},
        kind = gql_types.boolean.nonNull,
        callback = module_name .. '.pause',
    })
    graphql.add_mutation({
        prefix = 'cluster',
        name = 'failover_resume',
        doc = 'Resume failover after pausing',
        args = {},
        kind = gql_types.boolean.nonNull,
        callback = module_name .. '.resume',
    })
end

return {
    init = init,
    get_failover_enabled = get_failover_enabled,
    set_failover_enabled = set_failover_enabled,
    get_failover_params = get_failover_params,
    set_failover_params = set_failover_params,
    promote = promote,
    pause = pause,
    resume = resume,
}
