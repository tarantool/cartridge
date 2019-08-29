#!/usr/bin/env tarantool

require('strict').on()

if package.setsearchroot ~= nil then
    package.setsearchroot()
else
    -- Workaround for rocks loading in tarantool 1.10
    -- It can be removed in tarantool > 2.2
    -- By default, when you do require('mymodule'), tarantool looks into
    -- the current working directory and whatever is specified in
    -- package.path and package.cpath. If you run your app while in the
    -- root directory of that app, everything goes fine, but if you try to
    -- start your app with "tarantool myapp/init.lua", it will fail to load
    -- its modules, and modules from myapp/.rocks.
    local fio = require('fio')
    local app_dir = fio.abspath(fio.dirname(arg[0]))
    print('App dir set to ' .. app_dir)
    package.path = package.path .. ';' .. app_dir .. '/?.lua'
    package.path = package.path .. ';' .. app_dir .. '/?/init.lua'
    package.path = package.path .. ';' .. app_dir .. '/.rocks/share/tarantool/?.lua'
    package.path = package.path .. ';' .. app_dir .. '/.rocks/share/tarantool/?/init.lua'
    package.cpath = package.cpath .. ';' .. app_dir .. '/?.so'
    package.cpath = package.cpath .. ';' .. app_dir .. '/?.dylib'
    package.cpath = package.cpath .. ';' .. app_dir .. '/.rocks/lib/tarantool/?.so'
    package.cpath = package.cpath .. ';' .. app_dir .. '/.rocks/lib/tarantool/?.dylib'
end

local workdir = (os.getenv('TARANTOOL_WORKDIR') or 'tmp/db')
if os.getenv('ALIAS') then
    workdir = workdir .. '/' .. os.getenv('ALIAS')
end

local bucket_count = os.getenv('TARANTOOL_BUCKET_COUNT') or 30000
local memtx_memory = os.getenv('TARANTOOL_MEMTX_MEMORY')

-- When starting multiple instances of the app from systemd,
-- instance_name will contain the part after the "@". e.g.  for
-- myapp@instance_1, instance_name will contain "instance_1".
-- Then we use the suffix to assign port number, so that
-- advertise_port will be base_advertise_port + suffix
local instance_name = os.getenv('TARANTOOL_INSTANCE_NAME')
local instance_id = instance_name and tonumber(string.match(instance_name, "_(%d+)$"))

local advertise_uri, http_port, binary_port
if instance_id then
    print("Instance name: " .. instance_name)

    local advertise_hostname = os.getenv('TARANTOOL_HOSTNAME') or 'localhost'
    local base_advertise_port = os.getenv('TARANTOOL_BASE_ADVERTISE_PORT') or 3300
    local base_http_port = os.getenv('TARANTOOL_BASE_HTTP_PORT') or 8080

    local advertise_port = base_advertise_port + instance_id
    advertise_uri = string.format('%s:%s', advertise_hostname, advertise_port)
    http_port = base_http_port + instance_id
else
    binary_port = os.getenv('BINARY_PORT') or '3301'
    advertise_uri = os.getenv('TARANTOOL_ADVERTISE_URI') or 'localhost:'..binary_port
    http_port = os.getenv('TARANTOOL_HTTP_PORT') or 8081
end

local cartridge = require('cartridge')
local ok, err = cartridge.cfg({
    alias = instance_name,
    workdir = workdir,
    advertise_uri = advertise_uri,
    bucket_count = bucket_count,
    http_port = http_port,
    roles = {
        'cartridge.roles.vshard-storage',
        'cartridge.roles.vshard-router',
        'app.roles.api',
        'app.roles.storage',
    },
    cluster_cookie = 'cartridge-kv-cluster-cookie',
})

assert(ok, tostring(err))
