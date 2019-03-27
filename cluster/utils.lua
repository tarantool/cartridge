#!/usr/bin/env tarantool

local fio = require('fio')
local ffi = require('ffi')
local errno = require('errno')
local checks = require('checks')
local errors = require('errors')

local e_fopen = errors.new_class('Can not open file')
local e_fread = errors.new_class('Can not read from file')
local e_fwrite = errors.new_class('Can not write to file')

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

local function file_read(path)
    local file = fio.open(path)
    if file == nil then
        return nil, e_fopen:new('%q %s', path, errno.strerror())
    end
    local buf = {}
    while true do
        local val = file:read(1024)
        if val == nil then
            return nil, e_fread:new('%q %s', path, errno.strerror())
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
        return nil, e_fopen:new('%q %s', path, errno.strerror())
    end

    local res = file:write(data)
    if not res then
        local err = e_fwrite:new('%q %s', path, errno.strerror())
        fio.unlink(path)
        return nil, err
    end

    local res = file:close()
    if not res then
        local err = e_fwrite:new('%q %s', path, errno.strerror())
        fio.unlink(path)
        return nil, err
    end

    return data
end

return {
	deepcmp = deepcmp,
    table_find = table_find,
    table_count = table_count,
    table_append = table_append,

    file_read = file_read,
    file_write = file_write,
    file_exists = file_exists,
}
