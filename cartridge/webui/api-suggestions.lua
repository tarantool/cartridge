local module_name = 'cartridge.webui.api-suggestions'

local fun = require('fun')
local issues = require('cartridge.issues')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')
local lua_api_get_topology = require('cartridge.lua-api.get-topology')

local gql_types = require('cartridge.graphql.types')

local refine_uri_suggestion = gql_types.object({
    name = 'RefineUriSuggestion',
    description = 'A suggestion to reconfigure cluster topology',
    fields = {
        uuid = gql_types.string.nonNull,
        uri_old = gql_types.string.nonNull,
        uri_new = gql_types.string.nonNull,
    }
})

local force_apply_suggestion = gql_types.object({
    name = 'ForceApplySuggestion',
    description = 'A suggestion to force apply config on the specified instance',
    fields = {
        uuid = gql_types.string.nonNull,
        reasons = gql_types.list(gql_types.string.nonNull).nonNull
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

local function parse_issues(issues)
    local reasons_list = {}

    for _, issue in ipairs(issues) do
        if issue.topic == 'config_mismatch'
        or issue.topic == 'config_locked' then
            if reasons_list[issue.instance_uuid] == nil then
                reasons_list[issue.instance_uuid] = {}
            end

            if issue.topic == 'config_mismatch' then
                table.insert(
                    reasons_list[issue.instance_uuid],
                    'Configuration checksum mismatch'
                )
            end

            if issue.topic == 'config_locked' then
                table.insert(
                    reasons_list[issue.instance_uuid],
                    'Configuration is prepared and locked'
                )
            end
        end
    end

    local servers = lua_api_get_topology.get_topology().servers
    for uuid, srv in pairs(servers) do
        if srv.message == 'OperationError' then
            if reasons_list[uuid] == nil then
                reasons_list[uuid] = {}
            end

            table.insert(reasons_list[uuid], 'Operation Error')
        end
    end

    local ret = {}
    for uuid, reasons in pairs(reasons_list) do
        table.insert(ret, {
            uuid = uuid,
            reasons = reasons
        })
    end

    if next(ret) == nil then
        return nil
    end

    return ret
end

local function force_apply(_, _, info)
    local cache = info.context.request_cache
    if cache.issues ~= nil then
        return parse_issues(cache.issues)
    end

    cache.issues = issues.list_on_cluster()
    return parse_issues(cache.issues)
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
