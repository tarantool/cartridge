--- Extended luatest.Server class to run tarantool instance.
--
-- @classmod cartridge.test-helpers.server

local log = require('log')
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
-- @return input object
local Server = luatest.Server:inherit({})

Server.constructor_checks = {
    command = 'string',
    workdir = 'string',
    chdir = '?string',
    env = '?table',
    args = '?table',

    http_port = '?number',
    net_box_port = '?number',
    net_box_credentials = '?table',

    alias = 'string',
    cluster_cookie = 'string',

    advertise_port = 'number',

    instance_uuid = '?string',
    replicaset_uuid = '?string',
}

function Server:initialize()
    self.net_box_port = self.net_box_port or self.advertise_port
    self.net_box_uri = 'localhost:' .. self.net_box_port
    self.advertise_uri = self.net_box_uri
    self.net_box_credentials = self.net_box_credentials or {
        user = 'admin',
        password = self.cluster_cookie,
    }
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
    }
end

--- Perform GraphQL request on cluster.
-- @param request object to be serialized into JSON body.
-- @param[opt] options additional options for :http_request.
-- @return parsed response JSON.
-- @raise HTTPRequest error when request fails or first error from `errors` field if any.
function Server:graphql(request, options)
    log.debug('GraphQL request to :' .. self.http_port .. '. Query: ' .. request.query)
    if request.variables then
        log.debug(request.variables)
    end
    options = options or {}
    options.json = request
    local response = self:http_request('post', '/admin/api', options)
    local errors = response.json and response.json.errors
    if errors then
        error(errors[1].message)
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
            ) {
                join_server(
                    uri: $uri,
                    instance_uuid: $instance_uuid,
                    replicaset_uuid: $replicaset_uuid,
                    timeout: $timeout
                )
            }
        ]],
        variables = {
            uri = self.advertise_uri,
            instance_uuid = self.instance_uuid,
            replicaset_uuid = self.replicaset_uuid,
            timeout = options and options.timeout,
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
                $weight: Float
            ) {
                edit_replicaset(
                    uuid: $uuid,
                    alias: $alias,
                    roles: $roles,
                    master: $master,
                    weight: $weight
                )
            }
        ]],
        variables = {
            uuid = config.uuid,
            alias = config.alias,
            roles = config.roles,
            master = config.master,
            weight = config.weight,
        }
    })
end

--- Upload application config.
-- @tparam string|table config - table will be encoded as yaml and posted to /admin/config.
function Server:upload_config(config)
    checks('table', 'string|table')
    if type(config) == 'table' then
        config = yaml.encode(config)
    end
    return self:http_request('put', '/admin/config', {body = config})
end

--- Download application config.
function Server:download_config()
    return yaml.decode(self:http_request('get', '/admin/config').body)
end

return Server
