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
local ConflictConfigError = errors.new_class('ConflictConfigError')
local SectionNotFoundError = errors.new_class('SectionNotFoundError')

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
            local _plaintext = table.deepcopy(self._plaintext)
            return setmetatable({
                _plaintext = utils.table_setro(_plaintext),
                locked = false,
            }, clusterwide_config_mt)
        end,

        set_plaintext = function(self, section_name, content)
            checks('ClusterwideConfig', 'string', '?string')

            if self.locked == true then
                error("ClusterwideConfig is locked", 2)
            end

            rawset(self, '_luatables', nil)

            if content == box.NULL then
                content = nil
            end

            rawset(self._plaintext, section_name, content)
            return self
        end,

        update_luatables = function(self)
            checks('ClusterwideConfig')

            local root = {}
            for section_name, section_value in pairs(self._plaintext) do
                local data = section_value
                if section_name:match("[^.]+$") == 'yml'
                or section_name:match("[^.]+$") == 'yaml'
                then
                    local ok, _data = pcall(yaml.decode, section_value)
                    if not ok then
                        return nil, DecodeYamlError:new(
                            'Parsing %s raised error: %s',
                            section_name, _data
                        )
                    end
                    data = _data
                end
                root[section_name] = data
            end

            local function _load(tbl)
                local err = nil
                for k, v in pairs(tbl) do
                    if type(v) == 'table' then
                        if v['__file'] then
                            tbl[k] = self._plaintext[v['__file']]
                            if not tbl[k] then
                                return nil, SectionNotFoundError:new(
                                    'Error while parsing data, in section %q' ..
                                    ' directive %q not found, please check that file exists',
                                    k, v['__file']
                                )
                            end
                        else
                            tbl[k], err = _load(v)
                            if err ~= nil then
                                return nil, err
                            end
                        end
                    end
                end
                return tbl, err
            end

            local new_luatables, err = _load(root)
            if err ~= nil then
                return nil, err
            end

            utils.table_setro(new_luatables)
            rawset(self, '_luatables', new_luatables)
            return self
        end,

        get_plaintext = function(self, section_name)
            checks('ClusterwideConfig', '?string')
            assert(self._plaintext ~= nil)

            if section_name == nil then
                return self._plaintext
            else
                return self._plaintext[section_name]
            end
        end,

        get_readonly = function(self, section_name)
            checks('ClusterwideConfig', '?string')
            assert(self._plaintext ~= nil)

            if self._luatables == nil then
                LoadConfigError:assert(self:update_luatables())
            end

            if section_name == nil then
                return self._luatables
            else
                return self._luatables[section_name]
            end
        end,

        get_deepcopy = function(self, section_name)
            checks('ClusterwideConfig', '?string')

            local ret = table.deepcopy(self:get_readonly(section_name))

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

    local cfg = setmetatable({
        _plaintext = utils.table_setro(data),
        locked = false
    }, clusterwide_config_mt)

    return cfg:update_luatables()
end

--- Load object from file.
-- Configuration is a YAML file.
-- @function _load_from_file
-- @local
-- @tparam string filename
--   Filename to load.
-- @treturn[1] ClusterwideConfig
-- @treturn[2] nil
-- @treturn[2] table Error description
local function _load_from_file(filename)
    checks('string')

    local raw, err = utils.file_read(filename)
    if not raw then
        return nil, err
    end

    local confdir = fio.dirname(filename)

    local encoded, err = DecodeYamlError:pcall(yaml.decode, raw)
    if not encoded then
        if not err then
            return nil, LoadConfigError:new('file %q is empty', filename)
        end

        return nil, err
    end

    local _plaintext = {}

    -- array of nested config tables
    local to_visit = {}

    -- read all config root data and store it to _plaintext
    for k, v in pairs(encoded) do
        if type(v) == 'table' then
            table.insert(to_visit, v)
        end

        if type(v) ~= 'string' then
            v = yaml.encode(v)
            k = k .. '.yml'
        end

        _plaintext[k] = v
    end

    -- check nested tables contains __file directive
    -- and add data to plain text if it's exist
    while #to_visit > 0 do
        local current = to_visit[1]
        if current['__file'] then
            local __file = current['__file']
            local raw, _ = utils.file_read(confdir .. '/' .. __file)
            _plaintext[__file] = raw
        else
            for _, v in pairs(current) do
                if type(v) == 'table' then
                    table.insert(to_visit, v)
                end
            end
        end
        table.remove(to_visit, 1)
    end

    return new(_plaintext)
end

--- Write object to filesystem.
-- @function save
-- @local
-- @tparam ClusterwideConfig clusterwide_config
--   ClusterwideConfig object to save.
-- @tparam string filename
--   Destination path.
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function save(clusterwide_config, path)
    checks('ClusterwideConfig', 'string')
    local files_to_remove = {}
    local dirs_to_remove = {}

    if fio.path.lexists(path) then
        return nil, ConflictConfigError:new(
            "Config can't be saved, directory %q already exists",
            path
        )
    end

    local ok, err = utils.mktree(path)
    if not ok then
        return nil, err
    end

    local _err
    for section_name, section_value in pairs(clusterwide_config._plaintext) do
        local full_path = fio.pathjoin(path, section_name)
        local dirname = fio.dirname(full_path)

        local ok, err = utils.mktree(dirname)
        if not ok then
            _err = err
            goto write_exit
        end
        dirs_to_remove[dirname] = true

        -- here we work only with strings that stored in our _plaintext
        local ok, err = utils.file_write(
            full_path, section_value,
            {'O_CREAT', 'O_EXCL', 'O_WRONLY'}
        )
        if not ok then
            _err = err
            goto write_exit
        end
        files_to_remove[full_path] = true
    end

::write_exit::
    if _err ~= nil then
        dirs_to_remove[path] = nil
        for file_path, _ in pairs(files_to_remove) do
            fio.unlink(file_path)
        end

        for dir_path, _ in pairs(dirs_to_remove) do
            utils.rmtree(dir_path)
        end

        return nil, _err
    end

    return true
end


--- Load sections from config directory.
-- Configuration is a file tree.
-- @function _recursive_load
-- @local
-- @tparam string root_path
--   Path of file tree.
-- @tparam string nested_path
--   Current recursion path relative to the root_path.
-- @tparam table sections
--   Config sections.
-- @treturn[1] true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function _recursive_load(root_path, nested_path, sections)
    local current_path = fio.pathjoin(root_path, nested_path)
    local entries = fio.listdir(current_path)

    for _, entry_name in ipairs(entries) do
        local entry_fullpath = fio.pathjoin(current_path, entry_name)
        local entry_relative_path = fio.pathjoin(nested_path, entry_name)

        if fio.path.is_dir(entry_fullpath) then
            local _, err = _recursive_load(root_path, entry_relative_path, sections)
            if err ~= nil then
                return nil, err
            end
        else
            local raw, err = utils.file_read(entry_fullpath)
            if not raw then
                return nil, err
            end

            local section_name = entry_relative_path
            sections[section_name] = raw
        end
    end

    return true
end


--- Load object from directory.
-- Configuration is a file tree.
-- @function _load_from_dir
-- @local
-- @tparam string path
--   Path to config entry.
-- @treturn[1] ClusterwideConfig
-- @treturn[2] nil
-- @treturn[2] table Error description
local function _load_from_dir(path)
    local cfg_sections = {}

    local ok, err = _recursive_load(path, '', cfg_sections)
    if not ok then
        return nil, err
    end

    return new(cfg_sections)
end


--- Load object from filesystem.
-- Configuration is a YAML file or a file tree.
-- @function load
-- @local
-- @tparam string path
--   Path to config entry.
-- @treturn[1] ClusterwideConfig
-- @treturn[2] nil
-- @treturn[2] table Error description
local function load(path)
    checks('string')

    if not fio.path.lexists(path) then
        return nil, LoadConfigError:new('entry %q does not exist', path)
    end

    if not fio.path.is_dir(path) then
        return _load_from_file(path)
    end

    return _load_from_dir(path)
end

return {
    new = new,
    load = load,
    save = save,
}
