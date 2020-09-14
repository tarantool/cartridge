local module_name = 'cartridge.webui.api-suggestions'

local fun = require('fun')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')

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

local function get_suggestions()
    return {
        refine_uri = refine_uri(),
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
            }
        }),
        callback = module_name .. '.get_suggestions',
    })
end

return {
    init = init,
    get_suggestions = get_suggestions,
}
