local fio = require('fio')
local t = require('luatest')
local g = t.group()

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
                        advertise_port = 13301,
                        http_port = 8081
                    }
                }
            }, {
                uuid = helpers.uuid('b'),
                roles = {'vshard-storage'},
                servers = {
                    {
                        alias = 'storage-1',
                        instance_uuid = helpers.uuid('b', 'b', 1),
                        advertise_port = 13302,
                        http_port = 8082
                    }, {
                        alias = 'storage-2',
                        instance_uuid = helpers.uuid('b', 'b', 2),
                        advertise_port = 13304,
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
                        advertise_port = 13309,
                        http_port = 8089
                    }
                }
            }
        }
    })

    g.cluster:start()

    g.cluster:server('expelled'):stop()
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

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function set_all_rw(replicaset_uuid, all_rw)
    g.cluster:server('router'):graphql({
        query = [[
            mutation($uuid: String!, $all_rw: Boolean!) {
                edit_replicaset(
                    uuid: $uuid
                    all_rw: $all_rw
                )
            }
        ]],
        variables = {
            uuid = replicaset_uuid,
            all_rw = all_rw,
        }
    })
end

g.setup = function()
    pcall(set_all_rw, helpers.uuid('b'), false)
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
        edit_server_req,
        {
            uuid = helpers.uuid('a', 'a', 1),
            uri = 'localhost:3303'
        }
    )

    t.assert_error_msg_contains(
        'Server "cccccccc-cccc-0000-0000-000000000001" is expelled',
        edit_server_req,
        {
            uuid = helpers.uuid('c', 'c', 1),
            uri = 'localhost:3303'
        }
    )

    t.assert_error_msg_contains(
        'Server "dddddddd-dddd-0000-0000-000000000001" not in config',
        edit_server_req,
        {
            uuid = helpers.uuid('d', 'd', 1),
            uri = 'localhost:3303'
        }
    )
end


function g.test_edit_replicaset()
    local router = g.cluster:server('router')
    local storage = g.cluster:server('storage-1')

    router:graphql({
        query = [[
            mutation {
                edit_replicaset(
                    uuid: "bbbbbbbb-0000-0000-0000-000000000000"
                    roles: ["vshard-router", "vshard-storage"]
                )
            }
        ]]
    })

    t.assert_error_msg_contains(
        string.format(
            [[replicasets[%s] leader "%s" doesn't exist]],
            helpers.uuid('b'), helpers.uuid('b', 'b', 3)
        ),
        function()
            router:graphql({
                query = [[mutation {
                    edit_replicaset(
                        uuid: "bbbbbbbb-0000-0000-0000-000000000000"
                        master: ["bbbbbbbb-bbbb-0000-0000-000000000003"]
                    )
                }]]
            })
        end
    )

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

    change_weight_req({weight = 2})
    t.assert_error_msg_contains(
        [[replicasets[bbbbbbbb-0000-0000-0000-000000000000].weight]] ..
        [[ must be non-negative, got -100]],
        change_weight_req,
        {weight = -100}
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

    t.assert_equals(#replicasets, 1)
    t.assert_equals(replicasets[1], {
        uuid = helpers.uuid('b'),
        roles = {'vshard-storage', 'vshard-router'},
        status = 'healthy',
        weight = 2,
        all_rw = false,
        servers = {{uri = 'localhost:13302'}, {uri = 'localhost:13304'}}
    })

    router:graphql({
        query = [[mutation {
            edit_replicaset(
                uuid: "bbbbbbbb-0000-0000-0000-000000000000"
                all_rw: true
            )
        }]]
    })

    local resp = get_replicaset()
    local replicasets = resp['data']['replicasets']

    t.assert_equals(#replicasets, 1)
    t.assert_equals(replicasets[1], {
        uuid = helpers.uuid('b'),
        roles = {'vshard-storage', 'vshard-router'},
        status = 'healthy',
        weight = 2,
        all_rw = true,
        servers = {{uri = 'localhost:13302'}, {uri = 'localhost:13304'}}
    })
end


local function test_all_rw(all_rw)
    set_all_rw(helpers.uuid('b'), all_rw)

    local router = g.cluster:server('router')
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

    t.assert_equals(#resp['data']['replicasets'], 1)

    local replicaset = resp['data']['replicasets'][1]

    t.assert_equals(replicaset['all_rw'], all_rw)

    for _, srv in pairs(replicaset['servers']) do
        if srv['uuid'] == replicaset['master']['uuid'] then
            t.assert_equals(srv['boxinfo']['general']['ro'], false)
        else
            t.assert_equals(srv['boxinfo']['general']['ro'], not all_rw)
        end
    end
end


function g.test_all_rw_false()
    test_all_rw(false)
end

function g.test_all_rw_true()
    test_all_rw(true)
end
