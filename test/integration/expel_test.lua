local fio = require('fio')
local fun = require('fun')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        replicasets = {{
            alias = 'A',
            roles = {},
            servers = 3,
        }, {
            alias = 'B',
            roles = {},
            servers = 1,
        }},
    })
    g.cluster:start()

    g.A1 = g.cluster:server('A-1')
    helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.A1), {})
    end)

    g.r1_uuid = g.A1:eval('return box.space._cluster:get(1).uuid')
    g.r2_uuid = g.A1:eval('return box.space._cluster:get(2).uuid')
    g.r3_uuid = g.A1:eval('return box.space._cluster:get(3).uuid')

    -- Expel the second server, the gap is important for the test.
    local expelled = helpers.table_find_by_attr(
        g.cluster.servers, 'instance_uuid', g.r2_uuid
    )

    expelled:stop()
    g.A1:exec(function(uuid1, uuid2)
        package.loaded.cartridge.admin_edit_topology({servers = {{
            uuid = uuid1,
            expelled = true,
        }, {
            uuid = uuid2,
            expelled = true,
        }}})
    end, {expelled.instance_uuid, g.cluster:server('B-1').instance_uuid})
    g.expelled_uri = expelled.advertise_uri
    g.A1:call('package.loaded.cartridge.admin_edit_topology',
        {{servers = {{uuid = expelled.instance_uuid, expelled = true}}}})

    g.standalone = helpers.Server:new({
        alias = 'standalone',
        workdir = fio.pathjoin(g.cluster.datadir, 'standalone'),
        command = helpers.entrypoint('srv_basic'),
        cluster_cookie = g.cluster.cookie,
        advertise_port = 13300,
        http_port = 8080,
        replicaset_uuid = helpers.uuid('b'),
        instance_uuid = helpers.uuid('b', 'b', 1),
    })
    g.standalone:start()
end)

g.after_all(function()
    g.cluster:stop()
    g.standalone:stop()
    fio.rmtree(g.cluster.datadir)
end)

local function check_members(g, expected)
    local to_check = fun.iter(expected):map(function(x) return x end):totable()
    table.sort(to_check)
    t.helpers.retrying({}, function()
        local res = g.A1:exec(function()
            local fun = require('fun')
            local membership = require('membership')
            local members = fun.iter(membership.members()):
                map(function(x) return x end):totable()
            table.sort(members)
            return members
        end)
        t.assert_equals(res, to_check)
    end)
end

function g.test_api()
    local ret = g.A1:eval('return box.info.replication')
    t.assert_covers(ret[1], {id = 1, uuid = g.r1_uuid}, ret)
    t.assert_covers(ret[3], {id = 3, uuid = g.r3_uuid}, ret)
    t.assert_equals(ret[2], nil, ret)

    t.helpers.retrying({}, function()
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
    end)

    -- Check explicitly that expelled leader is not in _cluster. Just in case.
    t.assert_items_equals(
        g.A1.net_box.space._cluster:select(),
        {{1, g.r1_uuid}, {3, g.r3_uuid}}
    )

    local expected = {
        -- second instance is space _cluster is expelled:
        [g.cluster:server('A-1').advertise_uri] = true,
        [g.cluster:server('A-2').advertise_uri] = true,
        [g.cluster:server('A-3').advertise_uri] = true,
        -- expelled, but not stopped:
        [g.cluster:server('B-1').advertise_uri] = true,
        -- not in the cluster:
        [g.standalone.advertise_uri] = true,
    }
    table.sort(expected)

    check_members(g, expected)

    g.A1.env['TARANTOOL_EXCLUDE_EXPELLED_MEMBERS'] = 'true'
    g.A1:restart()

    -- now every instance except expelled and stopped should remain in membership 
    expected[g.expelled_uri] = nil
    check_members(g, expected)
end
