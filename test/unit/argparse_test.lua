#!/usr/bin/env tarantool

local t = require('luatest')
local g = t.group('argparse')
local log = require('log')
local fio = require('fio')
local yaml = require('yaml')
local checks = require('checks')
local utils = require('cartridge.utils')

function g:setup()
    self.tempdir = fio.tempdir()

    utils.file_write(
        fio.pathjoin(self.tempdir, 'getargs.lua'),
        [[
            local log = require('log')
            local fio = require('fio')
            local yaml = require('yaml')
            local errors = require('errors')
            local argparse = require('cartridge.argparse')
            fio.chdir("]] .. self.tempdir .. [[")
            local args, err = errors.pcall('ArgparseError', argparse.parse)
            if args == nil then
                print(yaml.encode({err = tostring(err)}))
                os.exit(1)
            end
            local box_opts, err = argparse.get_box_opts()
            print(yaml.encode({
                args = args,
                box_opts = {box_opts, err and tostring(err)},
            }))
        ]]
    )
end

function g:teardown()
    fio.rmtree(self.tempdir)
end

function g:run(cmd_args, env_vars, opts)
    checks('?', '?string', '?table', {
        ignore_errors = '?boolean',
    })
    local cmd =
        ('env --ignore-environment %s'):format(table.concat(env_vars or {}, ' ')) ..
        (' %s %q '):format(arg[-1], fio.pathjoin(self.tempdir, 'getargs.lua')) ..
        (cmd_args or '')
    local raw = io.popen(cmd):read('*all')
    local ret = yaml.decode(raw)

    if ret.err ~= nil
    and not (opts and opts.ignore_errors)
    then
        error('Script failed\n'..ret.err)
    end

    return ret
end

function g:test_sections()
    utils.file_write(
        fio.pathjoin(self.tempdir, 'tarantool.yml'),
        yaml.encode({
            ['default'] = {
                x = '@default',
                y_default = 0,
            },
            ['custom'] = {
                x = '@custom',
                y_custom = '$',
            },
            ['custom.sub'] = {
                x = '@custom.sub',
                y_sub = 3.14,
            },
            ['custom.sub.sub'] = {
                x = '@custom.sub.sub',
                y_subsub = true,
            },
        })
    )

    local function check(cmd_args, expected)
        local ret = self:run(cmd_args, {'TARANTOOL_CFG=./tarantool.yml'})
        t.assertEquals(ret.args['cfg'], './tarantool.yml')
        ret.args['cfg'] = nil
        t.assertEquals(ret.args, expected)
    end

    check('', {
        x = '@default',
        y_default = 0,
    })

    check('--instance-name', {
        instance_name = '',
        x = '@default',
        y_default = 0,
    })

    check('--instance-name ""', {
        instance_name = '',
        x = '@default',
        y_default = 0,
    })

    check('--instance-name unknown', {
        instance_name = 'unknown',
        x = '@default',
        y_default = 0,
    })

    check('--instance-name custom', {
        instance_name = 'custom',
        x = '@custom',
        y_default = 0,
        y_custom = '$',
    })

    check('--instance-name custom.bad', {
        instance_name = 'custom.bad',
        x = '@custom',
        y_default = 0,
        y_custom = '$',
    })

    check('--instance-name custom.sub', {
        instance_name = 'custom.sub',
        x = '@custom.sub',
        y_default = 0,
        y_custom = '$',
        y_sub = 3.14,
    })

    check('--instance_name custom.sub.sub', {
        instance_name = 'custom.sub.sub',
        x = '@custom.sub.sub',
        y_default = 0,
        y_custom = '$',
        y_sub = 3.14,
        y_subsub = true,
    })
end

function g:test_priority()
    utils.file_write(
        fio.pathjoin(self.tempdir, 'x.yml'),
        yaml.encode({
            ['default'] = {x = '@default'},
            ['custom'] = {x = '@custom'},
        })
    )
    utils.file_write(
        fio.pathjoin(self.tempdir, 'cfg.yml'),
        yaml.encode({
            ['default'] = {x = '@cfg-default'},
            ['custom'] = {x = '@cfg-custom'},
        })
    )

    local function check(cmd_args, env_vars, expected)
        local args = self:run(cmd_args, env_vars).args
        t.assertEquals(args.x, expected)
    end

    check('',                {'TARANTOOL_CFG=./x.yml'}, '@default')
    check('',               {'TARANTOOL_X="@EnvVars"'}, '@EnvVars')
    check('--x "@CmdArgs"', {'TARANTOOL_X="@EnvVars"'}, '@CmdArgs')
    check('--x ""',         {'TARANTOOL_X="@EnvVars"'}, '')
    check('--x',            {'TARANTOOL_X="@EnvVars"'}, '')
    check('',                         {'TARANTOOL_X='}, '')

    check('--instance-name custom',             {'TARANTOOL_CFG=./x.yml'}, '@custom')
    check('', {'TARANTOOL_INSTANCE_NAME=custom', 'TARANTOOL_CFG=./x.yml'}, '@custom')
    check('', {'TARANTOOL_INSTANCE_NAME=CUSTOM', 'TARANTOOL_CFG=./x.yml'}, '@default')

    check('--cfg ./cfg.yml',   {'TARANTOOL_CFG=./x.yml'}, '@cfg-default')
    check('',              {'TARANTOOL_CFG="./cfg.yml"'}, '@cfg-default')
    check('--cfg ./x.yml', {'TARANTOOL_CFG="./cfg.yml"'}, '@default')
    check('--instance-name custom', {'TARANTOOL_CFG="./cfg.yml"'}, '@cfg-custom')

end

function g:test_overrides()
    utils.file_write(
        fio.pathjoin(self.tempdir, 'tarantool.yml'),
        yaml.encode({
            ['default'] = {
                a1 = 1.1,
                B2 = 2.2,
            },
        })
    )

    local function check(cmd_args, env_vars, expected)
        table.insert(env_vars, 'TARANTOOL_CFG=./tarantool.yml')
        local ret = self:run(cmd_args, env_vars)
        t.assertEquals(ret.args['cfg'], './tarantool.yml')
        ret.args['cfg'] = nil
        t.assertEquals(ret.args, expected)
    end

    check('', {}, {a1 = 1.1, b2 = 2.2})
    check('--a1 a1', {}, {a1 = 'a1', b2 = 2.2})
    check('--A1 A1', {}, {a1 = 'A1', b2 = 2.2})
    check('--a1 o1 --a1 o2', {}, {a1 = 'o2', b2 = 2.2})
    check('', {"TARANTOOL_a1=e1"}, {a1 = 'e1', b2 = 2.2})
    check('', {"TARANTOOL_A1=E1"}, {a1 = 'E1', b2 = 2.2})
    check('', {"TARANTOOL_A1=O1", "TARANTOOL_A1=O2"}, {a1 = 'O2', b2 = 2.2})
end

function g:test_appname()
    utils.file_write(
        fio.pathjoin(self.tempdir, 'cfg.yml'),
        yaml.encode({
            ['myapp'] = {
                x = '@myapp',
            },
            ['otherapp'] = {
                y = '@otherapp',
            },
        })
    )

    utils.file_write(
        fio.pathjoin(self.tempdir, 'myapp-scm-1.rockspec'),
        ''
    )

    local function check(cmd_args, expected)
        local ret = self:run(cmd_args, {'TARANTOOL_CFG=./cfg.yml'})
        t.assertEquals(ret.args['cfg'], './cfg.yml')
        ret.args['cfg'] = nil
        t.assertEquals(ret.args, expected)
    end

    check('',                    {app_name = 'myapp', x = '@myapp'})
    check('--app-name otherapp', {app_name = 'otherapp', y = '@otherapp'})
end

function g:test_confdir()
    local confd = fio.pathjoin(self.tempdir, 'conf.d')
    fio.mkdir(confd)
    utils.file_write(
        fio.pathjoin(confd, '0-default.yml'),
        yaml.encode({['default'] = {x = '@default'}})
    )
    utils.file_write(
        fio.pathjoin(confd, '1-custom.yml'),
        yaml.encode({['custom'] = {x = '@custom'}})
    )

    local function check(cmd_args, expected)
        local args = self:run(cmd_args, {'TARANTOOL_CFG=./conf.d'}).args
        t.assertEquals(args.cfg, './conf.d/')
        t.assertEquals(args.x, expected)
    end

    check('--instance-name default', '@default')
    check('--instance-name custom', '@custom')

    local confd = fio.pathjoin(self.tempdir, 'conflict.d')
    fio.mkdir(confd)
    utils.file_write(
        fio.pathjoin(confd, '0-default.yml'),
        yaml.encode({['other'] = {x = '@default'}})
    )
    utils.file_write(
        fio.pathjoin(confd, '1-custom.yml'),
        yaml.encode({['other'] = {y = '@custom'}})
    )

    local ret = self:run('--cfg ./conflict.d', {}, {ignore_errors = true})
    t.assertStrContains(ret.err, 'ConfDirError: collision of section "other"' ..
        ' in ./conflict.d/ between 0-default.yml and 1-custom.yml'
    )
end

function g:test_badfile()
    utils.file_write(
        fio.pathjoin(self.tempdir, 'cfg.txt'),
        'x = whatever'
    )

    local ret = self:run('--cfg ./cfg.txt', {}, {ignore_errors = true})
    t.assertStrContains(ret.err, 'ConfFileError: ./cfg.txt: unsupported file type')

    local ret = self:run('--cfg /dev/null', {}, {ignore_errors = true})
    t.assertStrContains(ret.err, 'ConfFileError: /dev/null: unsupported file type')

    local ret = self:run('--cfg /no/such/file.yml', {}, {ignore_errors = true})
    t.assertStrContains(ret.err, 'Can not open file: "/no/such/file.yml" No such file or directory')

    utils.file_write(
        fio.pathjoin(self.tempdir, 'tarantool.yml'),
        '}'
    )
    local ret = self:run('--cfg tarantool.yml', {}, {ignore_errors = true})
    t.assertStrContains(ret.err, 'DecodeYamlError: tarantool.yml: unexpected END event')
end

function g:test_box_opts()
    utils.file_write(
        fio.pathjoin(self.tempdir, 'cfg.yml'),
        yaml.encode({
            default = {
                username = 'alice',        -- string -> string
                slab_alloc_factor = '1.3', -- string -> number
                log_nonblock = 'false',    -- string -> bool
                memtx_memory = 100,        -- number -> number
                read_only = true,          -- bool -> bool
            },
            number_to_string = {
                feedback_host = 0,
            },
            boolean_to_string = {
                feedback_host = false,
            },
            table_to_string = {
                feedback_host = {},
            },
            number_to_boolean = {
                read_only = 0,
            },
            boolean_to_number = {
                readahead = false,
            },
        })
    )

    local box_opts, err = unpack(self:run('--cfg ./cfg.yml').box_opts)
    t.assertNil(err)
    t.assertEquals(box_opts, {
        username = 'alice',
        slab_alloc_factor = 1.3,
        log_nonblock = false,
        memtx_memory = 100,
        read_only = true,
    })

    local function check_err(cmd_args, expected)
        local ok, err = unpack(self:run(cmd_args).box_opts)
        t.assertNil(ok)
        t.assertStrContains(err, expected)
    end

    check_err('--memtx-memory false',
        [[TypeCastError: can't typecast memtx_memory="false" to number]]
    )

    check_err('--memtx-memory --1',
        [[TypeCastError: can't typecast memtx_memory="--1" to number]]
    )

    check_err('--read-only yes',
        [[TypeCastError: can't typecast read_only="yes" to boolean]]
    )

    check_err('--read-only 1',
        [[TypeCastError: can't typecast read_only="1" to boolean]]
    )

    check_err('--cfg ./cfg.yml --instance-name number_to_string',
        [[TypeCastError: invalid configuration parameter feedback_host (string expected, got number)]]
    )

    check_err('--cfg ./cfg.yml --instance-name boolean_to_string',
        [[TypeCastError: invalid configuration parameter feedback_host (string expected, got boolean)]]
    )

    check_err('--cfg ./cfg.yml --instance-name table_to_string',
        [[TypeCastError: invalid configuration parameter feedback_host (string expected, got table)]]
    )

    check_err('--cfg ./cfg.yml --instance-name number_to_boolean',
        [[TypeCastError: invalid configuration parameter read_only (boolean expected, got number)]]
    )

    check_err('--cfg ./cfg.yml --instance-name boolean_to_number',
        [[TypeCastError: invalid configuration parameter readahead (number expected, got boolean)]]
    )
end