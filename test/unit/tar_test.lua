#!/usr/bin/env tarantool

local tar = require('cartridge.tar')
local log = require('log')
local fio = require('fio')
local errno = require('errno')
local digest = require('digest')

local t = require('luatest')
local g = t.group()

local fixtures = {
    ["1.tar"] = {
        ['a.txt'] = "It's my content and my rules!",
        ['b.txt'] = "Exactly?!",
        ['a/b.txt'] = "Sure",
        ['a/b/c.txt'] = "Oh, my god!",
        ['c/a/b.txt'] = "I'm your God!!!",
    },
    ["2.tar"] = {
        ['a.txt'] = "",
        ['b.txt'] = "I'm test",
    },
    ["3.tar"] = {
        ['a.txt'] = "I'm test",
        ['b.txt'] = "",
    },
    ["4.tar"] = {
        ['a.txt'] = "",
    },
    ["5.tar"] = {
        ['a.txt'] = "",
        ['b.txt'] = "",
    },
    ["6.tar"] = {
        ['a.txt'] = string.rep('$', 512),
        ['b.txt'] = "I'm test",
    },
    ["7.tar"] = {
        ['a.txt'] = "\0",
    },
    ["8.tar"] = {
        ['a.txt'] = digest.urandom(256),
        ['b.txt'] = digest.urandom(512),
        ['c.txt'] = digest.urandom(10241),
    },
}

local BLOCKSIZE = 512

function g.before_all()
    g.tempdir = fio.tempdir()
end

function g.after_all()
    fio.rmtree(g.tempdir)
end

local function table_keys(tbl)
    local ret = {}
    for k, _ in pairs(tbl) do
        table.insert(ret, k)
    end
    return ret
end

local function tar_execute(opts, tar, filename)
    local cmd = string.format('tar %s %s %s 2>&1', opts, tar, (filename or ''))
    log.info('> %s', cmd)
    local f = io.popen(cmd)
    return f:read('*all'):strip()
end

local function file_write(path, content)
    fio.mktree(fio.dirname(path))
    local f = fio.open(path,
        {'O_WRONLY', 'O_CREAT'}, tonumber(644, 8)
    )
    t.assert(f,                path .. ': ' .. errno.strerror())
    t.assert(f:write(content), path .. ': ' .. errno.strerror())
    t.assert(f:close(),        path .. ': ' .. errno.strerror())
end

function g.test_fixtures_pack()
    for tarname, files in pairs(fixtures) do

        local packed, err = tar.pack(files)
        t.assert_equals(err, nil, tarname .. ': Pack failed')
        local unpacked, err = tar.unpack(packed)
        t.assert_equals(err, nil, tarname .. ': Unpack failed')
        t.assert_equals(unpacked, files, tarname .. ': Repack spoiled')

        local path = fio.pathjoin(g.tempdir, tarname)
        file_write(path, packed)

        t.assert_items_equals(
            string.split(tar_execute('tf', path), '\n'),
            table_keys(files),
            string.format('Unexpected listing for %q', tarname)
        )

        for filename, content in pairs(files) do
            t.assert_equals(
                tar_execute('xOf', path, filename),
                content,
                string.format('Unexpected content in %q %s', tarname, filename)
            )
        end
    end
end

function g.test_fixtures_unpack()
    for tarname, files in pairs(fixtures) do
        local tarpath = fio.pathjoin(g.tempdir, tarname)
        local dirname = tarpath:match('(.+)%.tar')
        fio.mkdir(dirname)
        for filename, content in pairs(files) do
            file_write(fio.pathjoin(dirname, filename), content)
        end

        local cmd = string.format(
            'cd %s; tar cf %s *;',
            dirname, fio.pathjoin(g.tempdir, tarname)
        )
        log.info('> %s', cmd)
        local ret = os.execute(cmd)
        t.assert_equals(ret, 0, tarname .. ': Tar command failed')

        local packed = fio.open(tarpath):read()
        local unpacked, err = tar.unpack(packed)
        t.assert_equals(err, nil)
        t.assert_equals(unpacked, files, tarname .. ': Unexpected content')
    end
end

function g.test_truncated()
    -- Two empty blocks is a valid (and empty) tar file
    local packed, err = tar.pack({})
    t.assert_equals(err, nil)
    t.assert_equals(packed, string.rep('\0', BLOCKSIZE * 2))

    local unpacked, err = tar.unpack(packed)
    t.assert_equals(err, nil)
    t.assert_equals(unpacked, {})

    -- Other ways to truncate files are invalid
    local e_truncated = {
        class_name = 'UnpackTarError',
        err = 'Truncated file',
    }

    local unpacked, err = tar.unpack('')
    t.assert_equals(unpacked, nil)
    t.assert_covers(err, e_truncated)

    local unpacked, err = tar.unpack('\0')
    t.assert_equals(unpacked, nil)
    t.assert_covers(err, e_truncated)

    local unpacked, err = tar.unpack(string.rep('\0', BLOCKSIZE - 1))
    t.assert_equals(unpacked, nil)
    t.assert_covers(err, e_truncated)

    local config = {['a.txt'] = 'Test'}
    local packed, err = tar.pack(config)
    t.assert_equals(err, nil)
    t.assert_equals(#packed, 4 * BLOCKSIZE)

    local unpacked, err = tar.unpack(string.sub(packed, 1, BLOCKSIZE - 1))
    t.assert_equals(unpacked, nil)
    t.assert_covers(err, e_truncated)
    local unpacked, err = tar.unpack(string.sub(packed, 1, BLOCKSIZE))
    t.assert_equals(unpacked, nil)
    t.assert_covers(err, e_truncated)
    local unpacked, err = tar.unpack(string.sub(packed, 1, BLOCKSIZE + 1))
    t.assert_equals(unpacked, nil)
    t.assert_covers(err, e_truncated)
    local unpacked, err = tar.unpack(string.sub(packed, 1, 2 * BLOCKSIZE - 1))
    t.assert_equals(unpacked, nil)
    t.assert_covers(err, e_truncated)

    -- Two last empty blocks may be ommitted by other software
    -- It should be still possible to decode
    local unpacked, err = tar.unpack(string.sub(packed, 1, 2 * BLOCKSIZE))
    t.assert_equals(err, nil)
    t.assert_equals(unpacked, config)
    local unpacked, err = tar.unpack(string.sub(packed, 1, 2 * BLOCKSIZE + 1))
    t.assert_equals(err, nil)
    t.assert_equals(unpacked, config)
end


function g.test_errors()
    local packed, err = tar.pack({[string.rep('a', 101)] = ''})
    t.assert_equals(packed, nil)
    t.assert_covers(err, {
        class_name = 'PackTarError',
        err = 'Filename size is more then 100',
    })

    local unpacked, err = tar.unpack(digest.urandom(BLOCKSIZE))
    t.assert_equals(unpacked, nil)
    t.assert_covers(err, {
        class_name = 'UnpackTarError',
        err = 'Bad format (invalid magic)',
    })

    local config = {['a.txt'] = 'Test'}
    local packed, err = tar.pack(config)
    t.assert_equals(err, nil)
    local unpacked, err = tar.unpack(string.gsub(packed, 'a.txt', 'b.txt'))
    t.assert_equals(unpacked, nil)
    t.assert_covers(err, {
        class_name = 'UnpackTarError',
        err = 'Checksum mismatch',
    })
end
