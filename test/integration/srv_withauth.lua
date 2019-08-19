#!/usr/bin/env tarantool

require('strict').on()
_G.is_initialized = function() return false end

if not pcall(require, 'cluster.front-bundle') then
    -- to be loaded in development environment
    package.preload['cluster.front-bundle'] = function()
        return require('webui.build.bundle')
    end
end

local log = require('log')
local errors = require('errors')
local cluster = require('cluster')
errors.set_deprecation_handler(function(err)
    log.error('%s', err)
    os.exit(1)
end)

package.preload['auth-mocks'] = function()
    local checks = require('checks')
    local acl = {
        -- [username] = {
        --     username
        --     fullname
        --     shadow
        --     email
        -- },
    }

    local function shadow(password)
        return string.reverse(password) -- much secure, very wow
    end

    local function get_user(username)
        checks('string')
        local user = acl[username]
        if not user then
            return nil, 'User not found'
        end
        return {
            username = user.username,
            fullname = user.fullname,
            email = user.email,
        }
    end

    local function add_user(username, password, fullname, email)
        checks('string', 'string', '?string', '?string')
        local user = acl[username]
        if user ~= nil then
            return nil, 'User already exists'
        end
        acl[username] = {
            username = username,
            fullname = fullname,
            shadow = shadow(password),
            email = email,
        }
        return get_user(username)
    end

    local function edit_user(username, password, fullname, email)
        checks('string', '?string', '?string', '?string')
        local user = acl[username]
        if not user then
            return nil, 'User not found'
        end

        if password ~= nil then
            user.shadow = shadow(password)
        end
        if fullname ~= nil then
            user.fullname = fullname
        end
        if email ~= nil then
            user.email = email
        end

        return get_user(username)
    end

    local function list_users()
        local ret = {}
        for username, _ in pairs(acl) do
            local user = get_user(username)
            table.insert(ret, user)
        end
        return ret
    end

    local function remove_user(username)
        checks('string')
        local user, err = get_user(username)
        if not user then
            return nil, err
        end

        acl[username] = nil
        return user
    end

    local function check_password(username, password)
        checks('string', 'string')
        local user = acl[username]
        if not user then
            return false
        end
        return user.shadow == shadow(password)
    end

    return {
        add_user = add_user,
        get_user = get_user,
        edit_user = edit_user,
        list_users = list_users,
        remove_user = remove_user,
        check_password = check_password,
    }
end

local auth_mocks = require('auth-mocks')
local auth_enabled = false
if os.getenv('ADMIN_PASSWORD') then
    auth_mocks.add_user('admin', os.getenv('ADMIN_PASSWORD'))
    auth_enabled = true
end

local ok, err = cluster.cfg({
    bucket_count = 3000,
    roles = {
        'cluster.roles.vshard-storage',
        'cluster.roles.vshard-router',
    },
    auth_backend_name = 'auth-mocks',
    auth_enabled = auth_enabled, -- works for bootstrapping from scratch only
})

if not ok then
    log.error('%s', err)
    os.exit(1)
end

_G.is_initialized = cluster.is_healthy
