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
local cluster = require('cluster')

package.preload['mymodule'] = function()
    local state = nil
    local master = nil
    local service_registry = require('cluster.service-registry')
    local httpd = service_registry.get('httpd')
    local validated = false

    if httpd ~= nil then
        httpd:route(
            {
                method = 'GET',
                path = '/custom-get',
                public = true,
            },
            function(req)
                return {
                    status = 200,
                    body = 'GET OK',
                }
            end
        )

        httpd:route(
            {
                method = 'POST',
                path = '/custom-post',
                public = true,
            },
            function(req)
                return {
                    status = 200,
                    body = 'POST OK',
                }
            end
        )
    end

    return {
        role_name = 'myrole',
        dependencies = {'mymodule-dependency'},
        get_state = function() return state end,
        is_master = function() return master end,
        validate_config = function()
            validated = true
            return true
        end,
        init = function(opts)
            assert(opts.is_master ~= nil)
            assert(validated,
                'Config was not validated prior to init()'
            )
            if opts.is_master then
                assert(box.info().ro == false)
            end
            state = 'initialized'
        end,
        apply_config = function(_, opts)
            assert(opts.is_master ~= nil)
            assert(validated,
                'Config was not validated prior to apply_config()'
            )
            if opts.is_master then
                assert(box.info().ro == false)
            end
            master = opts.is_master
            validated = false
        end,
        stop = function()
            state = 'stopped'
            validated = false
        end
    }
end

package.preload['mymodule-dependency'] = function()
    return {
        role_name = 'myrole-dependency',
    }
end

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
    alias = os.getenv('ALIAS'),
    workdir = os.getenv('WORKDIR'),
    advertise_uri = os.getenv('ADVERTISE_URI') or 'localhost:3301',
    cluster_cookie = os.getenv('CLUSTER_COOKIE'),
    bucket_count = 3000,
    http_port = os.getenv('HTTP_PORT') or 8081,
    roles = {
        'cluster.roles.vshard-storage',
        'cluster.roles.vshard-router',
        'mymodule-dependency',
        'mymodule',
    },
    auth_backend_name = 'auth-mocks',
    auth_enabled = auth_enabled, -- works for bootstrapping from scratch only
})

if not ok then
    log.error('%s', err)
    os.exit(1)
end

_G.is_initialized = cluster.is_healthy

function get_uuid()
    -- this function is used in pytest
    -- to check vshard routing
    return box.info().uuid
end
