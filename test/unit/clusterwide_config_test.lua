#!/usr/bin/env tarantool

local t = require('luatest')
local g = t.group()
local fio = require('fio')
local yaml = require('yaml')
local checks = require('checks')
local errno = require('errno')
local utils = require('cartridge.utils')
local ClusterwideConfig = require('cartridge.clusterwide-config')

g.before_each(function()
    g.tempdir = fio.tempdir()
end)

g.after_each(function()
    fio.rmtree(g.tempdir)
end)

local function table_merge(t1, t2)
    local ret = table.copy(t1)
    for k, v in pairs(t2) do
        ret[k] = v
    end
    return ret
end

local function write_tree(tree)
    checks('table')
    for path, content in pairs(tree) do
        local abspath = fio.pathjoin(g.tempdir, path)
        utils.mktree(fio.dirname(abspath))
        utils.file_write(abspath, content)
    end
end

function g.test_newstyle_ok()
    local files = {
        ['a/b/c/first.txt'] = 'first',
        ['a/b/c/second.yml'] = 'key: value',
        ['table.yml'] = '{a: {b: {c: 4}}}',
        ['table.txt'] = '{a: {b: {c: 5}}}',
        ['include.yml'] = '__file: a/b/c/first.txt',
    }
    write_tree(files)

    local cfg, err = ClusterwideConfig.load(g.tempdir)
    t.assert_equals(err, nil)
    t.assert_equals(cfg:get_plaintext(), files)
    t.assert_equals(cfg:get_readonly(),
        table_merge(files, {
            ['a/b/c/second'] = {key = 'value'},
            ['table'] = {a = {b = {c = 4}}},
            ['include'] = 'first',
        })
    )

end

function g.test_newstyle_err()
    local cfg, err = ClusterwideConfig.load(
        fio.pathjoin(g.tempdir, 'not_existing')
    )
    t.assert_equals(cfg, nil)
    t.assert_covers(err, {
        class_name = 'LoadConfigError',
        err = string.format(
            "Error loading %q: %s",
            fio.pathjoin(g.tempdir, 'not_existing'),
            errno.strerror(errno.ENOENT)
        )
    })

    write_tree({
        ['cfg1/bad.yml'] = ',',
    })
    local cfg, err = ClusterwideConfig.load(g.tempdir .. '/cfg1')
    t.assert_equals(cfg, nil)
    t.assert_covers(err, {
        class_name = 'LoadConfigError',
        err = 'Error parsing section "bad.yml": unexpected END event'
    })

    write_tree({
        ['cfg2/bad.yml'] = '{__file: not_existing.txt}',
    })
    local cfg, err = ClusterwideConfig.load(g.tempdir .. '/cfg2')
    t.assert_equals(cfg, nil)
    t.assert_covers(err, {
        class_name = 'LoadConfigError',
        err =  'Error loading section "bad":' ..
        ' inclusion "not_existing.txt" not found'
    })
end

function g.test_oldstyle_ok()
    local files = {
        ['main.yml'] = [[
            string: "foobar"
            table: {a: {b: {c: 4}}}
            number: 42
            boolean: false
            colors.yml: "---\n{red: '0xff0000'}\n..."
            side_config: {__file: 'inclusion.txt'}
        ]],
        ['inclusion.txt'] = "Hi it's me",
        ['redundant.txt'] = "This is just a junk file",
    }
    write_tree(files)
    local cfg, err = ClusterwideConfig.load(g.tempdir .. '/main.yml')
    if err ~= nil then
        error(err)
    end

    cfg:update_luatables()
    t.assert_equals(cfg._luatables['string'], 'foobar')
    t.assert_equals(cfg._luatables['number'], 42)
    t.assert_equals(cfg._luatables['boolean'], false)
    t.assert_equals(cfg._luatables['colors'], {red = '0xff0000'})
    t.assert_equals(cfg._luatables['side_config'], "Hi it's me")

    t.assert_equals(cfg._luatables['string.yml'], nil)
    t.assert_equals(yaml.decode(cfg._luatables['number.yml']), 42)
    t.assert_equals(yaml.decode(cfg._luatables['boolean.yml']), false)
    t.assert_equals(yaml.decode(cfg._luatables['table.yml']), {a = {b = {c = 4}}})
    t.assert_equals(yaml.decode(cfg._luatables['colors.yml']), {red = '0xff0000'})
    t.assert_equals(yaml.decode(cfg._luatables['side_config.yml']), {__file = 'inclusion.txt'})

    t.assert_equals(cfg._luatables['inclusion.txt'], "Hi it's me")
    t.assert_equals(cfg._luatables['redundant.txt'], nil)

    t.assert_equals(cfg._luatables, cfg:get_readonly())
    t.assert_equals(cfg._luatables, cfg:get_deepcopy())


    t.assert_equals(cfg._plaintext, {
        ['string'] = "foobar",
        ['table.yml'] = yaml.encode({a = {b = {c = 4}}}),
        ['number.yml'] = yaml.encode(42),
        ['boolean.yml'] = yaml.encode(false),
        ['side_config.yml'] = yaml.encode({__file = 'inclusion.txt'}),
        ['inclusion.txt'] = "Hi it's me",
        ['colors.yml'] = "---\n{red: '0xff0000'}\n...",
    })
    t.assert_equals(cfg._plaintext, cfg:get_plaintext())
end

function g.test_oldstyle_err()
    local cfg, err = ClusterwideConfig.load(
        fio.pathjoin(g.tempdir, 'not_existing.yml')
    )
    t.assert_equals(cfg, nil)
    t.assert_covers(err, {
        class_name = 'LoadConfigError',
        err = string.format(
            "Error loading %q: %s",
            fio.pathjoin(g.tempdir, 'not_existing.yml'),
            errno.strerror(errno.ENOENT)
        )
    })

    write_tree({['bad1/main.yml'] = ','})
    local cfg, err = ClusterwideConfig.load(g.tempdir .. '/bad1/main.yml')
    t.assert_equals(cfg, nil)
    t.assert_covers(err, {
        class_name = 'LoadConfigError',
        err = string.format(
            "Error parsing %q: unexpected END event",
            fio.pathjoin(g.tempdir, 'bad1/main.yml'),
            errno.strerror(errno.ENOENT)
        )
    })

    write_tree({['bad2/main.yml'] = [[
        side_config: {__file: 'not_existing.txt'}
    ]]})
    local cfg, err = ClusterwideConfig.load(g.tempdir .. '/bad2/main.yml')
    t.assert_equals(cfg, nil)
    t.assert_covers(err, {
        class_name = 'LoadConfigError',
        err = 'Error loading section "side_config":' ..
        ' inclusion "not_existing.txt" not found'
    })

    write_tree({['config.yml'] = [[---
        local my_var = 123
        ...
    ]]})
    local cfg, err = ClusterwideConfig.load(g.tempdir .. '/config.yml')
    t.assert_equals(cfg, nil)
    t.assert_covers(err, {
        class_name = 'LoadConfigError',
        err = string.format(
            'Error loading %q: Config must be a table',
            fio.pathjoin(g.tempdir, 'config.yml')
        ),
    })
end

function g.test_preserving_plaintext()
    local cfg = ClusterwideConfig.new()
    local data = '{fizz: buzz} #important comment'
    cfg:set_plaintext('data.yml', data)

    t.assert_equals(cfg:get_readonly('data'), {fizz = 'buzz'})
    t.assert_equals(cfg:get_readonly('data.yml'), data)
    t.assert_equals(cfg:get_plaintext('data.yml'), data)
end


function g.test_delete_plaintext_key()
    local cfg = ClusterwideConfig.new():set_plaintext('key', 'val')
    t.assert_equals(cfg:get_plaintext(), {['key'] = 'val'})
    t.assert_equals(cfg:get_readonly(), {['key'] = 'val'})

    cfg:set_plaintext('key', nil)
    t.assert_equals(cfg:get_plaintext(), {})
    t.assert_equals(cfg:get_readonly(), {})

    local cfg = ClusterwideConfig.new():set_plaintext('key', 'val')
    t.assert_equals(cfg:get_plaintext(), {['key'] = 'val'})
    t.assert_equals(cfg:get_readonly(), {['key'] = 'val'})

    cfg:set_plaintext('key', box.NULL)
    t.assert_equals(cfg:get_plaintext(), {})
    t.assert_equals(cfg:get_readonly(), {})
end

function g.test_create_err()
    t.assert_error_msg_contains(
        'bad argument #1 to new (?table expected, got string)',
        function() ClusterwideConfig.new('str') end
    )
    t.assert_error_msg_contains(
        'bad argument #1 to new (table keys must be strings)',
        function() ClusterwideConfig.new({[1] = 'one'}) end
    )
    t.assert_error_msg_contains(
        'bad argument #1 to new (table values must be strings)',
        function() ClusterwideConfig.new({two = 2}) end
    )

    local cfg, err = ClusterwideConfig.new({
        ['x'] = 'foo',
        ['x.yml'] = 'bar'
    })
    t.assert_equals(cfg, nil)
    t.assert_covers(err, {
        class_name = 'LoadConfigError',
        err = 'Ambiguous sections "x" and "x.yml"'
    })
end


function g.test_get_readonly_ok()
    local data = '{fizz: buzz} #important comment'

    local cfg = ClusterwideConfig.new()
    t.assert_equals({cfg:get_readonly()}, {{}})

    local cfg = ClusterwideConfig.new():set_plaintext('a',  data)
    t.assert_equals({cfg:get_readonly('a')}, {data})

    local cfg = ClusterwideConfig.new():set_plaintext('a.txt',  data)
    t.assert_equals({cfg:get_readonly('a.txt')}, {data})

    local cfg = ClusterwideConfig.new():set_plaintext('a.yml',  data)
    t.assert_equals({cfg:get_readonly('a.yml')}, {data})
    t.assert_equals({cfg:get_readonly('a')}, {yaml.decode(data)})

    -- local cfg = ClusterwideConfig.new():set_plaintext('a.yaml', data)
    -- t.assert_equals({cfg:get_readonly('a.yaml')}, {data})
    -- t.assert_equals({cfg:get_readonly('a')}, {yaml.decode(data)})
end


function g.test_get_readonly_err()
    local cfg = ClusterwideConfig.new():set_plaintext('bad.yml', ',')
    cfg:set_plaintext('bad.yml', ',')
    t.assert_error_msg_contains(
        'LoadConfigError: Error parsing section "bad.yml":' ..
        ' unexpected END event',
        cfg.get_readonly, cfg
    )

    local cfg = ClusterwideConfig.new()
    cfg:set_plaintext('file.yml', '---\n{__file: some.txt}\n...')
    local _, err = cfg:update_luatables()
    t.assert_str_icontains(
        err.str,
        'LoadConfigError: Error loading section "file":' ..
        ' inclusion "some.txt" not found'
    )
end

function g.test_immutability()
    t.assert_error_msg_contains(
        'table is read-only',
        function()
            local cfg = ClusterwideConfig.new()
            cfg:get_readonly()['data'] = 'new_data'
        end
    )
end

function g.test_get_deepcopy_modify()
    local cfg = ClusterwideConfig.new():get_deepcopy()
    t.assert_equals(cfg, {})

    cfg['new_key'] = 'new_value'
    t.assert_equals(cfg, {
        ['new_key'] = 'new_value'
    })
end

function g.test_save_empty_config()
    local cfg = ClusterwideConfig.new()

    local p1 = g.tempdir .. '/cfg-1'
    ClusterwideConfig.save(cfg, p1)
    t.assert_equals({fio.listdir(p1)}, {{}})

    cfg:set_plaintext('data.yml', nil)
    local p2 = g.tempdir .. '/cfg-2'
    ClusterwideConfig.save(cfg, p2)
    t.assert_equals(fio.listdir(p2), {})

    cfg:set_plaintext('data.yml', '')
    local p3 = g.tempdir .. '/cfg-3'
    ClusterwideConfig.save(cfg, p3)
    t.assert_equals(fio.listdir(p3), {'data.yml'})
    t.assert_equals(utils.file_read(p3 .. '/data.yml'), '')
    t.assert_equals(cfg:get_readonly('data'), nil)
    t.assert_equals(cfg:get_readonly('data.yml'), '')
    t.assert_equals(cfg:get_readonly(), {
        ['data'] = nil,
        ['data.yml'] = '',
    })

    cfg:set_plaintext('data.yml', box.NULL)
    local p4 = g.tempdir .. '/cfg-4'
    ClusterwideConfig.save(cfg, p4)
    t.assert_equals(fio.listdir(p4), {})
end


function g.test_save_err()
    write_tree({['config'] = '---\n...'})

    local cfg = ClusterwideConfig.new({['b'] = 'b'})
    local ok, err = ClusterwideConfig.save(cfg, g.tempdir .. '/config')
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'SaveConfigError',
        err = string.format(
            "%s: %s",
            g.tempdir .. '/config',
            errno.strerror(errno.ENOTDIR)
        )
    })
    t.assert_equals(utils.file_read(g.tempdir .. '/config'), '---\n...')
end

function g.test_save_ok()
    local cfg = ClusterwideConfig.new()
    local ok, err = ClusterwideConfig.save(cfg, g.tempdir .. '/cfg1')
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    t.assert_equals(
        fio.listdir(fio.pathjoin(g.tempdir, 'cfg1')),
        {}
    )

    local cfg = ClusterwideConfig.new({
        ['some.txt'] = 'text',
        ['a/b/data'] = 'data',
        ['key.yml'] = '---\n{__file: some.txt}\n...',
        ['another.yml'] = '---\n{a: "val"}\n...'
    })

    local ok, err = ClusterwideConfig.save(
        cfg, fio.pathjoin(g.tempdir, 'cfg2')
    )
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    t.assert_items_equals(
        fio.listdir(fio.pathjoin(g.tempdir, 'cfg2')),
        {'a', 'some.txt', 'another.yml', 'key.yml'}
    )

    t.assert_equals(
        utils.file_read(fio.pathjoin(g.tempdir, 'cfg2/some.txt')),
        'text'
    )

    t.assert_equals(
        utils.file_read(fio.pathjoin(g.tempdir, 'cfg2/a/b/data')),
        'data'
    )

    t.assert_equals(
        utils.file_read(fio.pathjoin(g.tempdir, 'cfg2/key.yml')),
        '---\n{__file: some.txt}\n...'
    )

    t.assert_equals(
        utils.file_read(fio.pathjoin(g.tempdir, 'cfg2/another.yml')),
        '---\n{a: "val"}\n...'
    )
end

function g.test_checksum()
    -- New configs are similar, as are their checksums
    t.assert_equals(
        ClusterwideConfig.new():get_checksum(),
        ClusterwideConfig.new():get_checksum()
    )

    -- Different tables result in checksum mismatch (obviously)
    local cfg1 = ClusterwideConfig.new({['a'] = 'A'})
    local cfg2 = ClusterwideConfig.new({['a'] = 'B'})
    t.assert_not_equals(cfg1:get_checksum(), cfg2:get_checksum())

    -- Copy of cfg1 should have the same checksum
    cfg2 = cfg1:copy()
    t.assert_equals(cfg1:get_checksum(), cfg2:get_checksum())

    -- Changing in cfg with set_plaintext should result in change of
    -- checksum as well
    cfg1:set_plaintext('b', 'Hello there')
    t.assert_not_equals(cfg1:get_checksum(), cfg2:get_checksum())
    cfg2:set_plaintext('b', 'Hello there')
    t.assert_equals(cfg1:get_checksum(), cfg2:get_checksum())

    -- Sections and their content should be hashed separatly
    t.assert_not_equals(
        ClusterwideConfig.new({['foo'] = 'bar'}):get_checksum(),
        ClusterwideConfig.new({['foob'] = 'ar'}):get_checksum()
    )

    local c1 = {a = 'A', b = 'B'}
    local c2 = {b = 'B', a = 'A'}
    -- Two tables differ by inner representation
    t.assert(next(c1) ~= next(c2))
    -- Iteration order does not affect checksum calculation
    t.assert_equals(
        ClusterwideConfig.new(c1):get_checksum(),
        ClusterwideConfig.new(c2):get_checksum()
    )

end
