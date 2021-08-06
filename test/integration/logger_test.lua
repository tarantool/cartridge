local fio = require('fio')
local t = require('luatest')
local g = t.group()

local log = require('log')
local fun = require('fun')
local json = require('json')
local utils = require('cartridge.utils')
local helpers = require('test.helper')

g.before_each(function()
    g.tempdir = fio.tempdir()
    g.server = helpers.Server:new({
        alias = 'srv',
        workdir = g.tempdir,
        command = helpers.entrypoint('srv_basic'),
        instance_uuid = helpers.uuid('a', 'a', 1),
        replicaset_uuid = helpers.uuid('a'),
        cluster_cookie = require('digest').urandom(6):hex(),
        advertise_port = 13301,
        http_port = 8081,
    })
end)

g.after_each(function()
    g.server:stop()
    fio.rmtree(g.tempdir)
end)

function g.test_cfg()
    t.skip_if(log.cfg == nil, 'log.cfg() not implemented')

    g.server.env['TARANTOOL_LOG'] = ('| tee %s/log.txt'):format(g.tempdir)
    g.server.env['TARANTOOL_LOG_LEVEL'] = '2' -- ERROR

    print()
    g.server:start()
    g.servecall('package.loaded.log.info', {'Info message'})
    g.server:call('package.loaded.log.error', {'Error message'})
    g.server:stop()

    local txt, err = utils.file_read(g.tempdir .. '/log.txt')
    if txt == nil then
        error(err.err)
    end

    local lines = txt:strip():split('\n')
    t.assert_equals(#lines, 1, 'Too many lines logged')
    t.assert_str_matches(lines[1], '.+ E> Error message')
end

function g.test_content_unconfigured()
    t.skip_if(log.cfg == nil, 'log.cfg() not implemented')

    g.server.env['TARANTOOL_LOG'] = g.tempdir .. '/log.txt'
    g.server.env['TARANTOOL_LOG_FORMAT'] = 'json'

    g.server:start()
    g.server:call('package.loaded.log.info', {'Info message'})
    g.server:stop()

    local txt, err = utils.file_read(g.tempdir .. '/log.txt')
    if txt == nil then
        error(err.err)
    end

    local messages = fun.iter(txt:split('\n'))
        :map(function(l)
            local ok, record = pcall(json.decode, l)
            if ok then
                return record.message
            end
        end)
        :totable()

    t.assert_items_include(messages, {
        'Using advertise_uri "localhost:13301"',
        'Membership encryption enabled',
        'Membership BROADCAST sent to 127.0.0.1:3301',
        'Listening HTTP on 0.0.0.0:8081',
        'Remote control bound to 0.0.0.0:13301',
        'Remote control ready to accept connections',
        'Instance state changed:  -> Unconfigured',
        'Info message',
        'Cartridge ' .. require('cartridge').VERSION,
        'server alias ' .. g.server.alias,
        'advertise uri ' .. g.server.advertise_uri,
        'working directory ' .. g.server.workdir,
    })
end

function g.test_content_bootstrapped()
    print()
    g.server.env['TARANTOOL_LOG'] = ('| tee %s/log.txt'):format(g.tempdir)
    g.server:start()

    -- Fake init script
    g.server:eval('arg[0] = ...', {g.tempdir .. '/init.lua'})
    -- Fake VERSION file produced by cartridge pack
    utils.file_write(g.tempdir .. '/VERSION', 'pi=3.14.15-g9265358979')
    -- Bootstrap
    helpers.Server.join_cluster(g.server, g.server)

    g.server:stop()

    local txt, err = utils.file_read(g.tempdir .. '/log.txt')
    if txt == nil then
        error(err.err)
    end

    log.info('Captured:\n%s', txt)

    local messages = fun.iter(txt:split('\n'))
        :map(function(l) return l:match(' ([ECWI]> .+)$') end)
        :drop_while(function(l) return not l:startswith('C> Tarantool') end)
        :totable()

    t.assert_items_include(messages, {
        'I> Cartridge ' .. require('cartridge').VERSION,
        'I> server alias ' .. g.server.alias,
        'I> cluster uuid ' .. g.server.replicaset_uuid,
        'I> instance uuid ' .. g.server.instance_uuid,
        'I> advertise uri ' .. g.server.advertise_uri,
        'I> working directory ' .. g.server.workdir,
        'I> pi=3.14.15-g9265358979',
    })
end
