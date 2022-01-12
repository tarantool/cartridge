local fio = require('fio')

local t = require('luatest')
local g = t.group()
local h = require('test.helper')

local replicaset_uuid = h.uuid('b')
local single_replicaset_uuid = h.uuid('c')
local single_storage_uuid = h.uuid('c', 'c', 1)


g.before_all = function()
    g.cluster = h.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = true,
        server_command = h.entrypoint('srv_basic'),
        cookie = h.random_cookie(),
        replicasets = {
            {
                alias = 'router',
                roles = {
                    'vshard-router',
                },
                servers = 1,
            },
            {
                alias = 'storage',
                uuid = replicaset_uuid,
                roles = {
                    'vshard-storage',
                },
                servers = 2,
            },
            {
                alias = 'single-storage',
                uuid = single_replicaset_uuid,
                roles = {},
                servers = {
                    {
                        instance_uuid = single_storage_uuid,

                    },
                },
            },
        },
    })
    g.cluster:start()

    g.cluster.main_server:setup_replicaset({
        roles = {'vshard-storage'},
        weight = 0,
        uuid = single_replicaset_uuid,
    })

    for _, server in ipairs({'storage-1', 'single-storage-1'}) do
        g.cluster:server(server):exec(function ()
            box.schema.space.create('test', { if_not_exists = true })
            box.space.test:format{
                {'bucket_id', 'unsigned'},
                {'key', 'string'},
                {'value', 'any'},
            }
            box.space.test:create_index('primary', {
                parts = {'key'},
                if_not_exists = true,
            })
            box.space.test:create_index('bucket_id', {
                parts = {'bucket_id'},
                if_not_exists = true,
                unique = false,
            })
        end)
    end
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

g.after_each(function()
    for _, server in ipairs({'storage-1', 'single-storage-1'}) do
        g.cluster:server(server):exec(function ()
            box.space.test:truncate()
        end)
    end
end)

g.before_test('test_bucket_ref_on_replica_prevent_bucket_move', function()
    g.cluster.main_server:exec(function()
        local vshard_router = require('vshard.router')
        local key = 'key'
        local bucket_id = vshard_router:bucket_id_strcrc32(key)
        vshard_router.callrw(bucket_id, 'box.space.test:insert',
            {{bucket_id, key, {}}})
    end)
end)

-- see https://github.com/tarantool/vshard/issues/173 for details
g.test_bucket_ref_on_replica_prevent_bucket_move = function()
    t.xfail('Test fails until tarantool/vshard#173 will be fixed')
    -- ref bucket on replica
    local some_bucket_id = nil
    
    h.retrying({}, function()
        some_bucket_id = g.cluster:server('storage-2'):exec(function()
            assert(box.info.ro)

            local test_space = box.space.test
            local tupl = test_space:pairs():nth(1)
            local some_bucket_id = tupl.bucket_id
            local vshard_storage = require('vshard.storage')
            vshard_storage.bucket_ref(some_bucket_id, 'read')
            return some_bucket_id
        end)
    end)

    g.cluster.main_server:setup_replicaset({
        weight = 1,
        uuid = single_replicaset_uuid,
    })

    -- send bucket to another storage
    g.cluster:server('storage-1'):exec(function(bucket_id, replicaset_uuid)
        assert(not box.info.ro)
        local vshard_storage = require('vshard.storage')

        vshard_storage.bucket_send(bucket_id, replicaset_uuid)
    end, {some_bucket_id, single_replicaset_uuid})

    h.retrying({}, function()
        local bucket_counts = g.cluster:server('storage-1'):exec(function(bucket_id)
            return box.space.test:pairs():filter(function(x)
                return x.bucket_id == bucket_id
            end):length()
        end, {some_bucket_id})

        t.assert_not_equals(bucket_counts, 0)
    end)

    -- unref bucket on replica
    g.cluster:server('storage-2'):exec(function(some_bucket_id)
        assert(box.info.ro)
        local vshard_storage = require('vshard.storage')
        vshard_storage.bucket_unref(some_bucket_id, 'read')
    end, {some_bucket_id})
end

g.after_test('test_bucket_ref_on_replica_prevent_bucket_move', function()
    g.cluster.main_server:setup_replicaset({
        weight = 0,
        uuid = single_replicaset_uuid,
    })
end)
