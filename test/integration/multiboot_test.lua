local fio = require('fio')
local t = require('luatest')
local g = t.group('multiboot')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

function g:setup()
    self.datadir = fio.tempdir()

    self.servers = {}

    local function add_server(rn, sn)
        local id = string.format('%s%d', rn, sn)
        local http_port = 8080 + sn
        local advertise_port = 13310 + sn
        local alias = 'srv-' .. id

        self.servers[id] = helpers.Server:new({
            alias = alias,
            command = test_helper.server_command,
            workdir = fio.pathjoin(self.datadir, alias),
            cluster_cookie = 'test-cluster-cookie',
            http_port = http_port,
            advertise_port = advertise_port,
            instance_uuid = helpers.uuid(rn, rn, sn),
            replicaset_uuid = helpers.uuid(rn),
        })
    end

    add_server('a', 1)
    add_server('b', 2)
    add_server('b', 3)
    add_server('c', 4)

    for _, server in pairs(self.servers) do
        server:start()
    end

    for _, server in pairs(self.servers) do
        helpers.retrying({}, function() server:graphql({query = '{}'}) end)
    end
end

function g:teardown()
    for _, server in pairs(self.servers or {}) do
        server:stop()
    end

    fio.rmtree(self.datadir)
    self.servers = nil
end

function g:test_bootstrap()
    local a1 = self.servers['a1']
    local b2 = self.servers['b2']
    local b3 = self.servers['b3']

    local response = a1:graphql({
        query = [[
            mutation boot($replicasets: [EditReplicasetInput]) {
                cluster {
                    edit_topology(replicasets: $replicasets) {
                        replicasets {
                            status
                            uuid
                            roles
                            active_master {uri}
                            master {uri}
                            weight
                        }
                        servers {
                            status
                            uuid
                            uri
                            labels {name value}
                            boxinfo { general {pid} }
                        }
                    }
                }
            }
        ]],
        variables = {
            replicasets = {
                {
                    uuid = a1.replicaset_uuid,
                    join_servers = {{
                        uri = a1.advertise_uri,
                        uuid = a1.instance_uuid,
                        labels = {{name = 'addr', value = a1.advertise_uri}},
                    }},
                    failover_priority = {a1.instance_uuid},
                    roles = {"myrole", "vshard-router"},
                }, {
                    uuid = b2.replicaset_uuid,
                    join_servers = {{
                        uri = b2.advertise_uri,
                        labels = {{name = 'addr', value = b2.advertise_uri}},
                    }, {
                        uri = b3.advertise_uri,
                        labels = {{name = 'addr', value = b3.advertise_uri}},
                    }},
                    roles = {"vshard-storage"},
                }
            }
        }
    })

    local topology = response.data.cluster.edit_topology
    t.assert_items_equals(topology.replicasets, {
        {
            active_master = {uri = a1.advertise_uri},
            master = {uri = a1.advertise_uri},
            roles = {"vshard-router", "myrole-dependency", "myrole"},
            status = "healthy",
            uuid = a1.replicaset_uuid,
            weight = box.NULL,
        },
        {
            active_master = {uri = b2.advertise_uri},
            master = {uri = b2.advertise_uri},
            roles = {"vshard-storage"},
            status = "unhealthy",
            uuid = b2.replicaset_uuid,
            weight = 1
        }

    })
    t.assert_equals(topology.servers[1].uuid, a1.instance_uuid)

    local pids = {}
    for _, srv in pairs(topology.servers) do
        if srv.boxinfo ~= nil then
            pids[srv.uri] = srv.boxinfo.general.pid
        end
    end
    t.assert_items_equals(pids, {
        [a1.advertise_uri] = a1.process.pid,
        [b2.advertise_uri] = b2.process.pid,
        [b3.advertise_uri] = b3.process.pid,
    })
end
