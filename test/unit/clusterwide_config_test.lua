#!/usr/bin/env tarantool

local t = require('luatest')
local g = t.group('clusterwide_config')
local fio = require('fio')
local yaml = require('yaml')
local utils = require('cartridge.utils')
local clusterwide_config = require('cartridge.clusterwide-config')

g.setup = function()
    g.tempdir = fio.tempdir()
end

g.teardown = function()
    fio.rmtree(g.tempdir)
end


function g.test_new_config_nested()
    utils.mktree(
        fio.pathjoin(g.tempdir, 'a/b/c')
    )
    utils.file_write(
        fio.pathjoin(g.tempdir, 'a/b/c/first.txt'),
        'first'
    )

    utils.file_write(
        fio.pathjoin(g.tempdir, 'a/b/c/second.yml'),
        'key: value'
    )

    utils.file_write(
        fio.pathjoin(g.tempdir, 'directive.yml'),
        '__file: a/b/c/first.txt'
    )

    utils.file_write(
        fio.pathjoin(g.tempdir, 'table.txt'),
        '{a: {b: {c: 4}}}'
    )

    utils.file_write(
        fio.pathjoin(g.tempdir, 'table.yml'),
        '{a: {b: {c: 4}}}'
    )

    local cfg, err = clusterwide_config.load(g.tempdir)
    t.assert_equals(err, nil)
    t.assert_equals(
        cfg:get_readonly(),
        {
            ['a/b/c/first.txt'] = 'first',
            ['a/b/c/second.yml'] = {key = 'value'},
            ['directive.yml'] = 'first',
            ['table.txt'] = '{a: {b: {c: 4}}}',
            ['table.yml'] = {a = {b = {c = 4}}}
        }
    )

    t.assert_equals(
        cfg:get_plaintext(),
        {
            ['a/b/c/first.txt'] = 'first',
            ['a/b/c/second.yml'] = 'key: value',
            ['directive.yml'] = '__file: a/b/c/first.txt',
            ['table.txt'] = '{a: {b: {c: 4}}}',
            ['table.yml'] = '{a: {b: {c: 4}}}'
        }
    )
end


function g.test_laod_newstyle_err()
    local cfg, err = clusterwide_config.load(
        fio.pathjoin(g.tempdir, 'not_existing')
    )
    t.assert_equals(cfg, nil)
    t.assert_str_icontains(
        err.err, string.format(
            "entry %q does not exist",
            fio.pathjoin(g.tempdir, 'not_existing')
        )
    )


    local cfg_path = fio.pathjoin(g.tempdir, 'cfg1')
    utils.mktree(cfg_path)
    utils.file_write(
        fio.pathjoin(cfg_path, 'text.txt'),
        'text'
    )
    utils.file_write(
        fio.pathjoin(cfg_path, 'bad.yml'),
        ','
    )

    local cfg, err = clusterwide_config.load(cfg_path)
    t.assert_equals(cfg, nil)
    t.assert_str_icontains(
        err.str,
        'DecodeYamlError: Parsing bad.yml raised error: unexpected END event'
    )

    local cfg_path = fio.pathjoin(g.tempdir, 'cfg2')
    utils.mktree(cfg_path)
    utils.file_write(
        fio.pathjoin(cfg_path, 'some.yml'),
        '{__file: not_existing.txt}'
    )

    local cfg, err = clusterwide_config.load(cfg_path)
    t.assert_equals(cfg, nil)
    t.assert_str_icontains(
        err.str,
        'SectionNotFoundError: Error while parsing data, in section "some.yml"' ..
        ' directive "not_existing.txt" not found, please check that file exists'
    )
end


function g.test_load_oldstyle_ok()
    utils.file_write(
        fio.pathjoin(g.tempdir, 'main.yml'), [[
            string: "foobar"
            table: {a: {b: {c: 4}}}
            number: 42
            boolean: false
            side: {__file: 'side.txt'}
            colors.yml: "---\n{red: '0xff0000'}\n..."
        ]]
    )
    utils.file_write(
        fio.pathjoin(g.tempdir, 'side.txt'),
        'hi its me'
    )

    local cfg = clusterwide_config.load(
        fio.pathjoin(g.tempdir, 'main.yml')
    )

    cfg:update_luatables()
    t.assert_equals(cfg._luatables, {
        ['string'] = 'foobar',
        ['table.yml'] = {a = {b = {c = 4}}},
        ['number.yml'] = 42,
        ['boolean.yml'] = false,
        ['side.yml'] = 'hi its me',
        ['side.txt'] = 'hi its me',
        ['colors.yml'] = {red = '0xff0000'}
    })
    t.assert_equals(cfg._luatables, cfg:get_readonly())


    t.assert_equals(cfg._plaintext, {
        ['string'] = "foobar",
        ['table.yml'] = yaml.encode({a = {b = {c = 4}}}),
        ['number.yml'] = yaml.encode(42),
        ['boolean.yml'] = yaml.encode(false),
        ['side.yml'] = yaml.encode({__file = 'side.txt'}),
        ['side.txt'] = 'hi its me',
        ['colors.yml'] = "---\n{red: '0xff0000'}\n...",
    })
    t.assert_equals(cfg._plaintext, cfg:get_plaintext())
end

function g.test_load_oldstyle_err()
    local cfg, err = clusterwide_config.load(
        fio.pathjoin(g.tempdir, 'not_existing.yml')
    )
    t.assert_equals(cfg, nil)
    t.assert_str_icontains(
        err.str, string.format(
            'LoadConfigError: entry %q does not exist',
            fio.pathjoin(g.tempdir, 'not_existing.yml')
        )
    )

    utils.file_write(
        fio.pathjoin(g.tempdir, 'main.yml'), ','
    )
    local cfg, err = clusterwide_config.load(
        fio.pathjoin(g.tempdir, 'main.yml')
    )
    t.assert_equals(cfg, nil)
    t.assert_str_icontains(
        err.str, string.format(
            'DecodeYamlError: unexpected END event',
            fio.pathjoin(g.tempdir, 'not_existing.yml')
        )
    )

    utils.file_write(
        fio.pathjoin(g.tempdir, 'main.yml'), [[
            string: "foobar"
            number: 42
            boolean: false
            side: {__file: 'not_exisiting.txt'}
        ]]
    )
    local cfg, err = clusterwide_config.load(
        fio.pathjoin(g.tempdir, 'main.yml')
    )
    t.assert_equals(cfg, nil)
    t.assert_str_icontains(
        err.str,
        'SectionNotFoundError: Error while parsing data, in section "side.yml" ' ..
        'directive "not_exisiting.txt" not found, please check that file exists'
    )
end


function g.test_invalid_yaml()
    utils.file_write(
        fio.pathjoin(g.tempdir, 'bad.yml'),
        ","
    )

    local ok, err = clusterwide_config.load(g.tempdir)
    t.assert_equals(ok, nil)
    t.assert_equals(err.class_name, 'DecodeYamlError')
    t.assert_equals(err.err,
        'Parsing bad.yml raised error: unexpected END event'
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
        'DecodeYamlError: Parsing bad.yml raised error: unexpected END event',
        cfg.get_readonly, cfg
    )

    local cfg = clusterwide_config.new():set_plaintext('file.yml', '---\n{__file: some.txt}\n...')
    local _, err = cfg:update_luatables()
    t.assert_str_icontains(
        err.str,
        'SectionNotFoundError: Error while parsing data, in section "file.yml"' ..
        ' directive "some.txt" not found, please check that file exists'
    )
end

function g.test_get_readonly_modify()
    local cfg = clusterwide_config.new()
    t.assert_error_msg_contains(
        'table is read-only',
        function()
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


function g.test_save_config_error()
    local cfg = clusterwide_config.new({
        ['a'] = 'a',
        ['data'] = 'data',
        ['b'] = 'b',
    })

    local cfg_path = fio.pathjoin(g.tempdir, 'config')
    utils.mktree(cfg_path)
    local ok, err = clusterwide_config.save(cfg, cfg_path)
    t.assert_equals(ok, nil)
    t.assert_str_icontains(
        err.str,
        string.format(
            "ConflictConfigError: Config can't be saved, directory %q already exists",
            cfg_path
        )
    )

    t.assert_equals(
        fio.listdir(cfg_path),
        {}
    )
end

function g.test_save_config_ok()
    local cfg = clusterwide_config.new()
    local ok, err = clusterwide_config.save(
        cfg, fio.pathjoin(g.tempdir, 'cfg1')
    )
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
    t.assert_equals(
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
