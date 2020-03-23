local fio = require('fio')
local t = require('luatest')
local g = t.group()
local helpers = require('test.helper')

g.before_each(function()
    g.datadir = fio.tempdir()
    g.cluster = helpers.Cluster:new({
        datadir = g.datadir,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),

        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {},
            servers = {
                {
                    alias = 'main',
                    instance_uuid = helpers.uuid('a', 'a', 1),
                    advertise_port = 13301,
                    http_port = 8081,
                }
            }
        }}
    })
end)

g.after_each(function()
    g.cluster:stop()
    fio.rmtree(g.datadir)
end)

function g.test_defaults()
    g.cluster:start()

    t.assert_items_equals(
        fio.listdir(g.cluster.main_server.workdir),
        {
            '.tarantool.cookie', 'config',
            '00000000000000000000.snap',
            '00000000000000000000.xlog',
        }
    )
end

function g.test_abspath()
    local memtx_dir = fio.pathjoin(g.datadir, 'memtx')
    local vinyl_dir = fio.pathjoin(g.datadir, 'vinyl')
    local wal_dir   = fio.pathjoin(g.datadir, 'wal')

    g.cluster.servers[1].env['TARANTOOL_VINYL_DIR'] = vinyl_dir
    g.cluster.servers[1].env['TARANTOOL_MEMTX_DIR'] = memtx_dir
    g.cluster.servers[1].env['TARANTOOL_WAL_DIR'] = wal_dir
    g.cluster:start()

    local workdir = g.cluster.main_server.workdir
    t.assert_items_equals(
        fio.listdir(g.datadir),
        {'wal', 'memtx', 'vinyl', fio.basename(workdir)}
    )
    t.assert_items_equals(
        fio.listdir(workdir),
        {'.tarantool.cookie', 'config'}
    )
    t.assert_equals(
        fio.listdir(wal_dir),
        {'00000000000000000000.xlog'}
    )
    t.assert_equals(
        fio.listdir(memtx_dir),
        {'00000000000000000000.snap'}
    )
    t.assert_equals(
        fio.listdir(vinyl_dir),
        {}
    )
end


function g.test_relpath()
    g.cluster.servers[1].env['TARANTOOL_VINYL_DIR'] = './vinyl'
    g.cluster.servers[1].env['TARANTOOL_MEMTX_DIR'] = './memtx'
    g.cluster.servers[1].env['TARANTOOL_WAL_DIR'] = 'wal'

    g.cluster:start()

    local workdir = g.cluster.main_server.workdir
    t.assert_items_equals(
        fio.listdir(workdir),
        {'wal', 'config', 'memtx', 'vinyl', '.tarantool.cookie'}
    )
    t.assert_equals(
        fio.listdir(fio.pathjoin(workdir, 'wal')),
        {'00000000000000000000.xlog'}
    )
    t.assert_equals(
        fio.listdir(fio.pathjoin(workdir, 'memtx')),
        {'00000000000000000000.snap'}
    )
    t.assert_equals(
        fio.listdir(fio.pathjoin(workdir, 'vinyl')),
        {}
    )
end

function g.test_chdir()
    local chdir = fio.pathjoin(g.datadir, 'cd')
    local wal_dir = fio.pathjoin(g.datadir, 'wal')
    local memtx_dir = '../memtx'

    g.cluster.servers[1].env['TARANTOOL_WAL_DIR'] = wal_dir
    g.cluster.servers[1].env['TARANTOOL_MEMTX_DIR'] = memtx_dir
    g.cluster.servers[1].env['TARANTOOL_WORK_DIR'] = chdir

    g.cluster:start()

    local workdir = g.cluster.main_server.workdir
    t.assert_items_equals(
        fio.listdir(g.datadir),
        {'cd', 'wal', 'memtx', fio.basename(workdir)}
    )
    t.assert_items_equals(
        fio.listdir(workdir),
        {'config', '.tarantool.cookie'}
    )
    t.assert_equals(
        fio.listdir(chdir),
        {}
    )
    t.assert_equals(
        fio.listdir(wal_dir),
        {'00000000000000000000.xlog'}
    )
    t.assert_equals(
        fio.listdir(fio.pathjoin(g.datadir, 'memtx')),
        {'00000000000000000000.snap'}
    )
end
