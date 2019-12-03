#!/usr/bin/env tarantool

--- The abstraction, representing clusterwide configuration.
--
-- (**Added** in v1.2.0-17)
--
-- @module cartridge.clusterwide-config
-- @local

local fio = require('fio')
local yaml = require('yaml').new()
local checks = require('checks')
local errors = require('errors')

local utils = require('cartridge.utils')

yaml.cfg({
    encode_load_metatables = false,
    decode_save_metatables = false,
})

local LoadConfigError = errors.new_class('LoadConfigError')
local DecodeYamlError = errors.new_class('DecodeYamlError')

local clusterwide_config_mt
clusterwide_config_mt = {
    __type = 'ClusterwideConfig',
    __newindex = function()
        error("ClusterwideConfig object is immutable", 2)
    end,
    __index = {
        __type = 'ClusterwideConfig',
        lock = function(self)
            checks('ClusterwideConfig')
            rawset(self, 'locked', true)
            return self
        end,

        copy = function(self)
            checks('ClusterwideConfig')
            local data = table.deepcopy(self.data)
            return setmetatable({
                data = utils.table_setro(data),
                locked = false,
            }, clusterwide_config_mt)
        end,

        set_content = function(self, section_name, content)
            checks('ClusterwideConfig', 'string', '?')
            if self.locked then
                error("ClusterwideConfig is locked", 2)
            end

            if content == box.NULL then
                content = nil
            elseif type(content) == 'table' then
                content = table.deepcopy(content)
                content = utils.table_setro(content)
            end

            rawset(self.data, section_name, content)
            return self
        end,


        get_readonly = function(self, section_name)
            checks('ClusterwideConfig', '?string')
            assert(self.data ~= nil)
            if section_name == nil then
                return self.data
            else
                return self.data[section_name]
            end
        end,

        get_deepcopy = function(self, section_name)
            checks('ClusterwideConfig', '?string')
            assert(self.data ~= nil)

            local ret
            if section_name == nil then
                ret = self.data
            else
                ret = self.data[section_name]
            end

            ret = table.deepcopy(ret)

            if type(ret) == 'table' then
                return utils.table_setrw(ret)
            else
                return ret
            end
        end,
    }
}

--- Create new object.
-- @function new
-- @tparam[opt] table data.
-- @treturn ClusterwideConfig
local function new(data)
    checks('?table')
    if data == nil then
        data = {}
    end

    return setmetatable({
        data = utils.table_setro(data),
        locked = false,
    }, clusterwide_config_mt)
end

--- Load object from filesystem.
-- Configuration is a YAML file.
-- @function load
-- @local
-- @tparam string filename
--   Filename to load.
-- @treturn[1] ClusterwideConfig
-- @treturn[2] nil
-- @treturn[2] table Error description
local function load(filename)
    checks('string')

    if not utils.file_exists(filename) then
        return nil, LoadConfigError:new('file %q does not exist', filename)
    end

    local raw, err = utils.file_read(filename)
    if not raw then
        return nil, err
    end

    local confdir = fio.dirname(filename)

    local root, err = DecodeYamlError:pcall(yaml.decode, raw)
    if not root then
        if not err then
            return nil, LoadConfigError:new('file %q is empty', filename)
        end

        return nil, err
    end

    local function _load(tbl)
        for k, v in pairs(tbl) do
            if type(v) == 'table' then
                local err
                if v['__file'] then
                    tbl[k], err = utils.file_read(confdir .. '/' .. v['__file'])
                else
                    tbl[k], err = _load(v)
                end
                if err then
                    return nil, err
                end
            end
        end
        return tbl
    end

    local data, err = _load(root)
    if data == nil then
        return nil, err
    end

    return new(data)
end

--- Write object to filesystem.
-- @function save
-- @local
-- @tparam ClusterwideConfig clusterwide_config
--   Filename to load.
-- @tparam string filename
--   Destination path.
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function save(clusterwide_config, path)
    checks('ClusterwideConfig', 'string')
    local ok, err = utils.file_write(
        path, yaml.encode(clusterwide_config.data),
        {'O_CREAT', 'O_EXCL', 'O_WRONLY'}
    )
    if not ok then
        return nil, err
    end

    return true
end

return {
    new = new,
    load = load,
    save = save,
}
