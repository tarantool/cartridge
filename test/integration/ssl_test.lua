local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local cartridge_utils = require('cartridge.utils')

local CERT_DIR = fio.pathjoin(fio.abspath(os.getenv('SOURCEDIR') or '.'),
                              'test/integration/ssl_cert')
local CA_FILE = fio.pathjoin(CERT_DIR, 'ca.crt')
local SERVER_CERT_FILE = fio.pathjoin(CERT_DIR, 'server.crt')
local SERVER_KEY_FILE = fio.pathjoin(CERT_DIR, 'server.key')
local CLIENT_CERT_FILE = fio.pathjoin(CERT_DIR, 'client.crt')
local CLIENT_KEY_FILE = fio.pathjoin(CERT_DIR, 'client.key')

g.before_all = function()
    if type(cartridge_utils.feature) ~= 'table' then
        t.skip("No SSL support")
    end
    if not cartridge_utils.feature.ssl then
        t.skip("No SSL support")
    end

    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        cookie = helpers.random_cookie(),
        use_vshard = true,
        replicasets = {
            {
                uuid = helpers.uuid('a'),
                roles = {'vshard-router'},
                servers = {{
                    alias = 'A1',
                    instance_uuid = helpers.uuid('a', 'a', 1),
                    advertise_port = 13301,
                    http_port = 8081,
                    transport = 'ssl',
                    ssl_server_ca_file = CA_FILE,
                    ssl_server_cert_file = SERVER_CERT_FILE,
                    ssl_server_key_file = SERVER_KEY_FILE,

                    ssl_client_ca_file = CA_FILE,
                    ssl_client_cert_file = CLIENT_CERT_FILE,
                    ssl_client_key_file = CLIENT_KEY_FILE,
                }}
            }, {
                uuid = helpers.uuid('b'),
                roles = {'myrole', 'vshard-storage'},
                servers = {
                    {
                        alias = 'B1',
                        instance_uuid = helpers.uuid('b', 'b', 1),
                        advertise_port = 13302,
                        http_port = 8082,

                        transport = 'SSL',
                        ssl_server_ca_file = CA_FILE,
                        ssl_server_cert_file = SERVER_CERT_FILE,
                        ssl_server_key_file = SERVER_KEY_FILE,

                        ssl_client_ca_file = CA_FILE,
                        ssl_client_cert_file = CLIENT_CERT_FILE,
                        ssl_client_key_file = CLIENT_KEY_FILE,
                    },{
                        alias = 'B2',
                        instance_uuid = helpers.uuid('b', 'b', 2),
                        advertise_port = 13303,
                        http_port = 8083,

                        transport = 'ssl',
                        ssl_server_ca_file = CA_FILE,
                        ssl_server_cert_file = SERVER_CERT_FILE,
                        ssl_server_key_file = SERVER_KEY_FILE,

                        ssl_client_ca_file = CA_FILE,
                        ssl_client_cert_file = CLIENT_CERT_FILE,
                        ssl_client_key_file = CLIENT_KEY_FILE,
                    }
                }
            }, {
                uuid = helpers.uuid('c'),
                roles = {'myrole', 'vshard-storage'},
                servers = {
                    {
                        alias = 'C1',
                        instance_uuid = helpers.uuid('c', 'c', 1),
                        advertise_port = 13304,
                        http_port = 8084,

                        transport = 'ssl',
                        ssl_server_ca_file = CA_FILE,
                        ssl_server_cert_file = SERVER_CERT_FILE,
                        ssl_server_key_file = SERVER_KEY_FILE,

                        ssl_client_ca_file = CA_FILE,
                        ssl_client_cert_file = CLIENT_CERT_FILE,
                        ssl_client_key_file = CLIENT_KEY_FILE,
                    },{
                        alias = 'C2',
                        instance_uuid = helpers.uuid('c', 'c', 2),
                        advertise_port = 13305,
                        http_port = 8085,

                        transport = 'ssl',
                        ssl_server_ca_file = CA_FILE,
                        ssl_server_cert_file = SERVER_CERT_FILE,
                        ssl_server_key_file = SERVER_KEY_FILE,

                        ssl_client_ca_file = CA_FILE,
                        ssl_client_cert_file = CLIENT_CERT_FILE,
                        ssl_client_key_file = CLIENT_KEY_FILE,
                    }
                }
            }
        }
    })
    local ok, err = pcall(g.cluster.start, g.cluster)
    t.xfail_if(not ok, 'Flaky test')
    t.assert(ok, err)
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end


local function rpc_call(server, role_name, fn_name, args, kv_args)
    local res, err = server:eval([[
        local rpc = require('cartridge.rpc')
        return rpc.call(...)
    ]], {role_name, fn_name, args, kv_args})
    return res, err
end

local function get_box_info_using_vshard(srv, bucket)
    return srv:eval(
        'return require("vshard").router.callro(...)',
        {bucket, 'box.info', {}}
    )
end

function g.test_ssl_rpc_vshard()
    local A1 = g.cluster:server('A1')
    local B1 = g.cluster:server('B1')
    local C1 = g.cluster:server('C1')

    local res, err = rpc_call(A1, 'myrole', 'get_state', {}, {})
    t.assert_not(err)
    t.assert_equals(res, 'initialized')
    local res, err = rpc_call(B1, 'myrole', 'get_state', {}, {})
    t.assert_not(err)
    t.assert_equals(res, 'initialized')
    local res, err = rpc_call(C1, 'myrole', 'get_state', {}, {})
    t.assert_not(err)
    t.assert_equals(res, 'initialized')

    local _, err = get_box_info_using_vshard(A1, 1)
    t.assert_not(err)

    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(A1), {})
    end)
end
