local fio = require('fio')
local json = require('json')
local checks = require('checks')
local errors = require('errors')
local digest = require('digest')
local httpc = require('http.client')

local HttpError  = errors.new_class('HttpError')
local EtcdError  = errors.new_class('EtcdError')
local EtcdConnectionError  = errors.new_class('EtcdConnectionError')

-- The implicit state machine machine approximately reproduces
-- the one of net.box connection:
--
-- initial -> connected -> closed

local function request(connection, method, path, args, opts)
    checks('etcd2_connection', 'string', 'string', '?table', {
        timeout = '?number',
    })

    local ok, err = connection:_discovery()
    if not ok then
        return nil, err
    else
        assert(connection.state == 'connected')
    end

    assert(connection.etcd_cluster_id ~= nil)

    local body = {}
    if args ~= nil then
        for k, v in pairs(args) do
            table.insert(body, k .. '=' .. tostring(v))
        end
    end
    local body = table.concat(body, '&')
    local path = fio.pathjoin('/v2/keys', connection.prefix, path)
    -- Workaround for https://github.com/tarantool/tarantool/issues/4173
    -- Built-in taratool http.client substitutes GET with POST if
    -- body is not nil.
    if method == 'GET' and body ~= '' then
        path = path .. '?' .. body
        body = nil
    end

    local http_opts = {
        headers = {
            ['Connection'] = 'Keep-Alive',
            ['Content-Type'] = 'application/x-www-form-urlencoded',
            ['Authorization'] = connection.http_auth,
        },
        timeout = (opts and opts.timeout) or connection.request_timeout,
        verbose = connection.verbose,
    }

    local lasterror
    local num_endpoints = #connection.endpoints
    assert(num_endpoints > 0)

    for i = 0, num_endpoints - 1 do
        local eidx = connection.eidx + i
        if eidx > num_endpoints then
            eidx = eidx % num_endpoints
        end

        local url = connection.endpoints[eidx] .. path
        local resp = httpc.request(method, url, body, http_opts)
        if resp == nil or resp.status >= 500 then
            lasterror = HttpError:new('%s: %s',
                url, resp and (resp.body or resp.reason)
            )
            goto continue
        end

        local etcd_cluster_id = resp.headers and resp.headers['x-etcd-cluster-id']
        if etcd_cluster_id ~= connection.etcd_cluster_id then
            lasterror = EtcdConnectionError:new('Etcd cluster id mismatch')
            goto continue
        end

        local ok, data = pcall(json.decode, resp.body)
        if not ok then
            lasterror = HttpError:new(resp.body or resp.reason)
            lasterror.http_code = resp.status
            if resp.status == 408 then -- timeout
                return nil, lasterror
            else
                goto continue
            end
        end

        connection.eidx = eidx
        if data.errorCode then
            local err = EtcdError:new('%s (%s): %s',
                data.message, data.errorCode, data.cause
            )
            err.http_code = resp.status
            err.etcd_code = data.errorCode
            err.etcd_index = data.index
            return nil, err
        else
            return data
        end

        ::continue::
    end

    -- Not a single endpoint was able to reply conforming etcd protocol.
    -- We better close the connection and try to reconnect later.
    connection:close()

    assert(lasterror ~= nil)
    return nil, lasterror
end

local function _discovery(connection)
    checks('etcd2_connection')

    ::start_over::
    if connection.state == 'connected' then
        return true
    elseif connection.state == 'closed' then
        return nil, EtcdConnectionError:new('Connection closed')
    end

    local lasterror
    for _, e in pairs(connection.endpoints) do
        local url = e .. "/v2/members"
        local resp = httpc.get(url, {
            headers = {
                ['Connection'] = 'Keep-Alive',
                ['Authorization'] = connection.http_auth,
            },
            timeout = connection.request_timeout,
            verbose = connection.verbose,
        })

        if connection.state ~= 'initial' then
            -- something may change during network yield
            goto start_over
        end

        if resp == nil
        or resp.status ~= 200
        then
            lasterror = HttpError:new('%s: %s',
                url, resp and (resp.body or resp.reason)
            )
            goto continue
        end

        local ok, data = pcall(json.decode, resp.body)
        if not ok then
            lasterror = EtcdConnectionError:new(
                'Discovery failed, unexpeced response: %s', data
            )
            goto continue
        end

        local hash_endpoints = {}
        for _, m in pairs(data.members) do
            for _, u in pairs(m.clientURLs) do
                hash_endpoints[u] = true
            end
        end

        local new_endpoints = {}
        for k, _ in pairs(hash_endpoints) do
            table.insert(new_endpoints, k)
        end

        if #new_endpoints > 0 then
            connection.etcd_cluster_id = resp.headers['x-etcd-cluster-id']
            connection.endpoints = new_endpoints
            connection.eidx = math.random(#new_endpoints)
            connection.state = 'connected'
            return true
        end

        lasterror = EtcdConnectionError:new('Discovered nothing')
        ::continue::
    end

    assert(lasterror ~= nil)
    return nil, lasterror
end

local function close(connection)
    checks('etcd2_connection')
    if connection.state == 'closed' then
        return
    end

    table.clear(connection.endpoints)
    connection.state = 'closed'
end

local function is_connected(connection)
    checks('etcd2_connection')
    return connection.state == 'connected'
end

local etcd2_connection_mt = {
    __type = 'etcd2_connection',
    __index = {
        _discovery = _discovery,
        is_connected = is_connected,
        request = request,
        close = close,
    },
}

local function connect(endpoints, opts)
    checks('table', {
        prefix = 'string',
        request_timeout = 'number',
        username = 'string',
        password = 'string',
    })

    local connection = setmetatable({}, etcd2_connection_mt)
    connection.state = 'initial'
    connection.prefix = opts.prefix
    connection.endpoints = table.copy(endpoints)
    connection.request_timeout = opts.request_timeout
    connection.verbose = false
    if opts.username ~= '' then
        local credentials = opts.username .. ":" .. opts.password
        connection.http_auth = "Basic " .. digest.base64_encode(credentials)
    end

    return connection
end

return {
    connect = connect,

    EcodeKeyNotFound        = 100;
    EcodeTestFailed         = 101;
    EcodeNotFile            = 102;
    EcodeNotDir             = 104;
    EcodeNodeExist          = 105;
    EcodeRootROnly          = 107;
    EcodeDirNotEmpty        = 108;
    EcodePrevValueRequired  = 201;
    EcodeTTLNaN             = 202;
    EcodeIndexNaN           = 203;
    EcodeInvalidField       = 209;
    EcodeInvalidForm        = 210;
    EcodeRaftInternal       = 300;
    EcodeLeaderElect        = 301;
    EcodeWatcherCleared     = 400;
    EcodeEventIndexCleared  = 401;
}
