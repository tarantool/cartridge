#!/usr/bin/env tarantool

local checks = require('checks')
local vars = require('cluster.vars').new('cluster')

vars:new('workdir')
vars:new('advertise_uri')

local function init(opts)
	checks({
		workdir = 'string',
		advertise_uri = 'string',
	})

	vars.workdir = opts.workdir
	vars.advertise_uri = opts.advertise_uri
	return true
end

return {
	init = init,
}
