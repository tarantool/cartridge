#!/usr/bin/env tarantool

require('strict').on()
local fio = require('fio')
local log = require('log')
local term = require('term')
local http = require('http.server')
local errors = require('errors')
local console = require('console')
local cluster = require('cluster')

local e_init = errors.new_class('Cluster initialization failed')
local ok, err = e_init:pcall(cluster.init, {
    alias = os.getenv('ALIAS'),
    workdir = os.getenv('WORKDIR') or './dev/output',
    advertise_uri = os.getenv('ADVERTISE_URI') or 'localhost:3301',
}, {
    -- box.cfg arguments
})

if not ok then
    log.error('%s', err)
    os.exit(1)
end

local http_port = os.getenv('HTTP_PORT') or 8080
local httpd = http.new(
    '0.0.0.0', tonumber(http_port),
    { log_requests = false }
)
httpd:start()
local ok, err = cluster.webui.init(httpd)
log.info('Listening HTTP on 0.0.0.0:%s', http_port)

if not ok then
    log.error('%s', err)
    os.exit(1)
end

if term.isatty(io.stdout) then
    _G.cluster = cluster
    console.start()
    os.exit(0)
end

