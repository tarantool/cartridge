local fio = require('fio')
local t = require('luatest')
local g = t.group('api_edit')

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
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
            }, {
                uuid = helpers.uuid('c'),
                roles = {},
                servers = {
                    {
                        alias = 'expelled',
                        instance_uuid = helpers.uuid('c', 'c', 1),
                        advertise_port = 33009,
                        http_port = 8089
                    }
                }
            }
        }
    })

    g.server = helpers.Server:new({
        workdir = fio.tempdir(),
        alias = 'spare',
        command = test_helper.server_command,
        replicaset_uuid = helpers.uuid('d'),
        instance_uuid = helpers.uuid('d', 'd', 1),
        http_port = 8083,
        cluster_cookie = g.cluster.cookie,
        advertise_port = 33003
    })

    g.cluster:start()

    g.server:start()
    t.helpers.retrying({timeout = 5}, function()
        g.server:graphql({query = '{}'})
    end)

    g.expel_server = function(name)
        g.cluster:server(name):stop()
        g.cluster:server('router'):graphql({
            query = [[
                mutation($uuid: String!) {
                    expel_server(uuid: $uuid)
                }
            ]],
            variables = {
                uuid = g.cluster:server('expelled').instance_uuid
            }
        })
    end
    g.expel_server('expelled')
end

g.after_all = function()
    g.cluster:stop()
    g.server:stop()
    fio.rmtree(g.cluster.datadir)
    fio.rmtree(g.server.workdir)
end

g.setup = function()
    pcall(function()
        g.cluster:server('router'):graphql({
            query = [[
                mutation($uuid: String!, $all_rw: Boolean!) {
                    edit_replicaset(
                        uuid: $uuid
                        all_rw: $all_rw
                    )
                }
            ]],
            variables = {uuid = helpers.uuid('b'), all_rw = false}
        })
    end)

    pcall(g.expel_server, 'spare')
end


local function find_in_arr(arr, key, value)
    for _, v in pairs(arr) do
        if v[key] == value then
            return v
        end
    end
end


function g.test_edit_server()
    local edit_server_req = function(vars)
        return g.cluster:server('router'):graphql({
            query = [[
                mutation($uuid: String! $uri: String!) {
                    edit_server(
                        uuid: $uuid
                        uri: $uri
                    )
                }
            ]],
            variables = vars
        })
    end

    t.assert_error_msg_contains(
        'Server "localhost:3303" is not in membership',
        edit_server_req, {uuid = helpers.uuid('a', 'a', 1), uri = 'localhost:3303'}
    )

    t.assert_error_msg_contains(
        'Server "cccccccc-cccc-0000-0000-000000000001" is expelled',
        edit_server_req, {uuid = helpers.uuid('c', 'c', 1), uri = 'localhost:3303'}
    )

    t.assert_error_msg_contains(
        'Server "dddddddd-dddd-0000-0000-000000000001" not in config',
        edit_server_req, {uuid = helpers.uuid('d', 'd', 1), uri = 'localhost:3303'}
    )
end


function g.test_edit_replicaset()
    local router = g.cluster:server('router')
    local storage = g.cluster:server('storage')
    local resp = router:graphql({
        query = [[
            mutation {
                edit_replicaset(
                    uuid: "bbbbbbbb-0000-0000-0000-000000000000"
                    roles: ["vshard-router", "vshard-storage"]
                )
            }
        ]]
    })

    local change_weight_req = function(vars)
        return router:graphql({
            query = [[
                mutation($weight: Float!) {
                    edit_replicaset(
                        uuid: "bbbbbbbb-0000-0000-0000-000000000000"
                        weight: $weight
                    )
                }
            ]],
            variables = vars
        })
    end

    local resp = change_weight_req({weight = 2})

    local change_master_req = function()
        router:graphql({
            query = [[
                mutation {
                    edit_replicaset(
                        uuid: "bbbbbbbb-0000-0000-0000-000000000000"
                        master: ["bbbbbbbb-bbbb-0000-0000-000000000003"]
                    )
                }
            ]]
        })
    end

    t.assert_error_msg_contains(
        string.format(
            "replicasets[%s] leader \"%s\" doesn't exist",
            helpers.uuid('b'), helpers.uuid('b', 'b', 3)
        ), change_master_req
    )

    t.assert_error_msg_contains(
        'replicasets[bbbbbbbb-0000-0000-0000-000000000000].weight must be non-negative, got -100',
        change_weight_req, {weight = -100}
    )

    local get_replicaset = function()
        return storage:graphql({
            query = [[{
                replicasets(uuid: "bbbbbbbb-0000-0000-0000-000000000000") {
                    uuid
                    roles
                    status
                    servers { uri }
                    weight
                    all_rw
                }
            }]]
        })
    end

    local resp = get_replicaset()
    local replicasets = resp['data']['replicasets']

    t.assert_equals(table.getn(replicasets), 1)
    t.assert_equals(replicasets[1], {
        uuid = helpers.uuid('b'),
        roles = {'vshard-storage', 'vshard-router'},
        status = 'healthy',
        weight = 2,
        all_rw = false,
        servers = {{uri = 'localhost:33002'}, {uri = 'localhost:33004'}}
    })

    local resp = router:graphql({
        query = [[
            mutation {
                edit_replicaset(
                    uuid: "bbbbbbbb-0000-0000-0000-000000000000"
                    all_rw: true
                )
            }
        ]]
    })

    local resp = get_replicaset()
    local replicasets = resp['data']['replicasets']

    t.assert_equals(table.getn(replicasets), 1)
    t.assert_equals(replicasets[1], {
        uuid = helpers.uuid('b'),
        roles = {'vshard-storage', 'vshard-router'},
        status = 'healthy',
        weight = 2,
        all_rw = true,
        servers = {{uri = 'localhost:33002'}, {uri = 'localhost:33004'}}
    })
end


local function allow_read_write(all_rw)
    local router = g.cluster:server('router')
    local resp = router:graphql({
        query = [[
            mutation($uuid: String!, $all_rw: Boolean!) {
                edit_replicaset(
                    uuid: $uuid
                    all_rw: $all_rw
                )
            }
        ]],
        variables = {uuid = helpers.uuid('b'), all_rw = all_rw}
    })

    local resp = router:graphql({
        query = [[{
            replicasets(uuid: "bbbbbbbb-0000-0000-0000-000000000000") {
                all_rw
                servers {
                    uuid
                    boxinfo {
                        general { ro }
                    }
                }
                master {
                    uuid
                }
            }
        }]]
    })

    t.assert_equals(table.getn(resp['data']['replicasets']), 1)

    local replicaset = resp['data']['replicasets'][1]

    t.assert_equals(replicaset['all_rw'], all_rw)

    for _, srv in pairs(replicaset['servers']) do
        if srv['uuid'] == replicaset['master']['uuid'] then
            t.assert_false(srv['boxinfo']['general']['ro'])
        else
            t.assert_equals(srv['boxinfo']['general']['ro'], not all_rw)
        end
    end
end


function g.test_all_rw_false()
    allow_read_write(false)
end


function g.test_all_rw_true()
    allow_read_write(true)
end


function g.test_join_server()
    local router = g.cluster:server('router')
    local resp = router:graphql({
        query = [[
            mutation {
                probe_server(
                    uri: "localhost:33003"
                )
        }]]
    })

    t.assert_true(resp['data']['probe_server'])

    local join_server_req = function()
        return router:graphql({
            query = [[
                mutation {
                    join_server(
                        uri: "localhost:33003"
                        instance_uuid: "cccccccc-cccc-0000-0000-000000000001"
                    )
                }
            ]]
        })
    end

    t.assert_error_msg_contains(
        'Server "cccccccc-cccc-0000-0000-000000000001" is already joined',
        join_server_req
    )

    local join_server_req = function()
        return router:graphql({
            query = [[
                mutation {
                    join_server(
                        uri: "localhost:33003"
                        instance_uuid: "dddddddd-dddd-0000-0000-000000000001"
                        replicaset_uuid: "dddddddd-0000-0000-0000-000000000000"
                        roles: ["vshard-storage"]
                        replicaset_weight: -0.3
                    )
                }
            ]]
        })
    end

    t.assert_error_msg_contains(
        'replicasets[dddddddd-0000-0000-0000-000000000000].weight' ..
        ' must be non-negative, got -0.3',
        join_server_req
    )

    local join_server_req = function()
        return router:graphql({
            query = [[
                mutation {
                    join_server(
                        uri: "localhost:33003"
                        instance_uuid: "dddddddd-dddd-0000-0000-000000000001"
                        replicaset_uuid: "dddddddd-0000-0000-0000-000000000000"
                        roles: ["vshard-storage"]
                        vshard_group: "unknown"
                    )
                }
            ]]
        })
    end

    t.assert_error_msg_contains(
        'replicasets[dddddddd-0000-0000-0000-000000000000] can\'t be added' ..
        ' to vshard_group "unknown", cluster doesn\'t have any',
        join_server_req
    )

    local resp = router:graphql({
        query = [[
            mutation {
                join_server(
                    uri: "localhost:33003"
                    instance_uuid: "dddddddd-dddd-0000-0000-000000000001"
                    replicaset_uuid: "dddddddd-0000-0000-0000-000000000000"
                    replicaset_alias: "spare-set"
                    roles: ["vshard-storage"]
                )
            }
        ]]
    })

    t.helpers.retrying({timeout = 5, delay = 0.1}, function()
         g.server:graphql({query = '{}'})
    end)

    t.helpers.retrying({timeout = 5, delay = 0.1}, function()
        router.net_box:eval([[
            local cartridge = package.loaded['cartridge']
            return assert(cartridge) and assert(cartridge.is_healthy())
        ]])
    end)

    local resp = router:graphql({
        query = [[
            {
                servers {
                    uri
                    uuid
                    status
                    replicaset { alias uuid status roles weight }
                }
            }
        ]]
    })

    local servers = resp['data']['servers']

    t.assert_equals(table.getn(servers), 4)

    t.assert_equals(find_in_arr(servers, 'uuid', 'dddddddd-dddd-0000-0000-000000000001'),{
        uri = 'localhost:33003',
        uuid = 'dddddddd-dddd-0000-0000-000000000001',
        status = 'healthy',
        replicaset = {
            alias = 'spare-set',
            uuid = 'dddddddd-0000-0000-0000-000000000000',
            roles = {"vshard-storage"},
            status = 'healthy',
            weight = 0,
        }
    })
end
