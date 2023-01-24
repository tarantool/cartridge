local fio = require('fio')
local t = require('luatest')
local helpers = require('test.helper')

local etcd2_client = require('cartridge.etcd2-client')
local stateboard_client = require('cartridge.stateboard-client')

local g_etcd2 = t.group('integration.failover_stateful.etcd2_two_clusters_one_state_provider')
local g_stateboard = t.group('integration.failover_stateful.stateboard_two_clusters_one_state_provider')

local function setup_cluster(g, cookies)
    g.clusters = {}
    for i, v in ipairs(cookies) do
        local cluster = helpers.Cluster:new({
            datadir = g.datadir,
            server_command = helpers.entrypoint('srv_basic'),
            cookie = v,
            replicasets = {
                {
                    alias = 'core-' .. i,
                    roles = {'failover-coordinator'},
                    servers = {
                        {
                            alias = 'core-' .. i,
                            http_port = 8080 + i,
                            advertise_port = 13300 + i,
                        },
                    },
                },
                {
                    alias = 'server-' .. i,
                    roles = {'failover-coordinator'},
                    servers = {
                        {
                            alias = 'server-' .. i,
                            http_port = 8090 + i,
                            advertise_port = 13400 + i,
                        },
                    },
                },
            },
        })
        cluster:start()
        g.clusters[i] = cluster
    end
end

g_stateboard.setup_cluster = setup_cluster
g_etcd2.setup_cluster = setup_cluster

function g_stateboard.setup_failover(g, cluster, check_cookie_hash)
    return cluster.main_server:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            mode = 'stateful',
            state_provider = 'tarantool',
            check_cookie_hash = check_cookie_hash ~= false,
            tarantool_params = {
                uri = g.state_provider.net_box_uri,
                password = g.kvpassword,
            },
        }}
    )
end

g_stateboard.before_each(function()
    local g = g_stateboard
    g.type = 'stateboard'
    g.datadir = fio.tempdir()

    g.kvpassword = helpers.random_cookie()
    g.state_provider = helpers.Stateboard:new({
        command = helpers.entrypoint('srv_stateboard'),
        workdir = fio.pathjoin(g.datadir, 'stateboard'),
        net_box_port = 14401,
        net_box_credentials = {
            user = 'client',
            password = g.kvpassword,
        },
        env = {
            TARANTOOL_LOCK_DELAY = 2,
            TARANTOOL_PASSWORD = g.kvpassword,
        },
    })

    g.state_provider:start()
    g.client = stateboard_client.new({
        uri = 'localhost:' .. g.state_provider.net_box_port,
        password = g.kvpassword,
        call_timeout = 1,
    })
end)


local --[[const]] URI = 'http://127.0.0.1:14001'

function g_etcd2.setup_failover(_, cluster, check_cookie_hash)
    return cluster.main_server:call(
        'package.loaded.cartridge.failover_set_params',
        {{
            mode = 'stateful',
            state_provider = 'etcd2',
            check_cookie_hash = check_cookie_hash ~= false,
            etcd2_params = {
                prefix = 'failover_stateful_test',
                endpoints = {URI},
                lock_delay = 3,
            },
        }}
    )
end

g_etcd2.before_each(function()
    local g = g_etcd2
    g.type = 'etcd'
    local etcd_path = os.getenv('ETCD_PATH')
    t.skip_if(etcd_path == nil, 'etcd missing')

    g.datadir = fio.tempdir()
    g.state_provider = helpers.Etcd:new({
        workdir = fio.tempdir('/tmp'),
        etcd_path = etcd_path,
        peer_url = 'http://127.0.0.1:17001',
        client_url = 'http://127.0.0.1:14001',
    })

    g.state_provider:start()
    g.client = etcd2_client.new({
        prefix = 'failover_stateful_test',
        endpoints = {URI},
        lock_delay = 3,
        username = '',
        password = '',
        request_timeout = 1,
    })
    g.client:get_session().connection:request('DELETE', '/identification_str')
end)

local function after_each(g)
    for _, v in pairs(g.clusters) do
        v:stop()
    end

    g.state_provider:stop()
    fio.rmtree(g.state_provider.workdir)

    fio.rmtree(g.datadir)
end

g_stateboard.after_each(function() after_each(g_stateboard) end)
g_etcd2.after_each(function() after_each(g_etcd2) end)

local function add(name, fn)
    g_stateboard[name] = function() return fn(g_stateboard) end
    g_etcd2[name] = function() return fn(g_etcd2) end
end

add('test_same_state_provider', function(g)
    local cookie1 = helpers.random_cookie()
    local cookie2 = helpers.random_cookie()

    g:setup_cluster{cookie1, cookie2}
    local ok, err = g:setup_failover(g.clusters[1])
    t.assert(ok, err)

    local ok, err = g:setup_failover(g.clusters[2])
    t.assert(ok, err)

    t.assert_items_include(helpers.list_cluster_issues(g.clusters[1].main_server), {})
    t.assert_items_include(helpers.list_cluster_issues(g.clusters[2].main_server), {{
        level = 'error',
        topic = 'failover',
        message = "Cookie hash check errored: " ..
            (g.type == 'etcd' and 'Prefix failover_stateful_test already used by another Cartridge cluster'
            or '"localhost:14401": Someone else already uses this stateboard'),
        instance_uuid = box.NULL,
        replicaset_uuid = box.NULL,
    }})
end)

add('test_same_state_provider_check_disabled', function(g)
    local cookie1 = helpers.random_cookie()
    local cookie2 = helpers.random_cookie()

    g:setup_cluster{cookie1, cookie2}
    local ok, err = g:setup_failover(g.clusters[1], false)
    t.assert(ok, err)

    local ok, err = g:setup_failover(g.clusters[2], false)
    t.assert(ok, err)

    t.assert_items_include(helpers.list_cluster_issues(g.clusters[1].main_server), {})
    t.assert_items_include(helpers.list_cluster_issues(g.clusters[2].main_server), {})
end)

add('test_restart', function(g)
    local cookie1 = helpers.random_cookie()

    g:setup_cluster{cookie1}
    local ok, err = g:setup_failover(g.clusters[1])
    t.assert(ok, err)

    g.clusters[1]:restart()
    t.assert_items_include(helpers.list_cluster_issues(g.clusters[1].main_server), {})
end)

add('test_change_cookie', function(g)
    local cookie1 = helpers.random_cookie()
    local cookie2 = helpers.random_cookie()

    g:setup_cluster{cookie1}
    local ok, err = g:setup_failover(g.clusters[1])
    t.assert(ok, err)

    g.clusters[1].main_server:exec(function()
        local cluster_cookie = require('cartridge.cluster-cookie')
        rawset(_G, '_old_cookie_hash', cluster_cookie.get_cookie_hash())
    end)

    for _, v in ipairs(g.clusters[1].servers) do
        v:exec(function(new_cookie)
            local cluster_cookie = require('cartridge.cluster-cookie')

            cluster_cookie.set_cookie(new_cookie)

            require('membership').set_encryption_key(cluster_cookie.cookie())

            if require('cartridge.failover').is_leader() then
                box.schema.user.passwd(new_cookie)
            end
        end, {cookie2})
    end

    t.assert(g.clusters[1].main_server:exec(function()
        local old_hash = rawget(_G, '_old_cookie_hash')
        local cluster_cookie = require('cartridge.cluster-cookie')

        require('cartridge.vars').new('cartridge.failover').client:set_identification_string(
            cluster_cookie.get_cookie_hash(), old_hash)

        local confapplier = require('cartridge.confapplier')
        local clusterwide_config = confapplier.get_active_config()
        return confapplier.apply_config(clusterwide_config)
    end))
    t.assert_items_include(helpers.list_cluster_issues(g.clusters[1].main_server), {})
end)
