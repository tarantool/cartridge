#!/usr/bin/env tarantool

require('strict').on()
_G.is_initialized = function() return false end

local log = require('log')
local http = require('http.server')
local cluster = require('cluster')

local ok, err = cluster.init({
    alias = os.getenv('ALIAS'),
    workdir = os.getenv('WORKDIR'),
    advertise_uri = os.getenv('ADVERTISE_URI'),
    cluster_cookie = os.getenv('CLUSTER_COOKIE'),
})

if not ok then
    log.error('%s', err)
    os.exit(1)
end

local http_port = os.getenv('HTTP_PORT')
local httpd = http.new(
    '0.0.0.0', tonumber(http_port),
    { log_requests = false }
)
local ok, err = cluster.webui.init(httpd)

if not ok then
    log.error('%s', err)
    os.exit(1)
end

httpd:start()
log.info('Listening HTTP on 0.0.0.0:%s', http_port)

_G.is_initialized = cluster.is_healthy

-- local listen = os.getenv('TARANTOOL_LISTEN')
-- local workdir = os.getenv('TARANTOOL_WORKDIR') or './tmp'
-- local hostname = os.getenv('TARANTOOL_HOSTNAME') or 'localhost'
-- os.execute('mkdir -p ' .. workdir)
-- box.cfg({
--     memtx_dir = workdir,
--     vinyl_dir = workdir,
--     wal_dir = workdir,
--     vinyl_memory = 0,
--     memtx_memory = 32*1024*1024,
-- })
-- box.once('tarantool-entrypoint', function ()
--     box.schema.user.grant("guest", 'read,write,execute', 'universe', nil, {if_not_exists = true})
--     box.schema.user.grant("guest", 'replication',        nil,        nil, {if_not_exists = true})
-- end)
-- box.cfg({
--     listen = listen,
-- })

-- membership = require('membership')
-- -- tune periods to speed up test
-- opts = require('membership.options')
-- opts.PROTOCOL_PERIOD_SECONDS = 0.4
-- opts.ACK_TIMEOUT_SECONDS = 0.2
-- opts.ANTI_ENTROPY_PERIOD_SECONDS = 1.0
-- opts.SUSPECT_TIMEOUT_SECONDS = 1.0

-- membership.init(hostname, tonumber(listen))
-- _G.is_initialized = true
