#!/usr/bin/env tarantool
-- This script is used to generate testing data (snapshots).
-- Run it whenever you want to write test for new upgrade scenario

local fio = require('fio')
local helpers = require('test.helper')

local datadir = fio.pathjoin(
    helpers.project_root,
    'test/upgrade/data_' .. string.match(_TARANTOOL, '^(.-)%-')
)

fio.rmtree(datadir)

local cluster = helpers.Cluster:new({
    datadir = datadir,
    server_command = helpers.entrypoint('srv_basic'),
    use_vshard = true,
    cookie = 'tmp',
    env = {
        TARANTOOL_CHECKPOINT_COUNT = '1',
    },
    replicasets = {{
        uuid = helpers.uuid('a'),
        roles = {'vshard-router'},
        servers = {{
            alias = 'router',
            instance_uuid = helpers.uuid('a', 'a', 1),
            advertise_port = 13301,
        }},
    }, {
        uuid = helpers.uuid('b'),
        roles = {'vshard-storage'},
        servers = {{
            alias = 'storage-1',
            instance_uuid = helpers.uuid('b', 'b', 1),
            advertise_port = 13303,
        }, {
            alias = 'storage-2',
            instance_uuid = helpers.uuid('b', 'b', 2),
            advertise_port = 13305,
        }},
    }},
})

cluster:start()

for _, srv in pairs(cluster.servers) do
    srv.net_box:call('box.snapshot')
end

cluster:stop()
os.exit(1)
