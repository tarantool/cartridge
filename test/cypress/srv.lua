local fio = require('fio')
local helpers = require('cartridge.test-helpers')
local test_helper = require('test.helper')


local cluster = helpers.Cluster:new({
    datadir = fio.tempdir(),
    server_command = test_helper.server_command,
    use_vshard = true,
    cookie = 'test-cluster-cookie',

    replicasets = {
        {
            uuid = helpers.uuid('a'),
            roles = {'vshard-router'},
            servers = {
                {
                    alias = 'router',
                    instance_uuid = helpers.uuid('a', 'a', 1),
                    advertise_port = 33001,
                    http_port = 8081
                }
            }
        }, {
            uuid = helpers.uuid('b'),
            roles = {'vshard-storage'},
            servers = {
                {
                    alias = 'storage',
                    instance_uuid = helpers.uuid('b', 'b', 1),
                    advertise_port = 33002,
                    http_port = 8082
                }, {
                    alias = 'storage-2',
                    instance_uuid = helpers.uuid('b', 'b', 2),
                    advertise_port = 33004,
                    http_port = 8084
                }
            }
        }
    }
})

cluster:start()
