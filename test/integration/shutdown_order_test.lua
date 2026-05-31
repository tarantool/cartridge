local fio = require('fio')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_all(function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = false,
        cookie = helpers.random_cookie(),
        replicasets = {{
            uuid = helpers.uuid('a'),
            roles = {},
            servers = {{
                alias = 'main',
                instance_uuid = helpers.uuid('a', 'a', 1),
            }}
        }}
    })
    g.cluster:start()

    -- Inject hooks to monitor the order of shutdown components
    g.cluster.main_server:exec(function()
        local fio = require('fio')

        rawset(_G, 'roles_are_stopped', false)
        rawset(_G, 'order_violation', false)

        -- Hook cartridge.roles stop
        local roles = require('cartridge.roles')
        local orig_roles_stop = roles.stop
        roles.stop = function(...)
            -- Simulate time-consuming role shutdown to verify sequential execution
            require('fiber').sleep(0.1)
            rawset(_G, 'roles_are_stopped', true)
            return orig_roles_stop(...)
        end

        -- Hook membership leave
        local membership = require('membership')
        local orig_membership_leave = membership.leave
        membership.leave = function(...)
            -- Check if roles stop sequence has already completed
            rawset(_G, 'order_violation', not rawget(_G, 'roles_are_stopped'))

            local res = orig_membership_leave(...)

            -- Persist the verification result to a file
            local path = fio.pathjoin(box.cfg.memtx_dir, 'shutdown_order_status.txt')
            local f = fio.open(path, {'O_CREAT', 'O_WRONLY', 'O_TRUNC'}, tonumber('644', 8))
            if f then
                f:write(rawget(_G, 'order_violation') and "VIOLATION" or "OK")
                f:close()
            end

            return res
        end
    end)
end)

g.after_all(function()
    pcall(g.cluster.stop, g.cluster)
    fio.rmtree(g.cluster.datadir)
end)

function g.test_shutdown_order()
    t.skip_if(box.ctl.on_shutdown == nil,
        'box.ctl.on_shutdown is not supported in Tarantool ' .. _TARANTOOL
    )

    local server = g.cluster.main_server
    local result_path = fio.pathjoin(server.workdir, 'shutdown_order_status.txt')

    -- Stop the server to initiate the shutdown sequence
    server:stop()

    local f = fio.open(result_path, {'O_RDONLY'})
    t.assert_not_equals(f, nil, "Result file not found")
    local verdict = f:read()
    f:close()

    t.assert_equals(verdict, "OK", "Membership left before roles shutdown sequence finished")
end
