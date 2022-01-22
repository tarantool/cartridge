local fio = require('fio')
 local t = require('luatest')
 local g = t.group()

 local helpers = require('test.helper')

 g.before_all(function()
     g.cluster = helpers.Cluster:new({
         datadir = fio.tempdir(),
         server_command = helpers.entrypoint('srv_basic'),
         cookie = helpers.random_cookie(),
         swim_period = 0.05,
         replicasets = {
             {
                 alias = 'A',
                 uuid = helpers.uuid('a'),
                 roles = {},
                 servers = 1,
             },
             {
                 alias = 'B',
                 uuid = helpers.uuid('b'),
                 roles = {},
                 servers = 1,
             }
         },
     })

     g.A1 = g.cluster:server('A-1')
     g.B1 = g.cluster:server('B-1')

     g.cluster:start()

     g.A1:eval([[
         _G.commit_is_done = false
         _G.old_commit = _G.__cartridge_clusterwide_config_commit_2pc
         _G.__cartridge_clusterwide_config_commit_2pc = function(...)
             local res, err = _G.old_commit(...)
             _G.commit_is_done = true
             return res, err
         end
     ]])

     g.B1:eval([[
         _G.old_commit = _G.__cartridge_clusterwide_config_commit_2pc
         _G.__cartridge_clusterwide_config_commit_2pc = function(...)
             package.loaded.fiber.sleep(1)
             return _G.old_commit(...)
         end
     ]])
 end)

 g.after_all(function()
     g.cluster:stop()
     fio.rmtree(g.cluster.datadir)
 end)

 g.test_config_mismatch = function()
     -- Assign role 'myrole' on B
     g.A1:call(
         'package.loaded.cartridge.admin_edit_topology',
         {{
             replicasets = {{
                 uuid = helpers.uuid('b'),
                 roles = {'myrole'}
             }}
         }},
         {is_async = true}
     )
     -- A1 should commit config before B1
     t.helpers.retrying({}, function()
         local ready = g.A1:eval([[return _G.commit_is_done]])
         t.assert(ready)
     end)

     -- A1 thinks that 'myrole' is active on B1 (it assumes judging from its
     -- local config).
     -- But commit_2pc is stuck on B1 and role isn't applied.
     -- However A1 shouldn't return B1 as a candidate because there is a config
     -- checksum mismatch deduced from membership.
     local _, err = g.A1:exec(function()
        local rpc = require('cartridge.rpc')
        local _, err = rpc.call('myrole', 'dog_goes')
        local candidates = rpc.get_candidates('myrole')
        return candidates, err
    end)

     t.assert_str_contains(err.err, 'Twophase commit is in progress, try again later')
 end
