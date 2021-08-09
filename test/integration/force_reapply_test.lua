local t = require('luatest')
local g = t.group()

local fio = require('fio')
local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = helpers.entrypoint('srv_basic'),
        cookie = require('digest').urandom(6):hex(),
        replicasets = {{
            alias = 'A',
            roles = {'myrole-permanent'},
            servers = 3,
        }},
    })
    g.cluster:start()
    g.A1 = g.cluster:server('A-1')
    g.A2 = g.cluster:server('A-2')
    g.A3 = g.cluster:server('A-3')
    t.helpers.retrying({}, function()
        t.assert_equals(helpers.list_cluster_issues(g.A1), {})
    end)
end)

g.after_all(function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end)


function g.test_twophase_config_locked()
    -- Let's put a spoke in two-phases wheel
    local config = g.A1.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        return confapplier.get_active_config():get_plaintext()
    ]])
    config['hey.txt'] = 'Hello, locks'
    g.A2.net_box:call(
        '_G.__cartridge_clusterwide_config_prepare_2pc', {config}
    )

    t.assert_equals(fio.path.exists(g.A1.workdir .. '/config.prepare'), false)
    t.assert_equals(fio.path.exists(g.A2.workdir .. '/config.prepare'), true)
    t.assert_equals(fio.path.exists(g.A3.workdir .. '/config.prepare'), false)
    t.assert_equals(helpers.list_cluster_issues(g.A1), {{
        level = 'warning',
        topic = 'config_locked',
        instance_uuid = g.A2.instance_uuid,
        replicaset_uuid = g.A2.replicaset_uuid,
        message = 'Configuration is prepared and locked'..
            ' on localhost:13302 (A-2)',
    }})

    -- Obviously, 2pc is locked
    local ok, err = g.A1.net_box:call(
        'package.loaded.cartridge.config_patch_clusterwide',
        {{['bye.txt'] = 'Goodbye, locks'}}
    )
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'Prepare2pcError',
        err = '"localhost:13302": Two-phase commit is locked',
    })

    -- But force reapply comes to the rescue!
    local ok, err = g.A1.net_box:call(
        'package.loaded.cartridge.config_force_reapply',
        {{g.A2.instance_uuid}}
    )
    t.assert_equals({ok, err}, {true, nil})

    -- The lock is gone
    t.assert_equals(fio.path.exists(g.A2.workdir .. '/config.prepare'), false)

    -- And patch_clusterwide succeeds
    local ok, err = g.A1.net_box:call(
        'package.loaded.cartridge.config_patch_clusterwide',
        {{['bye.txt'] = 'Goodbye, locks'}}
    )
    t.assert_equals({ok, err}, {true, nil})

    t.assert_equals(helpers.list_cluster_issues(g.A1), {})
    t.assert_covers(
        g.cluster:download_config(),
        {['bye.txt'] = 'Goodbye, locks'}
    )
end

local function force_reapply(uuids)
    return g.cluster.main_server:graphql({
        query = [[mutation($uuids: [String]) {
            cluster { config_force_reapply(uuids: $uuids) }
        }]],
        variables = {uuids = uuids}
    })
end

function g.test_graphql_api()
    t.assert_error_msg_equals(
        'Server alien not in clusterwide config',
        force_reapply, {'alien'}
    )

    for _, srv in pairs(g.cluster.servers) do
        srv.net_box:eval([[
            local cartridge = require('cartridge')
            local myrole = cartridge.service_get('myrole-permanent')
            myrole.apply_config = function()
                _G.counter = _G.counter + 1
            end
            _G.counter = 0
        ]])
    end

    t.assert(force_reapply({g.A1.instance_uuid}))
    t.assert(force_reapply({g.A1.instance_uuid, g.A2.instance_uuid}))
    t.assert(force_reapply({g.A1.instance_uuid, g.A2.instance_uuid, g.A3.instance_uuid}))

    local q_get_counter = 'return _G.counter'
    t.assert_equals(g.A1.net_box:eval(q_get_counter), 3)
    t.assert_equals(g.A2.net_box:eval(q_get_counter), 2)
    t.assert_equals(g.A3.net_box:eval(q_get_counter), 1)
end

function g.test_suggestions()
    -- Wreak some havoc

    -- Trigger config_lock issue
    local config = g.A1.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        return confapplier.get_active_config():get_plaintext()
    ]])
    config['hey.txt'] = 'Hello, locks'
    g.A2.net_box:call(
        '_G.__cartridge_clusterwide_config_prepare_2pc', {config}
    )

    -- Add config_mismatch as well
    g.A2.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        local cfg = confapplier.get_active_config():copy()
        cfg:set_plaintext('todo.txt', '- Trigger config mismatch')
        cfg:lock()
        confapplier.apply_config(cfg)
    ]])

    -- OperationError also should be mentioned in suggestions if present
    g.A3.net_box:eval([[
        package.loaded['mymodule-permanent'].apply_config = function()
            error('Artificial Error', 0)
        end
    ]])
    t.assert_error_msg_equals(
        '"localhost:13303": Artificial Error',
        force_reapply, {g.A3.instance_uuid}
    )

    -- Speed up memebership payload dissemination
    g.A1.net_box:call(
        'package.loaded.membership.probe_uri',
        {g.A3.advertise_uri}
    )


    t.assert_items_equals(
        helpers.get_suggestions(g.A1).force_apply,
        {{
            uuid = g.A2.instance_uuid,
            config_locked = true,
            config_mismatch = true,
            operation_error = false,
        }, {
            uuid = g.A3.instance_uuid,
            config_locked = false,
            config_mismatch = false,
            operation_error = true,
        }}
    )

    -- Go back where it was
    g.A3.net_box:eval([[
        package.loaded['mymodule-permanent'].apply_config = nil
    ]])
    t.assert(force_reapply({g.A2.instance_uuid, g.A3.instance_uuid}))
    g.cluster:wait_until_healthy(g.A1)
    t.assert_is(helpers.get_suggestions(g.A1).force_apply, box.NULL)
end
