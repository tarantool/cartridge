local log = require('log')
local fio = require('fio')
local t = require('luatest')
local g = t.group()

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.servers = {}
    for i = 1, 3 do
        g.servers[i] = helpers.Server:new({
            workdir = fio.tempdir(),
            alias = 's' .. tostring(i),
            command = test_helper.server_command,
            replicaset_uuid = helpers.uuid('a'),
            instance_uuid = helpers.uuid('a', 'a', i),
            http_port = 8080 + i,
            cluster_cookie = 'test-cluster-cookie',
            advertise_port = ({13301, 13303, 13305})[i],
            env = {
                ['CLOCK_DELTA'] = ({0, -7, 3})[i]
            }
        })
        g.servers[i]:start()
    end

    for _, server in pairs(g.servers) do
        t.helpers.retrying({timeout = 5}, function()
            server:connect_net_box()
        end)
        server.net_box:eval([[
            local fiber = require('fiber')
            local _time64 = fiber.time64
            local delta = tonumber(os.getenv('CLOCK_DELTA'))
            function fiber.time64()
                return _time64() + delta * 1e6
            end
        ]])
    end
end

g.after_all = function()
    for _, server in pairs(g.servers) do
        server:stop()
        fio.rmtree(server.workdir)
    end
end

function g.test_clock_delta()
    g.servers[1].net_box:eval([[
        local membership = require('membership')
        for _, uri in pairs({...}) do
            assert(membership.probe_uri(uri))
        end
    ]], {
        g.servers[2].advertise_uri,
        g.servers[3].advertise_uri,
    })

    -- full mesh isn't established yet
    local resp = g.servers[2]:graphql({
        query = [[{ servers { uri clock_delta } }]]
    }).data.servers
    t.assert_equals(#resp, 2)

    for i, observer in pairs(g.servers) do
        ::retry::
        log.info('Observing servers[%s]', i, observer.advertise_uri)
        local resp = observer:graphql({
            query = [[{ servers { uri clock_delta } }]]
        }).data.servers
        for _, peer in pairs(g.servers) do
            local clock_delta = test_helper.table_find_by_attr(
                resp, 'uri', peer.advertise_uri
            ).clock_delta
            if clock_delta == nil then
                observer.net_box:eval([[
                    local membership = require('membership')
                    assert(membership.probe_uri(...))
                ]], {peer.advertise_uri})
                goto retry
            end
            t.assert_almost_equals(
                clock_delta,
                peer.env.CLOCK_DELTA - observer.env.CLOCK_DELTA, 0.1,
                string.format("Observer %s, peer %s", observer.alias, peer.alias)
            )
        end
    end
end
