local fio = require('fio')
local t = require('luatest')
local g = t.group()
local h = require('test.helper')

g.before_all = function()
    t.skip_if(h.tarantool_version_ge('2.10.4'))
    g.cluster = h.Cluster:new({
        datadir = fio.tempdir(),
        server_command = h.entrypoint('srv_basic'),
        use_vshard = false,
        cookie = h.random_cookie(),
        replicasets = {
            {
                roles = {},
                alias = 'A',
                servers = 1
            }
        }
    })
    g.cluster:start()
    g.cluster:wait_until_healthy()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

g.test_invalid_format = function()
   g.cluster.main_server:exec(function()
        box.schema.space.create('invalid')
        box.space.invalid:create_index('pk')
        box.space.invalid:format({{name = 'pk', type = 'n'}})

        box.schema.space.create('valid')
        box.space.valid:create_index('pk')
        box.space.valid:format({{name = 'pk', type = 'integer'}})
    end)
    g.cluster:stop()

    g.cluster:start()
    g.cluster:wait_until_healthy()

    g.cluster.main_server:exec(function()
        local invalid_format = require('cartridge.invalid-format')
        if box.ctl.on_schema_init ~= nil then
            assert(#box.space._space:before_replace() == 0)
            assert(#box.ctl.on_schema_init() == 1) -- there is some default trigger
            local spaces_str = invalid_format.spaces_list_str()
            assert(spaces_str == 'invalid')
        end

        local spaces = invalid_format.run_check()
        assert(spaces['invalid'] == true)
        assert(spaces['valid'] == nil)
        local spaces_str = invalid_format.spaces_list_str()
        assert(spaces_str == 'invalid')
    end)

    t.helpers.retrying({}, function()
        t.assert_equals(h.list_cluster_issues(g.cluster.main_server), {{
            level = 'warning',
            topic = 'invalid_format',
            instance_uuid = g.cluster.main_server.instance_uuid,
            replicaset_uuid = g.cluster.main_server.replicaset_uuid,
            message = 'Instance localhost:13301 (A-1) has spaces with deprecated format: invalid',
        }})
    end)
end
