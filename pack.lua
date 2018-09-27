#!/usr/bin/env tarantool
local log = require('log')
local fio = require('fio')

files = {}
local srcdir = arg[1]
local dst_name = arg[2]

if not srcdir or not dst_name then
    error('Usage: pack.lua SOURCE DEST_NAME')
end

local abspath = fio.abspath(srcdir)
assert(fio.stat(abspath), 'Error: can not pack %s: file does not exist')
log.info('-- Scan %s', abspath)

function fpack(relpath)
    local path = fio.pathjoin(abspath, relpath)
    if fio.path.is_dir(path) then
        for _, fname in ipairs(fio.listdir(path)) do
            fpack(fio.pathjoin(relpath, fname))
        end
    else
        log.info('-- Pack %s', relpath)
        local f = io.open(path, "r")
        table.insert(files, string.format([[[%q] = %q]], '/'..relpath, f:read('*a')))
        f:close()
    end
end

fpack('')
log.info('-- Save %s', dst_name)

local function mod()
    return files
end

local mod_str = string.format('return {\n%s\n}', table.concat(files, ',\n'))
log.info('Total: %.0f KiB', (#mod_str)/1024)

local f = assert(io.open(dst_name, "wb"))
assert(f:write(mod_str))
assert(f:close())
os.exit(0)
