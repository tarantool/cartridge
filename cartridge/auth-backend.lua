local fiber = require('fiber')
local cartridge = require('cartridge')
local checks = require('checks')
local errors = require('errors')
local uuid = require('uuid')
local digest = require('digest')
local utils = require('cartridge.utils')

local argparse = require('cartridge.argparse')
local cluster_cookie = require('cartridge.cluster-cookie')

local AddUserError = errors.new_class('AddUserError')
local GetUserError = errors.new_class('GetUserError')
local EditUserError = errors.new_class('EditUserError')
local RemoveUserError = errors.new_class('RemoveUserError')

local SALT_LENGTH = 16

local ADMIN_USER = {
    username = cluster_cookie.username(),
    fullname = 'Cartridge Administrator',
}

local admin_disabled = argparse.get_opts({
    admin_disabled = 'boolean'
}).admin_disabled or false

local function get_admin_username()
    return (not admin_disabled) and ADMIN_USER.username or false
end

local function disable_admin()
    admin_disabled = true
end

local function is_admin_disabled()
    return admin_disabled
end

local function generate_salt(length)
    return digest.base64_encode(
        digest.urandom(length - bit.rshift(length, 2)),
        {nopad=true, nowrap=true}
    ):sub(1, length)
end

local function password_digest(password, salt)
    return digest.sha512_hex(password .. salt)
end

local function create_password(password)
    checks('string')

    local salt = generate_salt(SALT_LENGTH)

    local shadow = password_digest(password, salt)

    return {
        shadow = shadow,
        salt = salt,
        updated = fiber.time64(),
        hash = 'sha512'
    }
end

local function should_password_update(_)
    return true
end

local function update_password(password, password_data)
    if not should_password_update(password_data) then
        return password_data
    end
    return create_password(password)
end

local function find_user_by_username(username)
    checks('string')

    local users_acl = cartridge.config_get_readonly('users_acl')
    if users_acl == nil then
        return nil
    end

    for uid, user in pairs(users_acl) do
        if user.username == username then
            return user, uid
        end
    end
end

local function find_user_by_email(email)
    checks('?string')
    if email == nil then
        return nil
    end

    local users_acl = cartridge.config_get_readonly('users_acl')
    if users_acl == nil then
        return nil
    end

    for uid, user in pairs(users_acl) do
        if user.email ~= nil and user.email:lower() == email:lower() then
            return user, uid
        end
    end
end

local function get_user(username)
    checks('string')

    if get_admin_username() == username then
        return {
            username = ADMIN_USER.username,
            fullname = ADMIN_USER.fullname,
        }
    end

    local user = find_user_by_username(username)
    if user == nil then
        return nil, GetUserError:new("User not found: '%s'", username)
    end

    return user
end

local function add_user(username, password, fullname, email)
    checks('string', 'string', '?string', '?string')

    if get_admin_username() == username then
        return nil, EditUserError:new(
            "add_user() can't override integrated superuser '%s'",
            username
        )
    end

    if find_user_by_username(username) then
        return nil, AddUserError:new("User already exists: '%s'", username)
    elseif find_user_by_email(email) then
        return nil, AddUserError:new("E-mail already in use: '%s'", email)
    end

    if email ~= nil and email:strip() ~= '' then
        local valid, err = utils.is_email_valid(email)
        if not valid then
            return nil, err
        end
    else
        email = nil
    end

    local users_acl = cartridge.config_get_deepcopy('users_acl') or {}

    local uid
    repeat
        uid = uuid.str()
    until users_acl[uid] == nil

    users_acl[uid] = {
        username = username,
        fullname = fullname,
        email = email,
        created_at = fiber.time64(),
        password_data = create_password(password),
        version = 1,
    }

    local ok, err = cartridge.config_patch_clusterwide({users_acl = users_acl})
    if not ok then
        return nil, err
    end

    return users_acl[uid]
end

local function edit_user(username, password, fullname, email)
    checks('string', '?string', '?string', '?string')

    if get_admin_username() == username then
        return nil, EditUserError:new(
            "edit_user() can't change integrated superuser '%s'",
            username
        )
    end

    local user, uid = find_user_by_username(username)
    if user == nil then
        return nil, EditUserError:new("User not found: '%s'", username)
    end

    local users_acl = cartridge.config_get_deepcopy('users_acl')
    user = users_acl[uid]

    if email == nil then -- luacheck: ignore 542
        -- don't edit
    elseif email:strip() == '' then
        user.email = nil
    else
        local valid, err = utils.is_email_valid(email)
        if not valid then
            return nil, err
        end

        local existing_user = find_user_by_email(email)
        if existing_user and existing_user.username ~= user.username then
            return nil, EditUserError:new("E-mail already in use: '%s'", email)
        end

        user.email = email
    end

    if fullname ~= nil then
        user.fullname = fullname
    end

    if password ~= nil then
        user.password_data = update_password(password, user.password_data)
        if user.version == nil then
            user.version = 1
        else
            user.version = user.version + 1
        end
    end

    if uid == nil then
        return user
    end

    local ok, err = cartridge.config_patch_clusterwide({users_acl = users_acl})
    if not ok then
        return nil, err
    end

    return user
end

local function list_users()
    local result = {}

    if get_admin_username() ~= false then
        table.insert(result, {
            username = ADMIN_USER.username,
            fullname = ADMIN_USER.fullname
        })
    end

    local users_acl = cartridge.config_get_readonly('users_acl')
    for _, user in pairs(users_acl or {}) do
        table.insert(result, user)
    end

    return result
end

local function remove_user(username)
    checks('string')

    if get_admin_username() == username then
        return nil, RemoveUserError:new("remove_user() can't delete integrated superuser '%s'", username)
    end

    local user, uid = find_user_by_username(username)
    if user == nil then
        return nil, RemoveUserError:new("User not found: '%s'", username)
    elseif uid == nil then
        return nil, RemoveUserError:new("Can't remove user '%s'", username)
    end

    local users_acl = cartridge.config_get_deepcopy('users_acl')
    users_acl[uid] = nil

    local ok, err = cartridge.config_patch_clusterwide({users_acl = users_acl})
    if not ok then
        return nil, err
    end

    return user
end

local function check_password(username, password)
    checks('string', 'string')

    if get_admin_username() == username then
        return cluster_cookie.cookie() == password
    end

    local user = find_user_by_username(username)
    if user == nil then
        return false
    end

    return user.password_data.shadow == password_digest(
        password, user.password_data.salt)
end


return {
    add_user = add_user,
    get_user = get_user,
    edit_user = edit_user,
    list_users = list_users,
    remove_user = remove_user,
    check_password = check_password,

    custom = {
        disable_admin = disable_admin,
        is_admin_disabled = is_admin_disabled
    }
}
