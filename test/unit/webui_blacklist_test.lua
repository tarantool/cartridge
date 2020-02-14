#!/usr/bin/env tarantool

local fio = require('fio')
local json = require('json')
local http_client = require('http.client')
local cartridge = require('cartridge')
local webui = require('cartridge.webui')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

local t = require('luatest')
local g = t.group()

local client

function g.before_all()
	g.tempdir = fio.tempdir()
	client = http_client.new()

	g.server1 = helpers.Server:new({
        alias = 'svr1',
        workdir = fio.tempdir(),
        command = test_helper.server_command,
        advertise_port = 13301,
        http_port = 8081,
        cluster_cookie = 'test-cluster-cookie',
        instance_uuid = helpers.uuid('a', 'a', 1),
    })
    g.server2 = helpers.Server:new({
    	alias = 'svr2',
        workdir = fio.tempdir(),
        command = test_helper.server_command,
        advertise_port = 13302,
        http_port = 8082,
        cluster_cookie = 'test-cluster-cookie',
        instance_uuid = helpers.uuid('b', 'b', 1),
    })

    --g.server1:start()
    --g.server2:start()
end

function g.after_all()
	--g.server:stop()
	fio.rmtree(g.tempdir)
end

local function cartridge_cfg(webui_blacklist)
	local ok, err = cartridge.cfg({
			workdir = fio.tempdir(),
			http_port = http_port,
			roles = {},
			webui_blacklist = webui_blacklist,
		})
	t.assert(ok, string.format('Cartridge is not configured (%s)', (err and err.err) or ''))
end

local function webui_blacklist_graphql(http_port)
	return json.decode(client:post(
		string.format('http://localhost:%d/admin/api', http_port),
		json.encode({query ='{ webui_blacklist }'})).body)
end

function g.test_cartridge_cfg()
	local a = [=[
	g.server1.net_box:eval([[
		local cartridge = require('cartridge')
		local fio = require('fio')

		return cartridge.cfg({
			workdir = fio.tempdir(),
			http_port = 8081,
			roles = {},
		})
	]])
	t.assert(ok, string.format('Cartridge is not configured (%s)', (err and err.err) or ''))

	local resp = webui_blacklist_graphql(g.server1.http_port)
	t.assert_items_equals(resp['data']['webui_blacklist'], {}, 'Not expected responce')

	g.server2.net_box:eval([[
		local cartridge = require('cartridge')
		local fio = require('fio')

		return cartridge.cfg({
			workdir = fio.tempdir(),
			http_port = 8082,
			roles = {},
			webui_blacklist = {
				'/cluster/code',
				'/cluster/schema',
			},
		})
	]])
	t.assert(ok, string.format('Cartridge is not configured (%s)', (err and err.err) or ''))

	local resp = webui_blacklist_graphql(g.server2.http_port)
	t.assert_items_equals(resp['data']['webui_blacklist'], {
		'/cluster/code',
		'/cluster/schema',
	},
	'Not expected responce')
	]=]
	require('log').info(a)

	local ok, err = cartridge.cfg({
			workdir = fio.tempdir(),
			http_port = 8081,
			roles = {},
			webui_blacklist = {
				'/cluster/code',
				'/cluster/schema',
			},
		})
	local resp = webui_blacklist_graphql(8081)
	t.assert_items_equals(resp['data']['webui_blacklist'], {
		'/cluster/code',
		'/cluster/schema',
	},
	'Not expected responce')
end
