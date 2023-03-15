local t = require('luatest')
local g = t.group()

local fio = require('fio')
local errno = require('errno')
local msgpack = require('msgpack')

local utils = require('cartridge.utils')
local upload = require('cartridge.upload')
local helpers = require('test.helper')

g.before_all(function()
    helpers.box_cfg()
end)

g.before_each(function()
    g.datadir = fio.tempdir()
end)

g.after_each(function()
    os.execute('chmod -R 755 ' .. g.datadir)
    fio.rmtree(g.datadir)
    g.datadir = nil
end)

function g.test_begin()
    local prefix = g.datadir
    upload.set_upload_prefix(prefix)
    t.assert_equals(_G.__cartridge_upload_begin('1'), true)
    t.assert_equals(_G.__cartridge_upload_begin('1'), false)

    -- Upload can create a prefix if it doesn't exist
    local prefix = g.datadir .. '/subdir'
    upload.set_upload_prefix(prefix)
    t.assert_equals(_G.__cartridge_upload_begin('2'), true)

    local prefix = g.datadir .. '/not-a-dir'
    upload.set_upload_prefix(prefix)
    utils.file_write(prefix, '')
    local ok, err = _G.__cartridge_upload_begin('3')
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'MktreeError',
        err = string.format(
            'Error creating directory %q: %s',
            prefix, errno.strerror(errno.EEXIST)
        )
    })

    local prefix = g.datadir
    upload.set_upload_prefix(prefix)
    utils.file_write(upload.get_upload_path('4'), '')
    local ok, err = _G.__cartridge_upload_begin('4')
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'UploadError',
        err = string.format(
            'Error creating directory %q: %s',
            upload.get_upload_path('4'),
            errno.strerror(errno.EEXIST)
        )
    })
end

function g.test_transmit()
    local prefix = g.datadir
    upload.set_upload_prefix(prefix)

    local ok, err = _G.__cartridge_upload_transmit('upload_id', 'data')
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'OpenFileError',
        err = string.format(
            '%s/payload: %s',
            upload.get_upload_path('upload_id'),
            errno.strerror(errno.ENOENT)
        )
    })

    _G.__cartridge_upload_begin('upload_id')
    local ok, err = _G.__cartridge_upload_transmit('upload_id', 'data')
    t.assert_equals({ok, err}, {true, nil})
end

function g.test_finish()
    local prefix = g.datadir
    upload.set_upload_prefix(prefix)

    local ok, err = _G.__cartridge_upload_finish('upload_id')
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'OpenFileError',
        err = string.format(
            '%s/payload: %s',
            upload.get_upload_path('upload_id'),
            errno.strerror(errno.ENOENT)
        )
    })

    _G.__cartridge_upload_begin('upload_id')
    _G.__cartridge_upload_transmit('upload_id', '')

    local ok, err = _G.__cartridge_upload_finish('upload_id')
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'UploadError',
        err = 'msgpack.decode: invalid MsgPack',
    })

    _G.__cartridge_upload_transmit('upload_id', msgpack.encode('data'))

    local ok, err = _G.__cartridge_upload_finish('upload_id')
    t.assert_equals({ok, err}, {true, nil})

    t.assert_equals(upload.inbox['upload_id'], 'data')
end

function g.test_cleanup()
    local prefix = g.datadir .. '/cleanup_failure'
    upload.set_upload_prefix(prefix)

    _G.__cartridge_upload_begin('upload_id')
    _G.__cartridge_upload_transmit('upload_id', '')

    local upload_path = upload.get_upload_path('upload_id')
    local payload_path = fio.pathjoin(upload_path, 'payload')
    t.assert(fio.path.exists(payload_path))

    -- The first attempt fails: can't rename
    fio.chmod(prefix, tonumber('555', 8))

    local f, err = fio.open(helpers.logfile(), {'O_RDWR'})
    t.skip_if(not f, err)
    f:truncate(0)

    _G.__cartridge_upload_cleanup('upload_id')
    t.assert(fio.path.exists(payload_path))

    local mes = f:read(1024)
    local d = ('W> Error removing %s: %s'):format(upload_path,
    errno.strerror(errno.EACCES)):gsub('-', '%%-')
    t.assert(mes:find(d))
    f:close()

    fio.chmod(prefix, tonumber('755', 8))

    -- The second attempt fails: can't rmtree
    fio.chmod(upload_path, tonumber('555', 8))

    local f, err = fio.open(helpers.logfile(), {'O_RDWR'})
    t.skip_if(not f, err)
    f:truncate(0)
    _G.__cartridge_upload_cleanup('upload_id')
    local random_path = prefix .. '/' .. fio.listdir(prefix)[1]

    local mes = f:read(1024)
    local d = ('W> Error removing %s: %s'):format(random_path,
    errno.strerror(errno.EACCES)):gsub('-', '%%-')

    t.assert(mes:find(d))
    f:close()

    fio.rename(random_path, upload_path)

    fio.chmod(upload_path, tonumber('755', 8))

    -- The third attempt succeeds
    _G.__cartridge_upload_cleanup('upload_id')
    t.assert_equals(fio.listdir(prefix), {})
end

function g.test_upload()
    local ok, err = upload.upload(function() end, {uri_list = {}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'UploadError',
        err = "Error serializing msgpack: unsupported Lua type 'function'",
    })

    local ok, err = upload.upload(box.NULL, {uri_list = {}})
    t.assert_not(err)
    t.assert(ok)
end
