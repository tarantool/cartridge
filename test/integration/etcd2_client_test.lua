local t = require('luatest')
local g = t.group()

local fio = require('fio')
local uuid = require('uuid')
local json = require('json')
local fiber = require('fiber')
local etcd2 = require('cartridge.etcd2')
local httpc = require('http.client')
local digest = require('digest')
local etcd2_client = require('cartridge.etcd2-client')

local helpers = require('test.helper')

local URI = 'http://127.0.0.1:14001'

local function create_client(username, password)
    return etcd2_client.new({
        prefix = 'etcd2_client_test',
        lock_delay = g.lock_delay,
        endpoints = {URI},
        username = username or '',
        password = password or '',
        request_timeout = 1,
    })
end

g.before_each(function()
    local etcd_path = os.getenv('ETCD_PATH')
    t.skip_if(etcd_path == nil, 'etcd missing')

    -- Etcd has a specific feature: upon restart it preallocates
    -- WAL file with 64MB size, and it can't be configured.
    -- See https://github.com/etcd-io/etcd/issues/9422
    --
    -- Our Gitlab CI uses tmpfs at `/dev/shm` as TMPDIR.
    -- It's size is also limited, in our case the same 64MB.
    -- As a result, restarting etcd fails with an error:
    -- C | etcdserver: open wal error: no space left on device
    --
    -- As a workaround we start etcd with workdir in `/tmp` and
    -- ignore TMPDIR setting
    g.datadir = fio.tempdir('/tmp')

    g.etcd_a = helpers.Etcd:new({
        name = 'a',
        workdir = g.datadir .. '/a',
        etcd_path = etcd_path,
        peer_url = 'http://127.0.0.1:17001',
        client_url = URI,
        env = {
            ETCD_INITIAL_ADVERTISE_PEER_URLS = 'http://127.0.0.1:17001',
            ETCD_INITIAL_CLUSTER = 'a=http://127.0.0.1:17001',
        }
    })
    g.etcd_a:start()

    local resp = httpc.post(URI ..'/v2/members',
        json.encode({peerURLs = {'http://127.0.0.1:17002'}}),
        {headers = {['Content-Type'] = 'application/json'}}
    )
    t.assert(resp.status == 201, resp.body)

    g.etcd_b = helpers.Etcd:new({
        name = 'b',
        workdir = g.datadir .. '/b',
        etcd_path = etcd_path,
        peer_url = 'http://127.0.0.1:17002',
        client_url = 'http://127.0.0.1:14002',
        env = {
            ETCD_INITIAL_ADVERTISE_PEER_URLS = 'http://127.0.0.1:17002',
            ETCD_INITIAL_CLUSTER_STATE = 'existing',
            ETCD_INITIAL_CLUSTER =
                'a=http://127.0.0.1:17001,' ..
                'b=http://127.0.0.1:17002',
        }
    })
    g.etcd_b:start()

    g.lock_delay = 40
end)

g.after_each(function()
    g.etcd_a:stop()
    g.etcd_b:stop()
    fio.rmtree(g.datadir)
end)

function g.test_locks()
    local c1 = create_client():get_session()
    local c2 = create_client():get_session()
    local kid = uuid.str()

    t.assert_equals(
        c1:acquire_lock({uuid = kid, uri ='localhost:9'}),
        true
    )
    t.assert_equals(
        c1:get_coordinator(),
        {uuid = kid, uri = 'localhost:9'}
    )

    t.assert_equals(
        c2:acquire_lock({uuid = uuid.str(), uri = 'localhost:11'}),
        false
    )

    local ok, err = c2:set_leaders({{'A', 'a1'}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'SessionError',
        err = 'You are not holding the lock'
    })

    t.assert_equals(
        c2:get_coordinator(),
        {uuid = kid, uri = 'localhost:9'}
    )

    t.assert(c1:drop(), true)

    local kid = uuid.str()
    helpers.retrying({}, function()
        t.assert_equals({c2:get_coordinator()}, {nil})
    end)

    t.assert_equals(
        c2:acquire_lock({uuid = kid, uri = 'localhost:11'}),
        true
    )
    t.assert_equals(
        c2:get_coordinator(),
        {uuid = kid, uri = 'localhost:11'}
    )
end

function g.test_appointments()
    local c = create_client():get_session()
    local kid = uuid.str()
    t.assert_equals(
        c:acquire_lock({uuid = kid, uri = 'localhost:9'}),
        true
    )

    t.assert_equals(
        c:set_leaders({{'A', 'a1'}, {'B', 'b1'}}),
        true
    )

    t.assert_equals(
        c:get_leaders(),
        {A = 'a1', B = 'b1'}
    )

    local ok, err = c:set_leaders({{'A', 'a2'}, {'A', 'a3'}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'SessionError',
        err = 'Duplicate key in updates'
    })
end

function g.test_longpolling()
    local c1 = create_client():get_session()
    local kid = uuid.str()
    t.assert_equals(
        c1:acquire_lock({uuid = kid, uri = 'localhost:9'}),
        true
    )
    c1:set_leaders({{'A', 'a1'}, {'B', 'b1'}})

    local client = create_client()
    local function async_longpoll()
        local chan = fiber.channel(1)
        fiber.new(function()
            local ret, err = client:longpoll(0.2)
            chan:put({ret, err})
        end)
        return chan
    end

    t.assert_equals(client:longpoll(0.5), {A = 'a1', B = 'b1'})

    local chan = async_longpoll()
    t.assert(c1:set_leaders({{'A', 'a2'}}), true)
    t.assert_equals(chan:get(0.2), {{A = 'a2', B = 'b1'}})

    local chan = async_longpoll()
    -- there is no data in channel
    t.assert_equals(chan:get(0.1), nil)

    -- data recieved
    t.assert_equals(chan:get(0.2), {{}})
end

function g.test_event_cleared()
    local httpc = httpc.new({max_connections = 100})
    local function set_leaders(leaders)
        local resp = httpc:put(
            URI .. '/v2/keys/etcd2_client_test/leaders',
            'value=' .. json.encode(leaders)
        )
        t.assert_covers(resp, {reason = "Ok"})
    end

    local client1 = create_client()
    local client2 = create_client()

    set_leaders({A = 'a1'})
    t.assert_equals(client1:longpoll(0.2), {A = 'a1'})
    t.assert_equals(client2:longpoll(0.2), {A = 'a1'})

    -- Cause the error "The event in requested index is outdated and
    -- cleared" by inserting 1000 values. The number 1000 is hardcoded
    -- in the etcd source code:
    -- https://github.com/etcd-io/etcd/blob/master/server/etcdserver/api/v2store/store.go#L101
    -- See also: https://github.com/etcd-io/etcd/issues/925#issuecomment-51722404
    local fiber_map = {}
    for i = 1, 100 do
        local fiber_object = fiber.new(function()
            for _ = 1, 11 do
                httpc:put(URI .. '/v2/keys/foo?value=bar')
            end
        end)
        fiber_object:set_joinable(true)
        fiber_map[i] = fiber_object
    end

    for _, fiber_object in ipairs(fiber_map) do
        fiber_object:join()
    end

    -- Self-test. We check the behavior of
    local resp = httpc:get(URI .. '/v2/keys/foo' ..
        '?wait=true&waitIndex=' .. (client1.session.longpoll_index + 1)
    )
    t.assert_covers(resp, {status = 400})
    t.assert_covers(json.decode(resp.body),
        {errorCode = etcd2.EcodeEventIndexCleared}
    )

    --  ----s---|-------
    --       ^         ^
    -- In case of cleared history long-polling algorithm will return
    -- old leaders even if they haven't changed
    t.assert_equals(client1:longpoll(0.1), {A = 'a1'})

    --  ----s---|----x--
    --       ^         ^
    set_leaders({A = 'a2'})
    t.assert_equals(client2:longpoll(0.1), {A = 'a2'})

    -- Check that longpoll_index is updated despite leaders aren't modified
    local old_index = client2.session.longpoll_index
    httpc:put(URI .. '/v2/keys/foo?value=buzz')
    t.assert_equals(client2:longpoll(0.5), {})
    t.assert_equals(client2.session.longpoll_index, old_index + 1)
end

function g.test_client_drop_session()
    local client = create_client()
    local session = client:get_session()
    t.assert_equals(session:is_alive(), true)
    t.assert_is(client:get_session(), session)

    local ok = session:acquire_lock({uuid = 'uuid', uri = 'uri'})
    t.assert_equals(ok, true)
    t.assert_equals(session:is_alive(), true)
    t.assert_equals(session:is_locked(), true)
    t.assert_is(client:get_session(), session)

    client:drop_session()

    local ok, err = session:get_leaders()
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'SessionError',
        err = 'Session is dropped',
    })

    -- dropping session releases lock and make it dead
    t.assert_equals(session:is_alive(), false)
    t.assert_equals(session:is_locked(), false)

    -- dropping session is idempotent
    client:drop_session()
    t.assert_equals(session:is_alive(), false)
    t.assert_equals(session:is_locked(), false)

    t.assert_is_not(client:get_session(), session)
end

function g.test_outage()
    -- Test case:
    -- 1. Coordinator C1 acquires a lock and freezes;
    -- 2. Lock delay expires and stateboard allows C2 to acquire it again;
    -- 3. C2 writes some decisions and releases a lock;
    -- 4. C1 comes back;
    -- Goal: C1 must be informed on his outage

    g.lock_delay = 0

    local payload = {uuid = uuid.str(), uri = 'localhost:9'}

    local c1 = create_client():get_session()
    t.assert_equals(
        {c1:acquire_lock(payload)},
        {true}
    )
    t.assert_equals(
        -- C1 can renew expired lock if it wasn't stolen yet
        {c1:acquire_lock(payload)},
        {true}
    )

    local c2 = create_client():get_session()
    t.helpers.retrying({}, function()
        t.assert_equals(
            {c2:acquire_lock(payload)},
            {true}
        )
    end)

    c2:drop()

    -- C1 can't renew lock after it was stolen by C2
    local ok, err = c1:acquire_lock(payload)
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'SessionError',
        err = 'The lock was stolen'
    })

    local ok, err = c1:set_leaders({})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'SessionError',
        err = 'You are not holding the lock'
    })
end

function g.test_client_session()
    -- get_session always returns alive one
    local client = create_client()
    local session = client:get_session()
    t.assert_equals(session:is_alive(), true)
    t.assert_is(client:get_session(), session)

    local ok = session:acquire_lock({uuid = 'uuid', uri = 'uri'})
    t.assert_equals(ok, true)
    t.assert_equals(session:is_alive(), true)
    t.assert_equals(session:is_locked(), true)
    t.assert_is(client:get_session(), session)

    -- get_session creates new session if old one is dead
    httpc.delete(URI .. '/v2/keys/etcd2_client_test/lock')

    t.helpers.retrying({}, function()
        t.assert_equals(
            session:acquire_lock({uuid = 'uuid', uri = 'uri'}),
            nil
        )
    end)

    local ok, err = session:get_leaders()
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'SessionError',
        err = 'Session is dropped',
    })
    t.assert_is_not(client:get_session(), session)

    -- session looses lock if connection is interrupded
    t.assert_equals(session:is_alive(), false)
    t.assert_equals(session:is_locked(), false)
end

function g.test_authentication()
    local password = digest.urandom(6):hex()
    local credentials = "root:" .. password
    local http_auth = "Basic " .. digest.base64_encode(credentials)

    helpers.retrying({}, function()
        -- Without retrying it fails sometimes with an error message:
        -- "Not capable of accessing auth feature during rolling upgrades"
        local resp = httpc.put(URI .. '/v2/auth/users/root', json.encode({
            user = 'root',
            password = password,
        }))
        t.assert(resp.status == 201, resp.body)
    end)

    local resp = httpc.put(URI .. '/v2/auth/enable')
    t.assert(resp.status == 200, resp.body)
    local resp = httpc.put(URI .. '/v2/auth/roles/guest', json.encode({
        role = 'guest',
        revoke = {kv = {
            read = {'/*'},
            write = {'/*'},
        }},
    }), {
        verbose = true,
        headers = {['Authorization'] = http_auth},
    })
    t.assert(resp.status == 200, resp.body)

    local payload = {uuid = uuid.str(), uri = 'localhost:9'}

    local c1 = create_client():get_session()
    local c2 = create_client('root', 'fraud'):get_session()
    local c3 = create_client('root', password):get_session()

    -- C1 isn't authorized
    local ok, err = c1:acquire_lock(payload)
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'EtcdError',
        err = 'The request requires user authentication' ..
            ' (110): Insufficient credentials',
    })

    local ok, err = c2:acquire_lock(payload)
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'EtcdError',
        err = 'The request requires user authentication' ..
            ' (110): Insufficient credentials',
    })

    local ok, err = c3:acquire_lock(payload)
    t.assert_equals({ok, err}, {true, nil})
end

function g.test_vclockkeeper()
    local client = create_client()
    local session = client:get_session()

    local ok, err = session:get_vclockkeeper('A')
    t.assert_equals(ok, nil)
    t.assert_equals(err, nil)

    local ok, err = session:set_vclockkeeper('A', 'a1')
    t.assert_equals({ok, err}, {true, nil})
    t.assert_equals(session:get_vclockkeeper('A'), {
        replicaset_uuid = 'A',
        instance_uuid = 'a1',
    })

    local ok, err = session:set_vclockkeeper('A', 'a1', {[1] = 10})
    t.assert_equals({ok, err}, {true, nil})
    t.assert_equals(session:get_vclockkeeper('A'), {
        replicaset_uuid = 'A',
        instance_uuid = 'a1',
        vclock = {[1] = 10},
    })

    local ok, err = session:set_vclockkeeper('A', 'a1')
    t.assert_equals({ok, err}, {true, nil})
    t.assert_equals(session:get_vclockkeeper('A'), {
        replicaset_uuid = 'A',
        instance_uuid = 'a1',
        vclock = {[1] = 10},
    })

    local ok, err = session:set_vclockkeeper('A', 'a2')
    t.assert_equals({ok, err}, {true, nil})
    t.assert_equals(session:get_vclockkeeper('A'), {
        replicaset_uuid = 'A',
        instance_uuid = 'a2',
    })

    local chan_success = fiber.channel(1)
    local chan_fail = fiber.channel(1)
    local function set_vclockkeeper_async(r, s, vclock)
        fiber.new(function()
            local res, err = session:set_vclockkeeper(r, s, vclock)
            if res ~= nil then
                local vclockkeeper = {
                    replicaset_uuid = r,
                    instance_uuid = s,
                    vclock = vclock
                }
                chan_success:put({res, err, vclockkeeper})
            else
                chan_fail:put({res, err})
            end
        end)
    end

    g.etcd_a.process:kill('STOP')
    set_vclockkeeper_async('A', 'a3', {[1] = 101})
    set_vclockkeeper_async('A', 'a3', {[1] = 102})
    fiber.sleep(0)
    g.etcd_a.process:kill('CONT')

    local ret1, err1, vclockkeeper = unpack(chan_success:get(0.2))
    t.assert_equals({ret1, err1}, {true, nil})
    local ret2, err2 = unpack(chan_fail:get(0.2))
    t.assert_equals(ret2, nil)
    t.assert_equals(err2.class_name, 'EtcdError')
    t.assert_str_matches(err2.err,
        'Vclockkeeper changed between calls %- Compare failed %(%d+%): %[%d+ != %d+%]'
    )

    t.assert_equals(session:get_vclockkeeper('A'), vclockkeeper)

    g.etcd_b.process:kill('STOP')
    set_vclockkeeper_async('B', 'b1')
    set_vclockkeeper_async('B', 'b2')
    fiber.sleep(0)
    g.etcd_b.process:kill('CONT')

    local ret1, err1, vclockkeeper = unpack(chan_success:get(0.2))
    t.assert_equals({ret1, err1}, {true, nil})
    local ret2, err2 = unpack(chan_fail:get(0.2))
    t.assert_equals(ret2, nil)
    t.assert_equals(err2.class_name, 'EtcdError')
    t.assert_str_matches(err2.err,
        'Key already exists %(%d+%): ' ..
        '/etcd2_client_test/vclockkeeper/B'
    )

    t.assert_equals(session:get_vclockkeeper('B'), vclockkeeper)
end

function g.test_quorum()
    local client = create_client()
    t.assert_equals(client:check_quorum(), true)

    g.etcd_b.process:kill('STOP')
    t.assert_equals(client:check_quorum(), false)

    g.etcd_a.process:kill('STOP')
    t.assert_equals(client:check_quorum(), false)

    g.etcd_b.process:kill('CONT')
    t.assert_equals(client:check_quorum(), false)

    g.etcd_a.process:kill('CONT')
    t.helpers.retrying({}, function()
        t.assert_equals(client:check_quorum(), true)
    end)
end


function g.test_promote_after_close()
    local non_existent_uri = 'http://127.0.0.1:14002'
    local client = etcd2_client.new({
        prefix = 'etcd2_client_test',
        lock_delay = g.lock_delay,
        -- here we should have two endpoints, the first one
        -- is not available, so we request the next one
        endpoints = {non_existent_uri, URI},
        username = '',
        password = '',
        request_timeout = 1,
    })
    local session = client:get_session()

    session.connection:request('PUT', '/lock', {value = true})

    local httpc = package.loaded['http.client']
    local old_request = httpc.request
    rawset(package.loaded['http.client'], 'request', function(method, url, ...)
        if url == non_existent_uri .. '/v2/keys/etcd2_client_test/lock' then
            table.clear(session.connection.endpoints)
            return {reason = 'Artificial error'}
        end
        return old_request(method, url, ...)

    end)

    -- previously here was error 'attempt to concatenate a nil value'
    local ok, err = session.connection:request('GET', '/lock')
    t.xfail_if(ok, 'Right order')
    t.assert_equals(ok, nil)
    t.assert_str_contains(err.err, 'Artificial error')

    rawset(package.loaded['http.client'], 'request', old_request)
end
