local fio = require('fio')
local ffi = require('ffi')
local bit = require('bit')
local errno = require('errno')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')

local FcntlError = errors.new_class('FcntlError')
local OpenFileError = errors.new_class('OpenFileError')
local ReadFileError = errors.new_class('ReadFileError')
local WriteFileError = errors.new_class('WriteFileError')


ffi.cdef[[
int getppid(void);
int fcntl (int, int, ...);
]]

local F_GETFD = 1
local F_SETFD = 2
local FD_CLOEXEC = 1

local function deepcmp(got, expected, extra)
    if extra == nil then
        extra = {}
    end

    if type(expected) == "number" or type(got) == "number" then
        extra.got = got
        extra.expected = expected
        if got ~= got and expected ~= expected then
            return true -- nan
        end
        return got == expected
    end

    if ffi.istype('bool', got) then got = (got == 1) end
    if ffi.istype('bool', expected) then expected = (expected == 1) end
    if got == nil and expected == nil then return true end

    if type(got) ~= type(expected) then
        extra.got = type(got)
        extra.expected = type(expected)
        return false
    end

    if type(got) ~= 'table' then
        extra.got = got
        extra.expected = expected
        return got == expected
    end

    local path = extra.path or '/'

    for i, v in pairs(got) do
        extra.path = path .. '/' .. i
        if not deepcmp(v, expected[i], extra) then
            return false
        end
    end

    for i, v in pairs(expected) do
        extra.path = path .. '/' .. i
        if not deepcmp(got[i], v, extra) then
            return false
        end
    end

    extra.path = path

    return true
end

local function table_find(table, value)
    checks("table", "?")

    for k, v in pairs(table) do
        if v == value then
            return k
        end
    end

    return nil
end

local function table_count(table)
    checks("table")

    local cnt = 0
    for _, _ in pairs(table) do
        cnt = cnt + 1
    end
    return cnt
end

local function table_append(to, from)
    for _, item in pairs(from) do
        table.insert(to, item)
    end
    return to
end

local function file_exists(name)
    return fio.stat(name) ~= nil
end

local function mktree(path)
    checks('string')
    path = fio.abspath(path)

    local path = string.gsub(path, '^/', '')
    local dirs = string.split(path, "/")

    local current_dir = "/"
    for _, dir in ipairs(dirs) do
        current_dir = fio.pathjoin(current_dir, dir)
        local stat = fio.stat(current_dir)
        if stat == nil then
            local _, err = fio.mkdir(current_dir)
            local _errno = errno()
            if err ~= nil and not fio.path.is_dir(current_dir) then
                return nil, errors.new('MktreeError',
                    'Error creating directory %q: %s',
                    current_dir, errno.strerror(_errno)
                )
            end
        elseif not stat:is_dir() then
            return nil, errors.new('MktreeError',
                'Error creating directory %q: %s',
                current_dir, errno.strerror(errno.EEXIST)
            )
        end
    end
    return true
end

local function file_read(path)
    local file = fio.open(path)
    if file == nil then
        return nil, OpenFileError:new('%s: %s', path, errno.strerror())
    end
    local buf = {}
    while true do
        local val = file:read(1024)
        if val == nil then
            return nil, ReadFileError:new('%s: %s', path, errno.strerror())
        elseif val == '' then
            break
        end
        table.insert(buf, val)
    end
    file:close()
    return table.concat(buf, '')
end

local function file_write(path, data, opts, perm)
    checks('string', 'string', '?table', '?number')
    opts = opts or {'O_CREAT', 'O_WRONLY', 'O_TRUNC'}
    perm = perm or tonumber(644, 8)
    local file = fio.open(path, opts, perm)
    if file == nil then
        return nil, OpenFileError:new('%s: %s', path, errno.strerror())
    end

    local res = file:write(data)
    if not res then
        local err = WriteFileError:new('%s: %s', path, errno.strerror())
        fio.unlink(path)
        return nil, err
    end

    local res = file:close()
    if not res then
        local err = WriteFileError:new('%s: %s', path, errno.strerror())
        fio.unlink(path)
        return nil, err
    end

    return data
end


local mt_readonly = {
    __newindex = function()
        error('table is read-only', 2)
    end
}

--- Recursively change the table's read-only property.
-- This is achieved by setting or removing a metatable.
-- An attempt to modify the read-only table or any of its children
-- would raise an error: "table is read-only".
-- @function set_readonly
-- @local
-- @tparam table tbl A table to be processed.
-- @tparam boolean ro Desired readonliness.
-- @treturn table The same table `tbl`.
local function set_readonly(tbl, ro)
    for _, v in pairs(tbl) do
        if type(v) == 'table' then
            set_readonly(v, ro)
        end
    end

    if ro then
        setmetatable(tbl, mt_readonly)
    else
        setmetatable(tbl, nil)
    end

    return tbl
end

--- Return true if we run under systemd.
-- systemd detection based on http://unix.stackexchange.com/a/164092
local function under_systemd()
    local rv = os.execute("systemctl 2>/dev/null | grep '\\-\\.mount' " ..
                              "1>/dev/null 2>/dev/null")
    if rv == 0 and ffi.C.getppid() == 1 then
        return true
    end

    return false
end


local function is_email_valid(str)
    if type(str) ~= 'string' then
        return nil, "Expected string"
    end

    local lastAt = str:find("[^%@]+$")
    if lastAt == nil then
        return nil, "Symbol @ not found"
    end
    local localPart = str:sub(1, (lastAt - 2)) -- Returns the substring before '@' symbol
    local domainPart = str:sub(lastAt, #str) -- Returns the substring after '@' symbol
    -- we werent able to split the email properly
    if localPart == nil then
        return nil, "Local name is invalid"
    end

    if domainPart == nil then
        return nil, "Domain is invalid"
    end
    -- local part is maxed at 64 characters
    if #localPart > 64 then
        return nil, "Local name must be less than 64 characters"
    end
    -- domains are maxed at 253 characters
    if #domainPart > 253 then
        return nil, "Domain must be less than 253 characters"
    end
    -- somthing is wrong
    if lastAt >= 65 then
        return nil, "Invalid @ symbol usage"
    end
    -- quotes are only allowed at the beginning of a the local name
    local quotes = localPart:find("[\"]")
    if type(quotes) == 'number' and quotes > 1 then
        return nil, "Invalid usage of quotes"
    end
    -- no @ symbols allowed outside quotes
    if localPart:find("%@+") and quotes == nil then
        return nil, "Invalid @ symbol usage in local part"
    end
    -- no dot found in domain name
    if not domainPart:find("%.") then
        return nil, "No TLD found in domain"
    end
    -- only 1 period in succession allowed
    if domainPart:find("%.%.") then
        return nil, "Too many periods in domain"
    end
    if localPart:find("%.%.") then
        return nil, "Too many periods in local part"
    end
    -- just a general match
    if not str:match('[%w]*[%p]*%@+[%w]*[%.]?[%w]*') then
        return nil, "Email pattern test failed"
    end
    -- all our tests passed, so we are ok
    return true
end

local function http_read_body(req)
    local req_body = req:read()
    local content_type = req.headers['content-type'] or ''
    local multipart, boundary = content_type:match('(multipart/form%-data); boundary=(.+)')
    if multipart ~= 'multipart/form-data' then
        return req_body
    end

    -- RFC 2046 http://www.ietf.org/rfc/rfc2046.txt
    -- 5.1.1.  Common Syntax
    -- The boundary delimiter line is then defined as a line
    -- consisting entirely of two hyphen characters ("-", decimal value 45)
    -- followed by the boundary parameter value from the Content-Type header
    -- field, optional linear whitespace, and a terminating CRLF.
    --
    -- string.match takes a pattern, thus we have to prefix any characters
    -- that have a special meaning with % to escape them.
    -- A list of special characters is ().+-*?[]^$%
    local boundary_line = string.gsub('--'..boundary, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
    local _, form_body = req_body:match(
        boundary_line .. '\r\n' ..
        '(.-\r\n)' .. '\r\n' .. -- headers
        '(.-)' .. '\r\n' .. -- body
        boundary_line
    )
    return form_body
end

--- Wait for box.info.vclock[id] to reach desired LSN.
--
-- @function wait_lsn
-- @local
--
-- @tparam number id
-- @tparam number lsn
-- @tparam number pause
-- @tparam number timeout
-- @treturn boolean true / false
local function wait_lsn(id, lsn, pause, timeout)
    checks('number', 'number', 'number', 'number')
    local deadline = fiber.clock() + timeout

    while true do
        if (box.info.vclock[id] or 0) >= lsn then
            return true
        end

        if fiber.clock() >= deadline then
            return false
        end

        fiber.sleep(pause)
    end
end


-- Set FD_CLOEXEC flag for the given file descriptor.
--
-- See: https://www.gnu.org/software/libc/manual/html_node/Descriptor-Flags.html
--
-- @function
-- @local
--
-- @tparam number fd
--
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function fd_cloexec(fd)
    checks('number')

    local ret = ffi.C.fcntl(fd, F_GETFD)
    if ret < 0 then
        return nil, FcntlError:new(
            "fcntl(F_GETFD) failed: %s", errno.strerror()
        )
    end

    if bit.band(ret, FD_CLOEXEC) ~= 0 then
        -- already ok
        return true
    end

    local flags = ffi.cast('uint64_t', bit.bor(ret, FD_CLOEXEC))
    local ret = ffi.C.fcntl(fd, F_SETFD, flags)
    if ret < 0 then
        return nil, FcntlError:new(
            "fcntl(F_SETFD) failed: %s", errno.strerror()
        )
    end

    return true
end

return {
    deepcmp = deepcmp,
    table_find = table_find,
    table_count = table_count,
    table_append = table_append,

    mktree = mktree,
    file_read = file_read,
    file_write = file_write,
    file_exists = file_exists,

    under_systemd = under_systemd,
    is_email_valid = is_email_valid,

    table_setro = function(tbl)
        checks("table")
        return set_readonly(tbl, true)
    end,
    table_setrw = function(tbl)
        checks("table")
        return set_readonly(tbl, false)
    end,

    http_read_body = http_read_body,

    wait_lsn = wait_lsn,
    fd_cloexec = fd_cloexec,
}
