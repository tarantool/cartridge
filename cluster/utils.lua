#!/usr/bin/env tarantool

local fio = require('fio')
local ffi = require('ffi')
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

local function file_write(path, data)
    local file = fio.open(path, {'O_CREAT', 'O_WRONLY', 'O_TRUNC', 'O_SYNC'}, tonumber(644, 8))
    if file == nil then
        return nil, e_fopen:new('%q %s', path, errno.strerror())
    end

    local res = file:write(data)

    if not res then
        return nil, e_fwrite:new('%q %s', path, errno.strerror())
    end

    file:close()
    return data
end

local function pathjoin(path, ...)
    path = tostring(path)
    if path == nil or path == '' then
        error("Empty path part")
    end
    for i = 1, select('#', ...) do
        if string.match(path, '/$') ~= nil then
            path = string.gsub(path, '/$', '')
        end

        local sp = select(i, ...)
        if sp == nil then
            error("Undefined path part")
        end
        if string.match(sp, '^/') ~= nil then
            sp = string.gsub(sp, '^/', '')
        end
        if sp ~= '' then
            path = path .. '/' .. sp
        end
    end
    if string.match(path, '/$') ~= nil and #path > 1 then
        path = string.gsub(path, '/$', '')
    end

    if path == '' then
        return '/'
    end

    return path
end


return {
	deepcmp = deepcmp,
    table_find = table_find,
    table_count = table_count,

    file_read = file_read,
    file_write = file_write,
    file_exists = file_exists,
    pathjoin = pathjoin,
}