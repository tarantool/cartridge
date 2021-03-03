--- Spread the data across instances in a network-efficient manner.
--
-- (**Added** in v2.4.0-43)
--
-- @module cartridge.upload
-- @local

local log = require('log')
local fio = require('fio')
local fun = require('fun')
local errno = require('errno')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local digest = require('digest')
local msgpack = require('msgpack')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')

local vars = require('cartridge.vars').new('cartridge.upload')

local UploadError = errors.new_class('UploadError')

--- The uploaded data.
-- `{[upload_id] = data}`
-- @table inbox
vars:new('inbox', {})

-- All four functions begin / transmit / finish / cleanup do yield.
-- Since they are called over netbox (each in an individual fiber),
-- there may be a situation (usually abnormal), when cleanup starts
-- before previous stages finish.
vars:new('upload_fibers', {})

vars:new('options', {
    upload_prefix = '/tmp',
    netbox_call_timeout = 1,
    transmission_timeout = 30,
})

vars:new('get_upload_path', function(upload_id)
    return fio.pathjoin(
        vars.options.upload_prefix,
        'cartridge-upload.' .. upload_id
    )
end)

-- The upload starts by creating a shared resource - a directory named
-- after the `upload_id`. The instances who can create it before
-- others are the transmitters. The others wait patiently till the
-- `upload_finish()`.
local function upload_begin(upload_id)
    checks('string')

    vars.upload_fibers[upload_id] = fiber.self()

    local upload_path = vars.get_upload_path(upload_id)
    local ok, err = utils.mktree(fio.dirname(upload_path))
    fiber.testcancel()
    if ok == nil then
        vars.upload_fibers[upload_id] = nil
        return nil, err
    end

    local ok = fio.mkdir(upload_path)
    local _errno = errno()
    fiber.testcancel()

    vars.upload_fibers[upload_id] = nil

    if ok then
        return true
    elseif fio.path.is_dir(upload_path) then
        return false
    else
        return nil, UploadError:new(
            'Error creating directory %q: %s',
            upload_path, errno.strerror(_errno)
        )
    end
end

-- The communication only goes with transmitters - the instances who
-- replied `upload_begin() == true` i.e affirmed they own the shared
-- resource. The other instances will read the data from that resource
-- during the `upload_finish()` step.
local function upload_transmit(upload_id, payload)
    checks('string', 'string')

    vars.upload_fibers[upload_id] = fiber.self()

    local upload_path = vars.get_upload_path(upload_id)
    local payload_path = fio.pathjoin(upload_path, 'payload')
    local ok, err = utils.file_write(payload_path, payload)
    fiber.testcancel()
    if not ok then
        vars.upload_fibers[upload_id] = nil
        return nil, err
    end

    vars.upload_fibers[upload_id] = nil
    return true
end

-- The uploaded data is read from the shared resource on every instance,
-- not only on the transmitter.
local function upload_finish(upload_id)
    checks('string')

    vars.upload_fibers[upload_id] = fiber.self()

    local upload_path = vars.get_upload_path(upload_id)
    local payload_path = fio.pathjoin(upload_path, 'payload')
    local payload, err = utils.file_read(payload_path)

    vars.upload_fibers[upload_id] = nil

    fiber.testcancel()
    if err then
        return nil, err
    end

    local ok, data = pcall(msgpack.decode, payload)
    if not ok then
        return nil, UploadError:new(data)
    end
    vars.inbox[upload_id] = data
    return true
end

-- Remove shared resources. Be idempotent.
local function upload_cleanup(upload_id)
    checks('string')
    if vars.upload_fibers[upload_id] ~= nil then
        pcall(fiber.cancel, vars.upload_fibers[upload_id])
        vars.upload_fibers[upload_id] = nil
    end

    local upload_path = vars.get_upload_path(upload_id)
    local random_path = utils.randomize_path(upload_path)

    local ok = fio.rename(upload_path, random_path)
    local _errno = errno()
    if not ok then
        if not fio.path.is_dir(upload_path) then
            -- No such file, upload_path is already clean.
            return true
        else
            log.warn(
                'Error removing %s: %s',
                upload_path, errno.strerror(_errno)
            )
            return false
        end
    end

    local ok = fio.rmtree(random_path)
    local _errno = errno()
    if not ok then
        log.warn(
            "Error removing %s: %s",
            random_path, errno.strerror(_errno)
        )
        return false
    end

    return true
end

--- Spread the data across the cluster.
--
-- For each separate upload, a random `upload_id` is generated. All the
-- instances try to create `/tmp/<upload_id>` on their side, and those
-- who succeed act as transmitters.
--
-- When the upload finishes, all the instances load the data into the
-- `inbox` table and the temporary files are cleared. The inbox isn't
-- garbage-collected automatically. It's the user's responsibility to
-- clean it up after use.
--
-- @function upload
--
-- @param data
--   any Lua object.
-- @tparam {string,...} uri_list
--   array of URIs.
--
-- @treturn[1] string `upload_id` (if at least one upload succeded)
-- @treturn[2] nil
-- @treturn[2] table Error description
local function upload(data, uri_list)
    checks('?', 'table')
    local ok, payload = pcall(msgpack.encode, data)
    if not ok then
        return nil, UploadError:new(
            'Error serializing msgpack: %s', payload
        )
    end

    local upload_id = digest.urandom(6):hex()
    local transmitters_list = {}
    local _upload_error

    do -- begin
        local retmap, errmap = pool.map_call(
            '_G.__cartridge_upload_begin', {upload_id},
            {
                uri_list = uri_list,
                timeout = vars.options.netbox_call_timeout,
            }
        )

        for _, uri in ipairs(uri_list) do
            if retmap == nil or retmap[uri] == nil then
                local err = errmap and errmap[uri]
                if err == nil then
                    err = UploadError:new('Unknown error at %s', uri)
                end
                log.error('Error uploading files to %s:\n%s', uri, err)
                _upload_error = err
            elseif retmap[uri] == true then
                table.insert(transmitters_list, uri)
            end
        end

        if _upload_error ~= nil then
            goto cleanup
        end
    end

    do -- transmit
        local retmap, errmap = pool.map_call(
            '_G.__cartridge_upload_transmit', {upload_id, payload},
            {
                uri_list = transmitters_list,
                timeout = vars.options.transmission_timeout,
            }
        )

        for _, uri in ipairs(transmitters_list) do
            if retmap == nil or retmap[uri] == nil then
                local err = errmap and errmap[uri]
                if err == nil then
                    err = UploadError:new('Unknown error at %s', uri)
                end
                log.error('Error transmitting data to %s:\n%s', uri, err)
                _upload_error = err
            end
        end

        if _upload_error ~= nil then
            goto cleanup
        end
    end

    do -- finish
        local retmap, errmap = pool.map_call(
            '_G.__cartridge_upload_finish', {upload_id},
            {
                uri_list = uri_list,
                timeout = vars.options.netbox_call_timeout,
            }
        )

        for _, uri in ipairs(uri_list) do
            if retmap == nil or retmap[uri] == nil then
                log.warn(
                    'Error finishing upload on %s:\n%s',
                    uri, errmap and errmap[uri]
                )
            end
        end
    end

::cleanup::
    do -- cleanup
        local retmap, errmap = pool.map_call(
            '_G.__cartridge_upload_cleanup', {upload_id},
            {
                uri_list = uri_list,
                timeout = vars.options.netbox_call_timeout,
            }
        )

        for _, uri in ipairs(uri_list) do
            if retmap == nil or retmap[uri] == nil then
                log.warn(
                    'Error cleaning up %s:\n%s',
                    uri, errmap and errmap[uri]
                )
            end
        end
    end

    if _upload_error ~= nil then
        return nil, _upload_error
    end

    return upload_id
end

local function set_options(options)
    checks({
        upload_prefix = '?string',
        netbox_call_timeout = '?number',
        transmission_timeout = '?number',
    })
    vars.options = fun.chain(vars.options, options):tomap()
    return true
end

_G.__cartridge_upload_begin = function(...) return errors.pcall('E', upload_begin, ...) end
_G.__cartridge_upload_transmit = function(...) return errors.pcall('E', upload_transmit, ...) end
_G.__cartridge_upload_finish = function(...) return errors.pcall('E', upload_finish, ...) end
_G.__cartridge_upload_cleanup = function(...) return errors.pcall('E', upload_cleanup, ...) end

return {
    inbox = vars.inbox,
    upload = upload,
    set_options = set_options,
}
