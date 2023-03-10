--- Extended luatest.Server class to run a cartridge instance.
--
-- @classmod cartridge.test-helpers.server

local fun = require('fun')
local log = require('log')
local fio = require('fio')
local luatest = require('luatest')
local yaml = require('yaml')
local checks = require('checks')

--- Build server object.
-- @function new
-- @param object
-- @string object.command Command to start server process.
-- @string object.workdir Value to be passed in `TARANTOOL_WORKDIR`.
-- @bool[opt] object.chdir Path to cwd before starting a process.
-- @tab[opt] object.env Table to pass as env variables to process.
-- @tab[opt] object.args Args to run command with.
-- @int[opt] object.http_port Value to be passed in `TARANTOOL_HTTP_PORT` and used to perform HTTP requests.
-- @int object.advertise_port Value to generate `TARANTOOL_ADVERTISE_URI` and used for net_box connection.
-- @int[opt] object.net_box_port Alias for `advertise_port`.
-- @tab[opt] object.net_box_credentials Override default net_box credentials.
-- @string object.alias Instance alias.
-- @string object.cluster_cookie Value to be passed in `TARANTOOL_CLUSTER_COOKIE` and used as default net_box password.
-- @string[opt] object.instance_uuid Server identifier.
-- @string[opt] object.replicaset_uuid Replicaset identifier.
-- @string[opt] object.zone Vshard zone.
-- @number[opt] object.swim_period SWIM protocol period in seconds.
-- @return input object
local Server = luatest.Server:inherit({})

Server.constructor_checks = fun.chain(Server.constructor_checks, {
    alias = 'string',
    cluster_cookie = 'string',

    advertise_port = 'number',
    advertise_uri = '?string',

    instance_uuid = '?string',
    replicaset_uuid = '?string',
    labels = '?table',
    zone = '?string',
    swim_period = '?number',

    transport = '?string',
    ssl_ciphers = '?string',
    ssl_server_ca_file = '?string',
    ssl_server_cert_file = '?string',
    ssl_server_key_file = '?string',
    ssl_server_password = '?string',
    ssl_client_ca_file = '?string',
    ssl_client_cert_file = '?string',
    ssl_client_key_file = '?string',
    ssl_client_password = '?string',
}):tomap()

function Server:initialize()
    self.net_box_port = self.net_box_port or self.advertise_port
    self.net_box_uri = 'localhost:' .. self.net_box_port
    self.advertise_uri = self.advertise_uri or self.net_box_uri
    self.net_box_credentials = self.net_box_credentials or {
        user = 'admin',
        password = self.cluster_cookie,
    }

    if self.instance_uuid == nil then
        self.instance_uuid = require('uuid').str()
    end
    getmetatable(getmetatable(self)).initialize(self)
end

--- Generates environment to run process with.
-- The result is merged into os.environ().
-- @return map
function Server:build_env()
    return {
        TARANTOOL_ALIAS = self.alias,
        TARANTOOL_WORKDIR = self.workdir,
        TARANTOOL_HTTP_PORT = self.http_port,
        TARANTOOL_ADVERTISE_URI = self.advertise_uri,
        TARANTOOL_CLUSTER_COOKIE = self.cluster_cookie,
        -- speedup tests by amplifying membership message exchange
        TARANTOOL_SWIM_PROTOCOL_PERIOD_SECONDS = self.swim_period or 0.2,

        TARANTOOL_TRANSPORT = self.transport,
        TARANTOOL_SSL_CIPHERS = self.ssl_ciphers,
        TARANTOOL_SSL_SERVER_CA_FILE = self.ssl_server_ca_file,
        TARANTOOL_SSL_SERVER_CERT_FILE = self.ssl_server_cert_file,
        TARANTOOL_SSL_SERVER_KEY_FILE = self.ssl_server_key_file,
        TARANTOOL_SSL_SERVER_PASSWORD = self.ssl_server_password,
        TARANTOOL_SSL_CLIENT_CA_FILE = self.ssl_client_ca_file,
        TARANTOOL_SSL_CLIENT_CERT_FILE = self.ssl_client_cert_file,
        TARANTOOL_SSL_CLIENT_KEY_FILE = self.ssl_client_key_file,
        TARANTOOL_SSL_CLIENT_PASSWORD = self.ssl_client_password,
    }
end

local function reconnect(connection_old)
    local server = connection_old._server
    log.debug(
        'Netbox %s (%s): connection lost',
        server.alias, server.advertise_uri
    )
    local fiber = require('fiber')
    fiber.new(function()
        if type(server.net_box_uri) == 'string' then
            fiber.name(string.format('reconnect/%s', server.net_box_uri))
        elseif type(server.net_box_uri) == 'table' then
            fiber.name(string.format('reconnect/%s', server.net_box_uri.uri))
        end
        local uri = server.net_box_uri

        local connection_new = require('net.box').connect(
            uri, server.net_box_credentials
        )

        if server.net_box ~= connection_old then
            -- Someone has already assigned `self.net_box`
            -- while this fiber was trying to establish a new one.
            -- Don't interfere in this case.
            return
        end

        if connection_new.error then
            log.debug(
                'Netbox %s (%s) reconnect failed: %s',
                server.alias, server.advertise_uri, connection_new.error
            )
            return
        else
            log.debug(
                'Netbox %s (%s) reconnected',
                server.alias, server.advertise_uri
            )
        end

        connection_new:on_disconnect(reconnect)
        server.net_box = connection_new
        server.net_box._server = server
    end)
end

function Server:connect_net_box()
    local transport = self.transport
    if transport ~= nil and type(transport) == 'string' then
        transport = transport:lower()
    end
    if transport == 'ssl' then
        if type(self.net_box_uri) == 'string' then
            self.net_box_uri = {
                uri = self.net_box_uri,
                params = {
                    transport = transport,
                    ssl_ciphers = self.ssl_ciphers,
                    ssl_cert_file = self.ssl_client_cert_file,
                    ssl_key_file = self.ssl_client_key_file,
                    ssl_password = self.ssl_client_password,
                    ssl_ca_file = self.ssl_client_ca_file,
                }
            }
        end
    end

    getmetatable(getmetatable(self)).connect_net_box(self)
    self.net_box._server = self
    self.net_box:on_disconnect(reconnect)
    return self.net_box
end

--- Start the server.
function Server:start()
    getmetatable(getmetatable(self)).start(self)
    luatest.helpers.retrying({}, function()
        self:connect_net_box()
    end)
end

--- Stop server process.
function Server:stop()
    local process = self.process
    if process == nil then
        return
    end
    if self.net_box then
        -- Don't try to reconnect anymore
        self.net_box:on_disconnect(nil, reconnect)
    end
    getmetatable(getmetatable(self)).stop(self)
    luatest.helpers.retrying({}, function()
        luatest.assert_not(
            process:is_alive(),
            string.format('Process %s is still running', self.alias)
        )
    end)
    log.warn('Process %s killed', self.alias)
end

--- Perform GraphQL request.
-- @tparam table request
-- @tparam string request.query
--   grapqhl query
-- @tparam ?table request.variables
--   variables for graphql query
-- @tparam ?boolean request.raise
--   raise if response contains an error
--   (default: **true**)
-- @tparam[opt] table http_options
--   passed to `http_request` options.
-- @treturn table parsed response JSON.
-- @raise
--   * HTTPRequest error
--   * GraphQL error
function Server:graphql(request, http_options)
    checks('table', {
        query = 'string',
        variables = '?table',
        raise = '?boolean'
    }, '?table')

    log.debug('GraphQL request to %s (%s)', self.alias, self.advertise_uri)
    log.debug('Query: %s', request.query)
    if request.variables ~= nil then
        log.debug('Variables:\n%s', yaml.encode(request.variables))
    end

    if request.raise == nil then
        request.raise = true
    end

    http_options = table.copy(http_options) or {}
    http_options.json = {
        query = request.query,
        variables = request.variables,
    }

    local webui_prefix = self.env and self.env.TARANTOOL_WEBUI_PREFIX or ''
    local api_endpoint = fio.pathjoin('/', webui_prefix, 'admin/api')
    local response = self:http_request('post', api_endpoint, http_options)

    local errors = response.json and response.json.errors
    if errors and request.raise then
        error(errors[1].message, 2)
    end
    return response.json
end

--- Advertise this server to the cluster.
-- @param main_server Server to perform GraphQL request on.
-- @param[opt] options
-- @param options.timeout request timeout
function Server:join_cluster(main_server, options)
    log.debug('Adding ' .. self.advertise_uri .. '(' .. self.alias .. '):')
    return main_server:graphql({
        query = [[
            mutation(
                $uri: String!,
                $instance_uuid: String,
                $replicaset_uuid: String,
                $timeout: Float
                $labels: [LabelInput]
            ) {
                join_server(
                    uri: $uri,
                    instance_uuid: $instance_uuid,
                    replicaset_uuid: $replicaset_uuid,
                    timeout: $timeout
                    labels: $labels
                )
            }
        ]],
        variables = {
            uri = self.advertise_uri,
            instance_uuid = self.instance_uuid,
            replicaset_uuid = self.replicaset_uuid,
            timeout = options and options.timeout,
            labels = self.labels,
        }
    })
end

--- Update server's replicaset config.
-- @param config
-- @param config.uuid replicaset uuid
-- @param config.roles list of roles
-- @param config.master
-- @param config.weight
function Server:setup_replicaset(config)
    self:graphql({
        query = [[
            mutation(
                $uuid: String!,
                $alias: String,
                $roles: [String!],
                $master: [String!],
                $weight: Float,
                $vshard_group: String
            ) {
                edit_replicaset(
                    uuid: $uuid,
                    alias: $alias,
                    roles: $roles,
                    master: $master,
                    weight: $weight,
                    vshard_group: $vshard_group
                )
            }
        ]],
        variables = {
            uuid = config.uuid,
            alias = config.alias,
            roles = config.roles,
            master = config.master,
            weight = config.weight,
            vshard_group = config.vshard_group,
        }
    })
end

--- Upload application config.
-- @tparam string|table config - table will be encoded as yaml and posted to /admin/config.
-- @param table opts - http request options
function Server:upload_config(config, opts)
    checks('table', 'string|table', 'table|nil')
    if type(config) == 'table' then
        config = yaml.encode(config)
    end
    if opts == nil then
        opts = {}
    end
    opts.body = config
    return self:http_request('put', '/admin/config', opts)
end

--- Download application config.
function Server:download_config()
    return yaml.decode(self:http_request('get', '/admin/config').body)
end

return Server
