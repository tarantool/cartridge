local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {{
            alias = 'A',
            roles = {},
            servers = 3,
        }},
    })
    g.cluster:start()

    g.A1 = g.cluster:server('A-1')
    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.A1), {})
    end)

    g.r1_uuid = g.A1.net_box:eval('return box.space._cluster:get(1).uuid')
    g.r2_uuid = g.A1.net_box:eval('return box.space._cluster:get(2).uuid')
    g.r3_uuid = g.A1.net_box:eval('return box.space._cluster:get(3).uuid')

    -- Expel the second server, the gap is important for the test.
    local expelled = helpers.table_find_by_attr(
        g.cluster.servers, 'instance_uuid', g.r2_uuid
    )

    expelled:stop()
    g.A1.net_box:eval([[
        package.loaded.cartridge.admin_edit_topology({servers = {{
            uuid = ...,
            expelled = true,
        }}})

        box.space._cluster.index.uuid:delete(...)
    ]], {expelled.instance_uuid})

end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

function g.test_api()
    local ret = g.A1.net_box:eval('return box.info.replication')
    t.assert_covers(ret[1], {id = 1, uuid = g.r1_uuid}, ret)
    t.assert_covers(ret[3], {id = 3, uuid = g.r3_uuid}, ret)
    t.assert_equals(ret[2], nil, ret)

    local ret = g.A1:graphql({
        query = [[ query($uuid: String!) {
            servers(uuid: $uuid) {
                boxinfo { replication { replication_info {
                    id
                    upstream_peer
                    upstream_status
                    downstream_status
                }}}
            }
        }]],
        variables = {uuid = g.r3_uuid},
    }).data.servers[1].boxinfo.replication.replication_info

    t.assert_equals(ret, {
        [1] = {
            id = 1,
            upstream_peer = "admin@" .. g.A1.advertise_uri,
            upstream_status = "follow",
            downstream_status = "follow",
        },
        [2] = box.NULL,
        [3] = {
            id = 3,
            upstream_peer = box.NULL,
            upstream_status = box.NULL,
            downstream_status = box.NULL,
        },
    })
end
