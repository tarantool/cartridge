local module_name = 'cartridge.webui.api-issues'

local issues = require('cartridge.issues')
local gql_types = require('graphql.types')

local gql_type_warning = gql_types.object({
    name = 'Issue',
    fields = {
        level = gql_types.string.nonNull,
        message = gql_types.string.nonNull,
        replicaset_uuid = gql_types.string,
        instance_uuid = gql_types.string,
        topic = gql_types.string.nonNull,
    }
})

local function get_issues(_, _, info)
    local cache = info.context.request_cache
    if cache.issues ~= nil then
        return cache.issues
    end

    cache.issues, cache.issues_err = issues.list_on_cluster()
    return cache.issues
end

local function init(graphql)
    graphql.add_callback({
        prefix = 'cluster',
        name = 'issues',
        doc = 'List issues in cluster',
        args = {},
        kind = gql_types.list(gql_type_warning.nonNull),
        callback = module_name .. '.get_issues',
    })
end

return {
    init = init,
    get_issues = get_issues,
}
