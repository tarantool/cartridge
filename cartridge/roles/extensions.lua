#!/usr/bin/env tarantool

local log = require('log')
local vshard = require('vshard')
local checks = require('checks')
local errors = require('errors')

local vars = require('cartridge.vars').new('cartridge.roles.extensions')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local twophase = require('cartridge.twophase')
local confapplier = require('cartridge.confapplier')
local vshard_utils = require('cartridge.vshard-utils')

vars:new('loaded', {
    -- [module_name] = require(module_name),
})

local function get(module_name)
    checks('string')
    return vars.loaded[module_name]
end

local function validate_config()
	return true
end

local function load()

local function apply_config(conf)
    checks('table')

    vars.loaded = {}

    for section, content in pairs(conf) do
    	local filename = section:match('^extensions/(.+)%.lua$')
    	if not filename then
    		goto continue
    	end

    	local mod = loadstring()

    	::continue::
    end

    local functions = conf['extensions/config'].functions
    if functions == nil then
    	functions = {}
    end

    for fname, fconf in pairs(functions) do
    	local z = 1
    end
end

return {
    role_name = 'extensions',
    validate_config = validate_config,
    apply_config = apply_config,

    get = get,
}
