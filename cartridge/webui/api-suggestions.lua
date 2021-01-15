local module_name = 'cartridge.webui.api-suggestions'

local fun = require('fun')
local membership = require('membership')
local issues = require('cartridge.issues')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')

local gql_types = require('cartridge.graphql.types')

local refine_uri_suggestion = gql_types.object({
    name = 'RefineUriSuggestion',
    description =
        'A suggestion to reconfigure cluster topology because ' ..
        ' one or more servers were restarted with a new advertise uri',
    fields = {
        uuid = gql_types.string.nonNull,
        uri_old = gql_types.string.nonNull,
        uri_new = gql_types.string.nonNull,
    }
})

local force_apply_suggestion = gql_types.object({
    name = 'ForceApplySuggestion',
    description =
        'A suggestion to reapply configuration forcefully.' ..
        ' There may be several reasons to do that:' ..
        ' configuration checksum mismatch (config_mismatch);' ..
        ' the locking of tho-phase commit (config_locked);' ..
        ' an error during previous config update (operation_error).',
    fields = {
        uuid = gql_types.string.nonNull,
        config_locked = gql_types.boolean.nonNull,
        config_mismatch = gql_types.boolean.nonNull,
        operation_error = gql_types.boolean.nonNull,
    }
})

local function refine_uri()
    local topology_cfg = confapplier.get_readonly('topology')
    if topology_cfg == nil then
        return nil
    end

    local ret = {}

    local refined_uri_list = topology.refine_servers_uri(topology_cfg)
    for _, uuid, srv in fun.filter(topology.not_disabled, topology_cfg.servers) do
        if srv.uri ~= refined_uri_list[uuid] then
            table.insert(ret, {
                uuid = uuid,
                uri_old = srv.uri,
                uri_new = refined_uri_list[uuid],
            })
        end
    end

    if next(ret) == nil then
        return nil
    end

    return ret
end

local function force_apply(_, _, info)
    local topology_cfg = confapplier.get_readonly('topology')
    if topology_cfg == nil then
        return nil
    end

    local cache = info.context.request_cache
    if cache.issues == nil then
        cache.issues = issues.list_on_cluster()
    end

    local reasons_map = {}

    for _, issue in ipairs(cache.issues) do
        local uuid = issue.instance_uuid

        if issue.topic == 'config_mismatch'
        or issue.topic == 'config_locked'
        then
            reasons_map[uuid] = reasons_map[uuid] or {}
            reasons_map[uuid][issue.topic] = true
        end
    end

    local refined_uri_list = topology.refine_servers_uri(topology_cfg)
    for _, uuid, _ in fun.filter(topology.not_disabled, topology_cfg.servers) do
        local member = membership.get_member(refined_uri_list[uuid])

        if member ~= nil
        and (member.status == 'alive' or member.status == 'suspect')
        and member.payload.state == 'OperationError'
        then
            reasons_map[uuid] = reasons_map[uuid] or {}
            reasons_map[uuid]['operation_error'] = true
        end
    end

    local ret = {}
    for uuid, reasons in pairs(reasons_map) do
        table.insert(ret, {
            uuid = uuid,
            config_locked = reasons.config_locked or false,
            config_mismatch = reasons.config_mismatch or false,
            operation_error = reasons.operation_error or false,
        })
    end

    if next(ret) == nil then
        return nil
    end

    return ret
end

local function get_suggestions(_, _, info)
    return {
        refine_uri = refine_uri(),
        force_apply = force_apply(nil, nil, info),
    }
end

local function init(graphql)
    graphql.add_callback({
        prefix = 'cluster',
        name = 'suggestions',
        doc = 'Show suggestions to resolve operation problems',
        args = {},
        kind = gql_types.object({
            name = 'Suggestions',
            fields = {
                refine_uri = gql_types.list(refine_uri_suggestion.nonNull),
                force_apply = gql_types.list(force_apply_suggestion.nonNull),
            }
        }),
        callback = module_name .. '.get_suggestions',
    })
end

return {
    init = init,
    get_suggestions = get_suggestions,
}
