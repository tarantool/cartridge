local fio = require('fio')
local t = require('luatest')
local g = t.group()
local helpers = require('test.helper')

g.setup = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
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
end

g.teardown = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

function g.test_compatibility()
    g.cluster:start()

    t.assert_items_equals(fio.listdir(g.cluster.main_server.workdir), {
        '.tarantool.cookie', 'config',
        '00000000000000000000.snap',
        '00000000000000000000.xlog',
    })
end

function g.test_box_dirs_absolute_path()
    local workdir = g.cluster:server('main').workdir
    local cartridge_workdir = fio.pathjoin(workdir, 'cartridge')
    local memtx_dir = fio.pathjoin(workdir, 'memtx')
    local vinyl_dir = fio.pathjoin(workdir, 'vinyl')
    local wal_dir   = fio.pathjoin(workdir, 'wal')

    g.cluster.servers[1].env['TARANTOOL_WORKDIR'] = cartridge_workdir
    g.cluster.servers[1].env['TARANTOOL_VINYL_DIR'] = vinyl_dir
    g.cluster.servers[1].env['TARANTOOL_MEMTX_DIR'] = memtx_dir
    g.cluster.servers[1].env['TARANTOOL_WAL_DIR'] = wal_dir
    g.cluster:start()

    t.assert_items_equals(fio.listdir(workdir), {
        'wal', 'cartridge', 'memtx', 'vinyl'
    })

    t.assert_items_equals(fio.listdir(cartridge_workdir), {
        '.tarantool.cookie', 'config'
    })

    t.assert_equals(fio.listdir(memtx_dir), {'00000000000000000000.snap'})
    t.assert_equals(fio.listdir(wal_dir), {'00000000000000000000.xlog'})
end


function g.test_box_dirs_relative_path()
    g.cluster.servers[1].env['TARANTOOL_VINYL_DIR'] = './vinyl'
    g.cluster.servers[1].env['TARANTOOL_MEMTX_DIR'] = './memtx'
    g.cluster.servers[1].env['TARANTOOL_WAL_DIR'] = 'wal'

    g.cluster:start()

    local workdir = g.cluster.main_server.workdir
    t.assert_items_equals(fio.listdir(workdir), {
        'wal', 'config', 'memtx', 'vinyl', '.tarantool.cookie'
    })

    t.assert_equals(fio.listdir(fio.pathjoin(workdir, 'memtx')), {'00000000000000000000.snap'})
    t.assert_equals(fio.listdir(fio.pathjoin(workdir, 'wal')), {'00000000000000000000.xlog'})
end

function g.test_box_work_dir()
    local box_workdir = fio.pathjoin(g.cluster:server('main').workdir, 'box')
    g.cluster.servers[1].env['TARANTOOL_WORK_DIR'] = box_workdir
    g.cluster.servers[1].env['TARANTOOL_VINYL_DIR'] = './vinyl'
    g.cluster.servers[1].env['TARANTOOL_MEMTX_DIR'] = './memtx'
    g.cluster.servers[1].env['TARANTOOL_WAL_DIR'] = 'wal'

    g.cluster:start()

    local workdir = g.cluster.main_server.workdir
    t.assert_items_equals(fio.listdir(workdir), {
        'box', 'config', '.tarantool.cookie'
    })

    t.assert_equals(fio.listdir(fio.pathjoin(box_workdir, 'memtx')), {'00000000000000000000.snap'})
    t.assert_equals(fio.listdir(fio.pathjoin(box_workdir, 'wal')), {'00000000000000000000.xlog'})
end
