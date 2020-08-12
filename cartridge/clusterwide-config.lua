--- The abstraction, representing clusterwide configuration.
--
-- Clusterwide configuration is more than just a lua table. It's an
-- object in terms of OOP paradigm.
--
-- On filesystem clusterwide config is represented by a file tree.
--
-- In Lua it's represented as an object which holds both plaintext files
-- content and unmarshalled lua tables. Unmarshalling is implicit and
-- performed automatically for the sections with `.yml` file extension.
--
-- To access plaintext content there are two functions: `get_plaintext`
-- and `set_plaintext`.
--
-- Unmarshalled lua tables are accessed without `.yml` extension by
-- `get_readonly` and `get_deepcopy`. Plaintext serves for
-- accessing unmarshalled representation of corresponding sections.
--
-- To avoid ambiguity it's prohibited to keep both `<FILENAME>` and
-- `<FILENAME>.yml` in the configuration. An attempt to do so would
-- result in `return nil, err` from `new()` and `load()`, and an attempt
-- to call `get_readonly/deepcopy` would raise an error.
-- Nevertheless one can keep any other extensions because they aren't
-- unmarshalled implicitly.
--
-- (**Added** in v1.2.0-17)
--
-- @usage
-- tarantool> cfg = ClusterwideConfig.new({
--          >     -- two files
--          >     ['forex.yml'] = '{EURRUB_TOM: 70.33, USDRUB_TOM: 63.18}',
--          >     ['text'] = 'Lorem ipsum dolor sit amet',
--          > })
-- ---
-- ...
--
-- tarantool> cfg:get_plaintext()
-- ---
-- - text: Lorem ipsum dolor sit amet
--   forex.yml: '{EURRUB_TOM: 70.33, USDRUB_TOM: 63.18}'
-- ...
--
-- tarantool> cfg:get_readonly()
-- ---
-- - forex.yml: '{EURRUB_TOM: 70.33, USDRUB_TOM: 63.18}'
--   forex:
--     EURRUB_TOM: 70.33
--     USDRUB_TOM: 63.18
--   text: Lorem ipsum dolor sit amet
-- ...
--
-- @module cartridge.clusterwide-config
-- @local

local log = require('log')
local fio = require('fio')
local yaml = require('yaml').new()
local checks = require('checks')
local digest = require('digest')
local errno = require('errno')
local errors = require('errors')

local utils = require('cartridge.utils')

yaml.cfg({
    encode_load_metatables = false,
    decode_save_metatables = false,
})

local LoadConfigError = errors.new_class('LoadConfigError')
local SaveConfigError = errors.new_class('SaveConfigError')
local RemoveConfigError = errors.new_class('RemoveConfigError')

local function generate_checksum(clusterwide_config)
    checks('ClusterwideConfig')

    local keys = {}
    for section, _ in pairs(clusterwide_config._plaintext) do
        table.insert(keys, section)
    end
    table.sort(keys)

    local checksum = digest.crc32.new()
    for _, section in ipairs(keys) do
        checksum:update(string.format('[%s] = ', section))
        checksum:update(clusterwide_config._plaintext[section])
    end

    rawset(clusterwide_config, '_checksum', checksum:result())
    return clusterwide_config
end

local function update_luatables(clusterwide_config)
    checks('ClusterwideConfig')

    local root = {}
    for section, content in pairs(clusterwide_config._plaintext) do
        root[section] = content
        if clusterwide_config._plaintext[section .. '.yml'] ~= nil then
            local err = LoadConfigError:new(
                'Ambiguous sections %q and %q',
                section, section .. '.yml'
            )
            return nil, err
        end

        local fname = string.match(section, "^(.+)%.yml$")
        if not fname or fio.basename(fname) == '' then
            goto continue
        end

        local ok, data = pcall(yaml.decode, content)
        if not ok then
            local err = LoadConfigError:new(
                'Error parsing section %q: %s',
                section, data
            )
            return nil, err
        end
        root[fname] = data

        ::continue::
    end

    local function _load(tbl)
        local err = nil
        for k, v in pairs(tbl) do
            if type(v) ~= 'table' then
                goto continue
            end

            if v['__file'] then
                tbl[k] = clusterwide_config._plaintext[v['__file']]
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
            ::continue::
        end
        return tbl, err
    end

    local new_luatables, err = _load(root)
    if err ~= nil then
        return nil, err
    end

    utils.table_setro(new_luatables)
    rawset(clusterwide_config, '_luatables', new_luatables)
    return clusterwide_config
end

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

            if self.locked then
                error("ClusterwideConfig is locked", 2)
            end

            if content == box.NULL then
                content = nil
            end

            rawset(self._plaintext, section_name, content)

            rawset(self, '_checksum', nil)
            rawset(self, '_luatables', nil)
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

        get_checksum = function(self)
            checks('ClusterwideConfig')
            assert(self._plaintext ~= nil)

            if self._checksum == nil then
                self:generate_checksum()
            end

            return self._checksum
        end,

        update_luatables = update_luatables,
        generate_checksum = generate_checksum,
    }
}

--- Create new object.
-- @function new
-- @tparam[opt] {string=string,...} data
--   Plaintext content
-- @treturn[1] ClusterwideConfig
-- @treturn[2] nil
-- @treturn[2] table Error description
local function new(data)
    checks('?table')
    if data == nil then
        data = {}
    end

    for k, v in pairs(data) do
        if type(k) ~= 'string' then
            local err = "bad argument #1 to new" ..
                " (table keys must be strings)"
            error(err, 2)
        elseif type(v) ~= 'string' then
            local err = "bad argument #1 to new" ..
                " (table values must be strings)"
            error(err, 2)
        end

    end

    local cfg = setmetatable({
        _plaintext = utils.table_setro(data),
        locked = false
    }, clusterwide_config_mt)

    return cfg:update_luatables()
end

--- Load old-style config from YAML file.
--
-- @function load_from_file
-- @local
-- @tparam string filename
--   Filename to load.
-- @treturn[1] ClusterwideConfig
-- @treturn[2] nil
-- @treturn[2] table Error description
local function load_from_file(filename)
    local raw, err = utils.file_read(filename)
    if not raw then
        return nil, err
    end

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
    for section, content in pairs(data) do
        if type(content) == 'string' then
            _plaintext[section] = content
        else
            _plaintext[section .. '.yml'] = yaml.encode(content)
        end
    end

    local dirname = fio.dirname(filename)
    local function _load(tbl)
        for _, v in pairs(tbl) do
            if type(v) ~= 'table' then
                goto continue
            elseif v['__file'] == nil then
                local ok, err = _load(v)
                if not ok then
                    return nil, err
                end
                goto continue
            end

            _plaintext[v['__file']] = utils.file_read(
                fio.pathjoin(dirname, v['__file'])
            )

            ::continue::
        end
        return true
    end

    local ok, err = _load(data)
    if not ok then
        return nil, err
    end

    return new(_plaintext)
end

--- Load new-style config from a directory.
--
-- @function load_from_dir
-- @local
-- @tparam string path
--   Path to the config.
-- @treturn[1] ClusterwideConfig
-- @treturn[2] nil
-- @treturn[2] table Error description
local function load_from_dir(path)
    local plaintext = {}

    local function _recursive_load(subdir)
        local flist = fio.listdir(fio.pathjoin(path, subdir))
        for _, fname in ipairs(flist) do
            local relpath = fio.pathjoin(subdir, fname)
            local abspath = fio.pathjoin(path, relpath)

            if fio.path.is_dir(abspath) then
                local _, err = _recursive_load(relpath)
                if err ~= nil then
                    return nil, err
                end
            else
                local raw, err = utils.file_read(abspath)
                if not raw then
                    return nil, err
                end

                plaintext[relpath] = raw
            end
        end

        return true
    end

    local ok, err = _recursive_load('')
    if not ok then
        return nil, err
    end

    return new(plaintext)
end

local function randomize(filename)
    local random = digest.urandom(9)
    local suffix = digest.base64_encode(random, {urlsafe = true})
    return filename .. '.' .. suffix
end

--- Remove config from filesystem atomically.
--
-- The atomicity is achieved by splitting it into two phases:
-- 1. Configuration is saved with a random filename in the same directory
-- 2. Temporal filename is renamed to the destination
--
--
-- @function remove
-- @local
-- @tparam path string
--  Directory path to remove.
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function remove(path)
    local random_path = fio.pathjoin(
        fio.dirname(path),
        randomize(fio.basename(path))
    )

    local ok = fio.rename(path, random_path)
    if not ok then
        return nil, RemoveConfigError:new(
            '%s: %s',
            path, errno.strerror()
        )
    end

    local ok, err = fio.rmtree(random_path)
    if not ok then
        log.warn(
            "Error removing %s: %s",
            random_path, err
        )
    end

    return true
end

--- Write configuration to filesystem.
--
-- Write atomicity is achieved by splitting it into two phases:
-- 1. Configuration is saved with a random filename in the same directory
-- 2. Temporal filename is renamed to the destination
--
-- @function save
-- @tparam ClusterwideConfig clusterwide_config
-- @tparam string filename
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function save(clusterwide_config, path)
    checks('ClusterwideConfig', 'string')

    local random_path = fio.pathjoin(
        fio.dirname(path),
        randomize(fio.basename(path))
    )

    local ok, err

    ok, err = utils.mktree(random_path)
    if not ok then
        return nil, err
    end

    for section, content in pairs(clusterwide_config._plaintext) do
        local abspath = fio.pathjoin(random_path, section)
        local dirname = fio.dirname(abspath)

        ok, err = utils.mktree(dirname)
        if not ok then
            goto rollback
        end

        ok, err = utils.file_write(
            abspath, content,
            {'O_CREAT', 'O_EXCL', 'O_WRONLY'}
        )
        if not ok then
            goto rollback
        end
    end

    ok = fio.rename(random_path, path)
    if not ok then
        err = SaveConfigError:new(
            '%s: %s',
            path, errno.strerror()
        )
        goto rollback
    else
        return true
    end

::rollback::
    local ok, _err = fio.rmtree(random_path)
    if not ok then
        log.warn(
            "Error removing %s: %s",
            random_path, _err
        )
    end

    return nil, err
end

--- Load object from filesystem.
--
-- This function handles both old-style single YAML and
-- new-style directory with a file tree.
--
-- @function load
-- @tparam string filename
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

    if fio.path.is_dir(path) then
        return load_from_dir(path)
    else
        return load_from_file(path)
    end

end

return {
    new = new,
    load = load,
    save = save,
    remove = remove,
}
