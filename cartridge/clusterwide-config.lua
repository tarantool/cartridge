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
local errno = require('errno')
local errors = require('errors')
local uuid = require('uuid')
local log = require('log')

local utils = require('cartridge.utils')

yaml.cfg({
    encode_load_metatables = false,
    decode_save_metatables = false,
})

local LoadConfigError = errors.new_class('LoadConfigError')
local SaveConfigError = errors.new_class('SaveConfigError')
local RemoveConfigError = errors.new_class('RemoveConfigError')

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
            for section_name, content in pairs(self._plaintext) do
                if section_name:match("[^.]+$") == 'yml'
                or section_name:match("[^.]+$") == 'yaml'
                then
                    local ok, data = pcall(yaml.decode, content)
                    if not ok then
                        local err = LoadConfigError:new(
                            'Error parsing section %q: %s',
                            section_name, data
                        )
                        return nil, err
                    end
                    root[section_name] = data
                else
                    root[section_name] = content
                end
            end

            local function _load(tbl)
                local err = nil
                for k, v in pairs(tbl) do
                    if type(v) == 'table' then
                        if v['__file'] then
                            tbl[k] = self._plaintext[v['__file']]
                            if not tbl[k] then
                                return nil, LoadConfigError:new(
                                    'Error loading section %q:' ..
                                    ' inclusion %q not found',
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

    local ok, data = pcall(yaml.decode, raw)
    if not ok then
        local err = LoadConfigError:new(
            'Error parsing %q: %s',
            filename, data
        )
        return nil, err
    elseif data == nil then
        return nil, LoadConfigError:new(
            'Error loading %q: File is empty', filename
        )
    end

    local _plaintext = {}

    -- array of nested config tables
    local to_visit = {}

    -- read all config root data and store it to _plaintext
    for k, v in pairs(data) do
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


--- Atomic remove config folder.
-- @function remove
-- @local
-- @tparam path string
--  Directory path to remove.
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function remove(path)
    local base_name = fio.basename(path)
    local base_path = fio.dirname(path)
    local temp_path = fio.pathjoin(base_path, base_name .. '_' .. uuid.str())

    local ok, err = fio.rename(path, temp_path)
    if not ok then
        return nil, RemoveConfigError:new(
            'Move config to temporary folder failed: %s',
            err
        )
    end

    local _, err = fio.rmtree(temp_path)
    if err ~= nil then
        log.warn(
            "Temporary config folder %q wasn't " ..
            "removed, please make it manually.\n" ..
            "Following error occoured %s",
            temp_path, err
        )
    end

    return true
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

    if fio.path.lexists(path) then
        return nil, SaveConfigError:new(
            "Config can't be saved, directory %q already exists",
            path
        )
    end

    local base_path = fio.dirname(path)
    local base_name = fio.basename(path)
    local temp_path = fio.pathjoin(base_path, base_name .. '_' .. uuid.str())

    local err
    local ok, _err = utils.mktree(temp_path)
    if not ok then
        return nil, SaveConfigError:new(
            "Create temporary config dir %q raised error: %s",
            temp_path, _err.str
        )
    end

    for section_name, section_value in pairs(clusterwide_config._plaintext) do
        local full_path = fio.pathjoin(temp_path, section_name)
        local dirname = fio.dirname(full_path)

        local ok, _err = utils.mktree(dirname)
        if not ok then
            err = SaveConfigError:new(
                "Create config subdirectory %q raised error: %s",
                dirname, _err.str
            )
            goto write_exit
        end

        -- here we work only with strings that stored in our _plaintext
        local ok, _err = utils.file_write(
            full_path, section_value,
            {'O_CREAT', 'O_EXCL', 'O_WRONLY'}
        )
        if not ok then
            err = SaveConfigError:new(
                "Save config section file %q raised error: %s",
                full_path, _err.str
            )
            goto write_exit
        end
    end

::write_exit::
    if err == nil then
        local ok, _err = fio.rename(temp_path, path)
        if not ok then
            err = SaveConfigError:new(
                "Rename config folder %q to %q raised error: %s",
                temp_path, path, _err
            )
        end
    end

    local _ok, _err = fio.rmtree(temp_path)
    if not _ok then
        log.warn(
            "Temporary config folder %q wasn't " ..
            "removed, please make it manually.\n" ..
            "Following error occoured %s",
            temp_path, _err
        )
    end

    if err ~= nil then
        return nil, err
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
        local err = LoadConfigError:new(
            'Error loading %q: %s',
            path, errno.strerror(errno.ENOENT)
        )
        return nil, err
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
    remove = remove,
}
