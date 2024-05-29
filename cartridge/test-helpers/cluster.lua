--- Class to run and manage multiple tarantool instances.
--
-- @classmod cartridge.test-helpers.cluster

local checks = require('checks')
local fio = require('fio')
local fun = require('fun')
local log = require('log')
local uuid = require('uuid')

local luatest = require('luatest')
local utils = require('cartridge.utils')
local Server = require('cartridge.test-helpers.server')
local Stateboard = require('cartridge.test-helpers.stateboard')

-- Defaults.
local Cluster = {
    CONNECTION_TIMEOUT = 5,
    CONNECTION_RETRY_DELAY = 0.1,

    cookie = 'test-cluster-cookie',
    base_http_port = 8080,
    base_advertise_port = 13300,
    failover = 'disabled',
}

function Cluster:inherit(object)
    setmetatable(object, self)
    self.__index = self
    return object
end

--- Build cluster object.
-- @param object
-- @string object.datadir Data directory for all cluster servers.
-- @string object.server_command Command to run server.
-- @string object.cookie Cluster cookie.
-- @int[opt] object.base_http_port Value to calculate server's http_port.
-- @int[opt] object.base_advertise_port Value to calculate server's advertise_port.
-- @bool[opt] object.use_vshard bootstrap vshard after server is started.
-- @tab object.replicasets Replicasets configuration. List of @{replicaset_config}
-- @string[opt] object.failover Failover mode: disabled, eventual, or stateful.
-- @string[opt] object.stateboard_entrypoint Command to run stateboard.
-- @tab[opt] object.zone_distances Vshard distances between zones.
-- @number[opt] object.swim_period SWIM protocol period in seconds.
-- @bool[opt] object.auth_enabled Enable authentication.
-- @return object
function Cluster:new(object)
    checks('table', {
        datadir = 'string',
        server_command = 'string',
        cookie = '?string',
        base_http_port = '?number',
        base_advertise_port = '?number',
        use_vshard = '?boolean',
        replicasets = 'table',
        env = '?table',
        failover = '?string',
        stateboard_entrypoint = '?string',
        zone_distances = '?table',
        swim_period = '?number',
        auth_enabled = '?boolean',
    })
    --- Replicaset config.
    -- @table @replicaset_config
    -- @string[opt] alias Prefix to generate server alias automatically.
    -- @string[opt] uuid Replicaset uuid.
    -- @tparam {string} roles List of roles for servers in the replicaset.
    -- @tparam ?string vshard_group Name of vshard group.
    -- @tparam ?number weight Vshard group weight.
    -- @tparam ?boolean all_rw Make all replicas writable.
    -- @tparam table|number servers List of objects to build `Server`s with or
    --      number of servers in replicaset.
    for _, replicaset in pairs(object.replicasets) do
        (function(_) checks({
            alias = '?string',
            uuid = '?string',
            roles = 'table',
            vshard_group = '?string',
            weight = '?number',
            servers = 'table|number',
            all_rw = '?boolean',
        }) end)(replicaset)
    end

    self:inherit(object)
    object:initialize()
    return object
end

function Cluster:initialize()
    self.servers = {}

    assert(
        self.failover == 'disabled'
        or self.failover == 'eventual'
        or self.failover == 'stateful'
        or self.failover == 'raft',
        "failover must be 'disabled', 'eventual', 'stateful' or 'raft'"
    )

    if self.failover == 'stateful' then
        assert(self.stateboard_entrypoint ~= nil,
            'stateboard_entrypoint required for stateful failover')
        self.stateboard = Stateboard:new({
            workdir = fio.pathjoin(self.datadir, 'stateboard'),
            command = self.stateboard_entrypoint,
            net_box_port = 14401,
            net_box_credentials = {
                user = 'client',
                password = self.cookie,
            },
            env = {
                TARANTOOL_PASSWORD = self.cookie,
            }
        })
    end

    for _, replicaset_config in ipairs(self.replicasets) do
        replicaset_config.uuid = replicaset_config.uuid or uuid.str()
        if type(replicaset_config.servers) == 'number' then
            assert(replicaset_config.servers > 0, 'servers count must be positive')
            replicaset_config.servers = fun.range(replicaset_config.servers):
                map(function() return {} end):totable()
        end
        assert(#replicaset_config.servers > 0, 'Replicaset must contain at least one server')
        for i, server_config in ipairs(replicaset_config.servers) do
            if self.env then
                server_config.env = fun.chain(self.env, server_config.env or {}):tomap()
            end
            if self.auth_enabled then
                server_config.auth_enabled = true
            end
            table.insert(self.servers, self:build_server(server_config, replicaset_config, i))
        end
    end
end

function Cluster:configure_failover()
    assert(self.main_server)

    local failover_config = {mode = self.failover}
    if failover_config.mode == 'stateful' then
        failover_config.state_provider = 'tarantool'
        failover_config.tarantool_params = {
            uri = self.stateboard.net_box_uri,
            password = self.stateboard.net_box_credentials.password
        }
    end

    self.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {failover_config}
    )
end

--- Find server by alias.
-- @string alias
-- @return @{cartridge.test-helpers.server}
function Cluster:server(alias)
    for _, server in ipairs(self.servers) do
        if server.alias == alias then
            return server
        end
    end
    error('Server ' .. alias .. ' not found', 2)
end

--- Return iterator for cluster server's with enabled role
local function iter_servers_by_role(cluster, role_name)
    local replicasets_with_role = fun.iter(cluster.replicasets)
        :map(function(rs) return rs.uuid, rs.roles end)
        :map(function(rs_uuid, roles) return rs_uuid, utils.table_find(roles, role_name) ~= nil end)
        :tomap()

    return fun.iter(cluster.servers)
        :filter(function(server)
            return replicasets_with_role[server.replicaset_uuid]
        end)
end

--- Find server by role name.
-- @string role_name
-- @return @{cartridge.test-helpers.server}
function Cluster:server_by_role(role_name)
    return iter_servers_by_role(self, role_name):nth(1)
end

--- Return list of servers with enabled role by role name
-- @string role_name
-- @return @{cartridge.test-helpers.server}
function Cluster:servers_by_role(role_name)
    return iter_servers_by_role(self, role_name):totable()
end

--- Execute `edit_topology` GraphQL request to setup replicasets, apply roles
-- join servers to replicasets.
function Cluster:apply_topology()
    local replicasets = table.deepcopy(self.replicasets)
    local replicaset_by_uuid = {}
    for _, replicaset in pairs(replicasets) do
        replicaset_by_uuid[replicaset.uuid] = replicaset
        replicaset.join_servers = {}
        replicaset.servers = nil
    end

    for _, server in pairs(self.servers) do
        table.insert(replicaset_by_uuid[server.replicaset_uuid].join_servers, {
            uri = server.advertise_uri,
            uuid = server.instance_uuid,
            labels = server.labels,
            zone = server.zone,
        })
    end

    self.main_server:graphql({
        query = [[
            mutation boot($replicasets: [EditReplicasetInput]) {
                cluster {
                    edit_topology(replicasets: $replicasets) { servers { uri } }
                }
            }
        ]],
        variables = {replicasets = replicasets}
    })
end

function Cluster:apply_zone_distances()
    assert(self.main_server)

    if self.zone_distances ~= nil then
        self.main_server.net_box:call(
            'package.loaded.cartridge.config_patch_clusterwide',
            {{zone_distances = self.zone_distances}}
        )
    end
end

-- Configure replicasets and bootstrap vshard if required.
function Cluster:bootstrap()
    self.main_server = self.servers[1]
    self:apply_topology()
    self:apply_zone_distances()

    for _, server in ipairs(self.servers) do
        self:wait_until_healthy(server)
    end

    if self.use_vshard then
        self:bootstrap_vshard()
    end
end

function Cluster:bootstrap_vshard()
    local server = self.main_server
    log.debug('Bootstrapping vshard.router on ' .. server.advertise_uri)
    log.debug({response = server:graphql({query = 'mutation { bootstrap_vshard }'})})
end

--- Bootstraps cluster if it wasn't bootstrapped before. Otherwise starts servers.
function Cluster:start()
    if self.running then
        return
    end
    if self.failover == 'stateful' then
        self.stateboard:start()
        luatest.helpers.retrying({}, function()
            self.stateboard:connect_net_box()
        end)
    end
    for _, server in ipairs(self.servers) do
        server:start()
    end
    if self.bootstrapped then
        for _, server in ipairs(self.servers) do
            self:wait_until_healthy(server)
        end
    else
        self:bootstrap()
        self.bootstrapped = true
    end
    if self.failover ~= 'disabled' then
        self:configure_failover()
    end
    self.running = true
end

--- Stop all servers.
function Cluster:stop()
    for _, server in ipairs(self.servers) do
        server:stop()
    end
    if self.stateboard then
        self.stateboard:stop()
    end
    self.running = nil
end

function Cluster:restart()
    self:stop()
    self:start()
    self:wait_until_healthy()
end

function Cluster:build_server(config, replicaset_config, sn)
    replicaset_config = replicaset_config or {}
    local server_id = #self.servers + 1
    local advertise_port = self.base_advertise_port and (self.base_advertise_port + server_id)
    local server_config = {
        alias = replicaset_config.alias and (replicaset_config.alias .. '-' .. sn),
        replicaset_uuid = replicaset_config.uuid,
        command = self.server_command,
        workdir = nil,
        cluster_cookie = self.cookie,
        http_port = self.base_http_port and (self.base_http_port + server_id),
        advertise_port = advertise_port,
        swim_period = self.swim_period,
    }
    for key, value in pairs(config) do
        server_config[key] = value
    end
    assert(server_config.alias, 'Either replicaset.alias or server.alias must be given')
    if server_config.workdir == nil then
        server_config.workdir = fio.pathjoin(
            self.datadir, 'localhost-' .. server_config.advertise_port
        )
    end
    return Server:new(server_config)
end

--- Register running server in the cluster.
-- @tparam Server server Server to be registered.
function Cluster:join_server(server)
    if self.main_server then
        self:retrying({}, function()
            self.main_server.net_box:eval(
                "assert(require('membership').probe_uri(...))",
                {server.advertise_uri}
            )
        end)
    else
        self.main_server = server
        self:retrying({}, function() server:graphql({query = '{ servers { uri } }'}) end)
    end

    server:join_cluster(self.main_server, {timeout = self.CONNECTION_TIMEOUT})
    -- wait for bootserv to see that the new member is alive
    self:wait_until_healthy()
end

--- Blocks fiber until `cartridge.is_healthy()` returns true on main_server.
function Cluster:wait_until_healthy(server)
    self:retrying({}, function ()
        (server or self.main_server).net_box:eval([[
            local cartridge = package.loaded['cartridge']
            return assert(cartridge) and assert(cartridge.is_healthy())
        ]])
    end)
end

--- Upload application config, shortcut for `cluster.main_server:upload_config(config)`.
--  @see cartridge.test-helpers.server:upload_config
function Cluster:upload_config(config, opts)
    return self.main_server:upload_config(config, opts)
end

--- Download application config, shortcut for `cluster.main_server:download_config()`.
-- @see cartridge.test-helpers.server:download_config
function Cluster:download_config()
    return self.main_server:download_config()
end

--- Keeps calling fn until it returns without error.
-- Throws last error if config.timeout is elapsed.
-- @tab config Options for `luatest.helpers.retrying`.
-- @func fn Function to call
-- @param[opt] ... Args to run fn with.
function Cluster:retrying(config, fn, ...)
    return luatest.helpers.retrying({
        timeout = config.timeout or self.CONNECTION_TIMEOUT,
        delay = config.delay or self.CONNECTION_RETRY_DELAY,
    }, fn, ...)
end

return Cluster
