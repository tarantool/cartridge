local fiber = require('fiber')
local cartridge = require('cartridge')
local checks = require('checks')
local errors = require('errors')
local uuid = require('uuid')
local digest = require('digest')
local utils = require('cartridge.utils')

local SALT_LENGTH = 16

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

    local user = find_user_by_username(username)
    if user == nil then
        return nil, errors.new('GetUserError', "User not found: '%s'", username)
    end

    return user
end

local function add_user(username, password, fullname, email)
    checks('string', 'string', '?string', '?string')

    if find_user_by_username(username) then
        return nil, errors.new('AddUserError', "User already exists: '%s'", username)
    elseif find_user_by_email(email) then
        return nil, errors.new('AddUserError', "E-mail already in use: '%s'", email)
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

    local user, uid = find_user_by_username(username)
    if user == nil then
        return nil, errors.new('EditUserError', "User not found: '%s'", username)
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

    local users_acl = cartridge.config_get_readonly('users_acl')
    for _, user in pairs(users_acl or {}) do
        table.insert(result, user)
    end

    return result
end

local function remove_user(username)
    checks('string')

    local user, uid = find_user_by_username(username)
    if user == nil then
        return nil, errors.new('RemoveUserError', "User not found: '%s'", username)
    elseif uid == nil then
        return nil, errors.new('RemoveUserError', "Can't remove user '%s'", username)
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
}
