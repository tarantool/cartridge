#!/usr/bin/env tarantool

local t = require('luatest')
local g = t.group('clusterwide_config')
local fio = require('fio')
local yaml = require('yaml')
local checks = require('checks')
local errno = require('errno')
local utils = require('cartridge.utils')
local clusterwide_config = require('cartridge.clusterwide-config')

g.setup = function()
    g.tempdir = fio.tempdir()
end

g.teardown = function()
    fio.rmtree(g.tempdir)
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
    write_tree({
        ['a/b/c/first.txt'] = 'first',
        ['a/b/c/second.yml'] = 'key: value',
        ['table.yml'] = '{a: {b: {c: 4}}}',
        ['table.txt'] = '{a: {b: {c: 5}}}',
        ['include.yml'] = '__file: a/b/c/first.txt',
    })

    local cfg, err = clusterwide_config.load(g.tempdir)
    t.assert_equals(err, nil)
    t.assert_equals(
        cfg:get_readonly(),
        {
            ['a/b/c/first.txt'] = 'first',
            ['a/b/c/second.yml'] = {key = 'value'},
            ['table.txt'] = '{a: {b: {c: 5}}}',
            ['table.yml'] = {a = {b = {c = 4}}},
            ['include.yml'] = 'first',
        }
    )

    t.assert_equals(
        cfg:get_plaintext(),
        {
            ['a/b/c/first.txt'] = 'first',
            ['a/b/c/second.yml'] = 'key: value',
            ['include.yml'] = '__file: a/b/c/first.txt',
            ['table.txt'] = '{a: {b: {c: 5}}}',
            ['table.yml'] = '{a: {b: {c: 4}}}'
        }
    )
end

function g.test_newstyle_err()
    local cfg, err = clusterwide_config.load(
        fio.pathjoin(g.tempdir, 'not_existing')
    )
    t.assert_equals(cfg, nil)
    t.assert_equals(err.class_name, 'LoadConfigError')
    t.assert_equals(err.err,
        string.format(
            "Error loading %q: %s",
            fio.pathjoin(g.tempdir, 'not_existing'),
            errno.strerror(errno.ENOENT)
        )
    )

    write_tree({
        ['cfg1/bad.yml'] = ',',
    })
    local cfg, err = clusterwide_config.load(g.tempdir .. '/cfg1')
    t.assert_equals(cfg, nil)
    t.assert_equals(err.class_name, 'LoadConfigError')
    t.assert_equals(err.err,
        'Error parsing section "bad.yml": unexpected END event'
    )

    write_tree({
        ['cfg2/bad.yml'] = '{__file: not_existing.txt}',
    })
    local cfg, err = clusterwide_config.load(g.tempdir .. '/cfg2')
    t.assert_equals(cfg, nil)
    t.assert_equals(err.class_name, 'LoadConfigError')
    t.assert_equals(err.err,
        'Error loading section "bad.yml":' ..
        ' inclusion "not_existing.txt" not found'
    )
end

function g.test_oldstyle_ok()
    write_tree({
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
    })
    local cfg = clusterwide_config.load(g.tempdir .. '/main.yml')

    cfg:update_luatables()
    t.assert_equals(cfg._luatables, {
        ['string'] = 'foobar',
        ['table.yml'] = {a = {b = {c = 4}}},
        ['number.yml'] = 42,
        ['boolean.yml'] = false,
        ['side_config.yml'] = "Hi it's me",
        ['inclusion.txt'] = "Hi it's me",
        ['colors.yml'] = {red = '0xff0000'}
    })
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
    local cfg, err = clusterwide_config.load(
        fio.pathjoin(g.tempdir, 'not_existing.yml')
    )
    t.assert_equals(cfg, nil)
    t.assert_equals(err.class_name, 'LoadConfigError')
    t.assert_equals(err.err,
        string.format(
            "Error loading %q: %s",
            fio.pathjoin(g.tempdir, 'not_existing.yml'),
            errno.strerror(errno.ENOENT)
        )
    )

    write_tree({['bad1/main.yml'] = ','})
    local cfg, err = clusterwide_config.load(g.tempdir .. '/bad1/main.yml')
    t.assert_equals(cfg, nil)
    t.assert_equals(err.class_name, 'LoadConfigError')
    t.assert_equals(err.err,
        string.format(
            "Error parsing %q: unexpected END event",
            fio.pathjoin(g.tempdir, 'bad1/main.yml'),
            errno.strerror(errno.ENOENT)
        )
    )

    write_tree({['bad2/main.yml'] = [[
        side_config: {__file: 'not_existing.txt'}
    ]]})
    local cfg, err = clusterwide_config.load(g.tempdir .. '/bad2/main.yml')
    t.assert_equals(cfg, nil)
    t.assert_equals(err.class_name, 'LoadConfigError')
    t.assert_equals(err.err,
        -- TODO: it shouldn't append .yml extension here
        'Error loading section "side_config.yml":' ..
        ' inclusion "not_existing.txt" not found'
    )
end

function g.test_preserving_plaintext()
    local cfg = clusterwide_config.new()
    local data = '{fizz: buzz} #important comment'
    cfg:set_plaintext('data.yml', data)

    t.assert_equals(
        cfg:get_readonly('data.yml'), {fizz = 'buzz'}
    )

    t.assert_equals(
        cfg:get_plaintext('data.yml'), data
    )
end


function g.test_delete_plaintext_key()
    local cfg = clusterwide_config.new():set_plaintext('key', 'val')
    t.assert_equals(cfg:get_plaintext(), {['key'] = 'val'})
    t.assert_equals(cfg:get_readonly(), {['key'] = 'val'})

    cfg:set_plaintext('key', nil)
    t.assert_equals(cfg:get_plaintext(), {})
    t.assert_equals(cfg:get_readonly(), {})

    local cfg = clusterwide_config.new():set_plaintext('key', 'val')
    t.assert_equals(cfg:get_plaintext(), {['key'] = 'val'})
    t.assert_equals(cfg:get_readonly(), {['key'] = 'val'})

    cfg:set_plaintext('key', box.NULL)
    t.assert_equals(cfg:get_plaintext(), {})
    t.assert_equals(cfg:get_readonly(), {})
end


function g.test_get_readonly_ok()
    local data = '{fizz: buzz} #important comment'

    local cfg = clusterwide_config.new()
    t.assert_equals({cfg:get_readonly()}, {{}})

    local cfg = clusterwide_config.new():set_plaintext('a',  data)
    t.assert_equals({cfg:get_readonly('a')}, {data})

    local cfg = clusterwide_config.new():set_plaintext('a.txt',  data)
    t.assert_equals({cfg:get_readonly('a.txt')}, {data})

    local cfg = clusterwide_config.new():set_plaintext('a.yml',  data)
    t.assert_equals({cfg:get_readonly('a.yml')}, {yaml.decode(data)})

    local cfg = clusterwide_config.new():set_plaintext('a.yaml', data)
    t.assert_equals({cfg:get_readonly('a.yaml')}, {yaml.decode(data)})
end


function g.test_get_readonly_err()
    local cfg = clusterwide_config.new():set_plaintext('bad.yml', ',')
    cfg:set_plaintext('bad.yml', ',')
    t.assert_error_msg_contains(
        'LoadConfigError: Error parsing section "bad.yml":' ..
        ' unexpected END event',
        cfg.get_readonly, cfg
    )

    local cfg = clusterwide_config.new()
    cfg:set_plaintext('file.yml', '---\n{__file: some.txt}\n...')
    local _, err = cfg:update_luatables()
    t.assert_str_icontains(
        err.str,
        'LoadConfigError: Error loading section "file.yml":' ..
        ' inclusion "some.txt" not found'
    )
end

function g.test_immutability()
    t.assert_error_msg_contains(
        'table is read-only',
        function()
            local cfg = clusterwide_config.new()
            cfg:get_readonly()['data'] = 'new_data'
        end
    )
end

function g.test_get_deepcopy_modify()
    local cfg = clusterwide_config.new():get_deepcopy()
    t.assert_equals(cfg, {})

    cfg['new_key'] = 'new_value'
    t.assert_equals(cfg, {
        ['new_key'] = 'new_value'
    })
end

function g.test_save_empty_config()
    local cfg = clusterwide_config.new()

    local p1 = fio.pathjoin(g.tempdir, 'cfg-1')
    clusterwide_config.save(cfg, p1)
    t.assert_equals({fio.listdir(p1)}, {{}})

    cfg:set_plaintext('data.yml', nil)
    local p2 = fio.pathjoin(g.tempdir, 'cfg-2')
    clusterwide_config.save(cfg, p2)
    t.assert_equals(fio.listdir(p2), {})

    cfg:set_plaintext('data.yml', '')
    local p3 = fio.pathjoin(g.tempdir, 'cfg-3')
    clusterwide_config.save(cfg, p3)
    t.assert_equals(fio.listdir(p3), {'data.yml'})
    t.assert_equals(utils.file_read(p3 .. '/data.yml'), '')

    cfg:set_plaintext('data.yml', box.NULL)
    local p4 = fio.pathjoin(g.tempdir, 'cfg-4')
    clusterwide_config.save(cfg, p4)
    t.assert_equals(fio.listdir(p4), {})
end


function g.test_save_config_err()
    local cfg_a = clusterwide_config.new({['a'] = 'a'})
    local ok, err = clusterwide_config.save(cfg_a, g.tempdir .. '/config')
    t.assert_equals(ok, true)
    t.assert_equals(err, nil)

    local cfg_b = clusterwide_config.new({['b'] = 'b'})
    local ok, err = clusterwide_config.save(cfg_b, g.tempdir .. '/config')
    t.assert_equals(ok, nil)
    t.assert_str_icontains(
        err.str,
        string.format(
            "ConflictConfigError: Config can't be saved, directory %q already exists",
            g.tempdir .. '/config'
        )
    )

    t.assert_equals(
        fio.listdir(g.tempdir .. '/config'),
        {'a'}
    )
end

function g.test_save_config_ok()
    local cfg = clusterwide_config.new()
    local ok, err = clusterwide_config.save(cfg, g.tempdir .. '/cfg1')
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    t.assert_equals(
        fio.listdir(fio.pathjoin(g.tempdir, 'cfg1')),
        {}
    )

    local cfg = clusterwide_config.new({
        ['some.txt'] = 'text',
        ['a/b/data'] = 'data',
        ['key.yml'] = '---\n{__file: some.txt}\n...',
        ['another.yml'] = '---\n{a: "val"}\n...'
    })

    local ok, err = clusterwide_config.save(
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
