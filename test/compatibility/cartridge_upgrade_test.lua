local fio = require('fio')
local log = require('log')
local fiber = require('fiber')
local errors = require('errors')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

local function version(srv)
    local version = srv:call('require', {'cartridge.VERSION'})
    local cwd = srv:call('package.loaded.fio.cwd')
    log.info('Check %s version: %s (from %s)', srv.alias, version, cwd)
    return version
end

local function upstream_info(srv)
    local info = srv:call('box.info')
    for _, v in pairs(info.replication) do
        if v.uuid ~= srv.instance_uuid then
            return {
                status = v.upstream.status,
                message = v.upstream.message,
            }
        end
    end
end

local function await_state(srv, desired_state)
    g.cluster:retrying({}, function()
        srv:eval([[
            local confapplier = require('cartridge.confapplier')
            local desired_state = ...
            local state = confapplier.wish_state(desired_state)
            assert(
                state == desired_state,
                string.format('Inappropriate state %q ~= desired %q',
                state, desired_state)
            )
        ]], {desired_state})
    end)
end

local cartridge_older_path = os.getenv('CARTRIDGE_OLDER_PATH')

--- Test upgrading form old version to the current one
local function change_version(old, new)
    t.skip_if(
        cartridge_older_path == nil,
        'No older version provided. Skipping'
    )
    ----------------------------------------------------------------------------
    -- Assemble cluster with old version

    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = fio.abspath(helpers.entrypoint('srv_basic')),
        cookie = helpers.random_cookie(),
        use_vshard = true,
        env = {TARANTOOL_FORBID_HOTRELOAD = 'true'},
        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {'vshard-router', 'vshard-storage'},
            servers = {{
                alias = 'leader',
                instance_uuid = helpers.uuid('a', 'a', 1),
                advertise_port = 13301,
                http_port = 8081,
                chdir = old,
            }, {
                alias = 'replica',
                instance_uuid = helpers.uuid('a', 'a', 2),
                advertise_port = 13302,
                http_port = 8082,
                chdir = old,
            }},
        }},
    })

    local leader = g.cluster:server('leader')
    local replica = g.cluster:server('replica')
    g.cluster.main_server = leader
    for _, srv in pairs(g.cluster.servers) do
        require('luatest.server').start(srv)
        g.cluster:retrying({}, function() srv:graphql({query = '{ servers { uri } }'}) end)
        srv:join_cluster(g.cluster.main_server)
        g.cluster:retrying({}, function() srv:connect_net_box() end)
    end
    g.cluster.main_server:setup_replicaset(g.cluster.replicasets[1])
    g.cluster:bootstrap_vshard()
    g.cluster:wait_until_healthy()

    if old ~= nil then
        t.assert_not_equals(version(leader), 'scm-1')
        t.assert_not_equals(version(replica), 'scm-1')
    else
        t.assert_equals(version(leader), 'scm-1')
        t.assert_equals(version(replica), 'scm-1')
    end

    ----------------------------------------------------------------------------
    -- Setup data model
    leader:eval([[
        box.schema.space.create('test', {
            format = {
                {name = 'bucket_id', type = 'unsigned', is_nullable = false},
                {name = 'record_id', type = 'unsigned', is_nullable = false},
                {name = 'alias', type = 'string', is_nullable = false},
            }
        })

        box.space.test:create_index('primary', {
            unique = true,
            parts = {{'record_id', 'unsigned', is_nullable = false}},
        })
        box.space.test:create_index('bucket_id', {
            unique = false,
            parts = {{'bucket_id', 'unsigned', is_nullable = false}},
        })
    ]])

    -- Start streaming
    local insertions_passed = {}
    local insertions_failed = {}
    local function _insert(cnt)
        local ret, err = g.cluster.main_server:eval([[
            local ret, err = package.loaded.vshard.router.callrw(
                1, 'box.space.test:insert', {{1, ...}}
            )
            if ret == nil then
                return nil, tostring(err)
            end

            return ret
        ]], {cnt, g.cluster.main_server.alias})

        if ret == nil then
            log.error('CNT %d: %s', cnt, err)
            table.insert(insertions_failed, {cnt = cnt, err = err})
        else
            table.insert(insertions_passed, ret)
        end
        return true
    end
    local highload_cnt = 0

    local highload_enabled = true
    local highload_fiber = fiber.new(function()
        log.warn('Highload started ----------')
        while highload_enabled do
            highload_cnt = highload_cnt + 1
            local ok, err = errors.pcall('E', _insert, highload_cnt)
            if ok == nil then
                log.error('CNT %d: %s', highload_cnt, err)
            end
            fiber.sleep(0.001)
        end
    end)
    highload_fiber:name('test.highload')
    highload_fiber:set_joinable(true)

    g.cluster:retrying({}, function()
        t.assert_equals(
            insertions_passed[#insertions_passed][3],
            'leader', 'No workload on leader'
        )
    end)

    --------------------------------------------------------------------
    -- Upgrade replica
    replica:stop()
    replica.chdir = new
    replica:start()
    g.cluster:retrying({}, function() replica:connect_net_box() end)
    await_state(replica, 'RolesConfigured')

    if old ~= nil then
        t.assert_not_equals(version(leader), 'scm-1')
        t.assert_equals(version(replica), 'scm-1')
    else
        t.assert_equals(version(leader), 'scm-1')
        t.assert_not_equals(version(replica), 'scm-1')
    end

    t.assert_equals(upstream_info(replica), {status = 'follow'})

    g.cluster:retrying({}, function()
        t.assert_items_equals(
            leader:graphql({query = [[{
                servers { alias status message }
            }]]}).data.servers,
            {{
                alias = leader.alias,
                status = 'healthy',
                message = '',
            }, {
                alias = replica.alias,
                status = 'healthy',
                message = '',
            }}
        )
    end)

    --------------------------------------------------------------------
    -- Switch the leadership
    local resp = leader:graphql({
        query = [[
            mutation($replicasets: [EditReplicasetInput]) {
                cluster {
                    edit_topology(replicasets: $replicasets) {
                        replicasets {
                            uuid
                            active_master {uri}
                            master {uri}
                        }
                    }
                }
            }
        ]],
        variables = {
            replicasets = {{
                uuid = leader.replicaset_uuid,
                failover_priority = {replica.instance_uuid},
            }}
        }
    })
    t.assert_equals(resp.data.cluster.edit_topology, {
        replicasets = {{
            active_master = {uri = replica.advertise_uri},
            master = {uri = replica.advertise_uri},
            uuid = replica.replicaset_uuid,
        }}
    })
    g.cluster.main_server = replica

    g.cluster:retrying({}, function()
        t.assert_equals(
            insertions_passed[#insertions_passed][3],
            'replica', 'No workload on replica'
        )
    end)

    --------------------------------------------------------------------
    -- Upgrade leader
    leader:stop()
    leader.chdir = new
    leader:start()
    g.cluster:retrying({}, function() leader:connect_net_box() end)
    g.cluster:wait_until_healthy()

    if old ~= nil then
        t.assert_equals(version(leader), 'scm-1')
        t.assert_equals(version(replica), 'scm-1')
    else
        t.assert_not_equals(version(leader), 'scm-1')
        t.assert_not_equals(version(replica), 'scm-1')
    end

    t.assert_equals(upstream_info(leader), {status = 'follow'})

    highload_enabled = false
    highload_fiber:join()
    t.assert_equals(
        g.cluster.main_server:call(
            'package.loaded.vshard.router.callrw', {
                1, 'box.space.test:select'
            }
        ),
        insertions_passed
    )

    log.warn(
        'Total insertions: %d (%d good, %d failed)',
        highload_cnt, #insertions_passed, #insertions_failed
    )
    for _, e in ipairs(insertions_failed) do
        log.error('#%d: %s', e.cnt, e.err)
    end
end

g.after_each(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)

g.test_upgrade = function()
    change_version(cartridge_older_path, nil)
end

g.test_downgrade = function()
    t.skip_if(os.getenv('CARTRIDGE_DOWNGRADE') ~= 'true')
    change_version(nil, cartridge_older_path)
end
