local errors = require('errors')

local auth = require('cartridge.auth')
local gql_types = require('cartridge.graphql.types')
local module_name = 'cartridge.webui.api-auth'

local gql_type_user = gql_types.object({
    name = 'User',
    description = 'A single user account information',
    fields = {
        username = gql_types.string.nonNull,
        fullname = gql_types.string,
        email = gql_types.string,
    }
})

local gql_type_userapi = gql_types.object({
    name = 'UserManagementAPI',
    description = 'User managent parameters and available operations',
    fields = {
        enabled = {
            kind = gql_types.boolean.nonNull,
            description = 'Whether authentication is enabled.',
        },
        username = {
            kind = gql_types.string,
            description = 'Active session username.',
        },
        cookie_max_age = {
            kind = gql_types.long.nonNull,
            description = 'Number of seconds until the authentication cookie expires.',
        },
        cookie_renew_age = {
            kind = gql_types.long.nonNull,
            description = "Update provided cookie if it's older then this age.",
        },

        implements_add_user = gql_types.boolean.nonNull,
        implements_get_user = gql_types.boolean.nonNull,
        implements_edit_user = gql_types.boolean.nonNull,
        implements_list_users = gql_types.boolean.nonNull,
        implements_remove_user = gql_types.boolean.nonNull,
        implements_check_password = gql_types.boolean.nonNull,
    }
})

local function add_user(_, args)
    return auth.add_user(args.username, args.password, args.fullname, args.email)
end

local function edit_user(_, args)
    return auth.edit_user(args.username, args.password, args.fullname, args.email)
end

local function users(_, args)
    if args.username ~= nil then
        local user, err = auth.get_user(args.username)

        if user == nil then
            return nil, err
        end

        return {user}
    else
        return auth.list_users()
    end
end

local function remove_user(_, args)
    return auth.remove_user(args.username)
end

local function get_auth_params()
    local callbacks = auth.get_callbacks()
    local params = auth.get_params()

    local username = auth.get_session_username()
    local user = username and auth.get_user(username)
    if user ~= nil and user.fullname ~= nil then
        username = user.fullname
    end
    return {
        username = username,

        enabled = params.enabled,
        cookie_max_age = params.cookie_max_age,
        cookie_renew_age = params.cookie_renew_age,

        implements_add_user = callbacks.add_user ~= nil,
        implements_get_user = callbacks.get_user ~= nil,
        implements_edit_user = callbacks.edit_user ~= nil,
        implements_list_users = callbacks.list_users ~= nil,
        implements_remove_user = callbacks.remove_user ~= nil,
        implements_check_password = true,
    }
end

local e_set_params = errors.new_class('Error setting auth params')
local function set_auth_params(_, args)
    if args.enabled and auth.get_session_username() == nil then
        return nil, e_set_params:new('You must log in to enable authentication')
    end

    local ok, err = auth.set_params(args)
    if not ok then
        return nil, err
    end

    return get_auth_params()
end

local function init(graphql)
    graphql.add_callback({
        prefix = 'cluster',
        name = 'auth_params',
        doc = '',
        args = {},
        kind = gql_type_userapi.nonNull,
        callback = module_name .. '.get_auth_params',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'auth_params',
        doc = '',
        args = {
            enabled = gql_types.boolean,
            cookie_max_age = gql_types.long,
            cookie_renew_age = gql_types.long,
        },
        kind = gql_type_userapi.nonNull,
        callback = module_name .. '.set_auth_params',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'add_user',
        doc = 'Create a new user',
        args = {
            username = gql_types.string.nonNull,
            password = gql_types.string.nonNull,
            fullname = gql_types.string,
            email = gql_types.string,
        },
        kind = gql_type_user,
        callback = module_name .. '.add_user',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'edit_user',
        doc = 'Edit an existing user',
        args = {
            username = gql_types.string.nonNull,
            password = gql_types.string,
            fullname = gql_types.string,
            email = gql_types.string,
        },
        kind = gql_type_user,
        callback = module_name .. '.edit_user',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'users',
        doc = 'List authorized users',
        args = {
            username = gql_types.string,
        },
        kind = gql_types.list(gql_type_user.nonNull),
        callback = module_name .. '.users',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'remove_user',
        doc = 'Remove user',
        args = {
            username = gql_types.string.nonNull,
        },
        kind = gql_type_user,
        callback = module_name .. '.remove_user',
    })
end

return {
    init = init,

    users = users, -- get_user + list_users
    add_user = add_user,
    edit_user = edit_user,
    remove_user = remove_user,

    get_auth_params = get_auth_params,
    set_auth_params = set_auth_params,
}
