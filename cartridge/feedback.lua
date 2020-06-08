local fio = require('fio')
local log   = require('log')
local json  = require('json')
local fiber = require('fiber')
local http  = require('http.client')

local PREFIX = "feedback_daemon"

local daemon = box.internal.feedback_daemon
if daemon == nil then
    return nil
end

local _daemon_mt = getmetatable(daemon)

-- copy-pasted from tarantool-1.10.3-124-g3b1e75ece
local function get_fiber_id(f)
    local fid = 0
    if f ~= nil and f:status() ~= "dead" then
        fid = f:id()
    end
    return fid
end

-- copy-pasted from tarantool-1.10.3-124-g3b1e75ece
local function feedback_loop(self)
    fiber.name(PREFIX, { truncate = true })

    while true do
        local feedback = self:generate_feedback()
        local msg = self.control:get(self.interval)
        -- if msg == "send" then we simply send feedback
        if msg == "stop" then
            break
        elseif feedback ~= nil then
            pcall(http.post, self.host, json.encode(feedback), {timeout=1})
        end
    end
    self.shutdown:put("stopped")
end

-- copy-pasted from tarantool-1.10.3-124-g3b1e75ece
local function guard_loop(self)
    fiber.name(string.format("guard of %s", PREFIX), {truncate=true})

    while true do

        if get_fiber_id(self.fiber) == 0 then
            self.fiber = fiber.create(feedback_loop, self)
            log.verbose("%s restarted", PREFIX)
        end
        local st, _ = pcall(fiber.sleep, self.interval)
        if not st then
            -- fiber was cancelled
            break
        end
    end
    self.shutdown:put("stopped")
end

-- copy-pasted from tarantool-1.10.3-124-g3b1e75ece
local function start(self)
    self:stop()
    if self.enabled then
        self.control = fiber.channel()
        self.shutdown = fiber.channel()
        self.guard = fiber.create(guard_loop, self)
    end
    log.verbose("%s started", PREFIX)
end

-- copy-pasted from tarantool-1.10.3-124-g3b1e75ece
local function stop(self)
    if (get_fiber_id(self.guard) ~= 0) then
        self.guard:cancel()
        self.shutdown:get()
    end
    if (get_fiber_id(self.fiber) ~= 0) then
        self.control:put("stop")
        self.shutdown:get()
    end
    self.guard = nil
    self.fiber = nil
    self.control = nil
    self.shutdown = nil
    log.verbose("%s stopped", PREFIX)
end

-- We copy-paste most of the code because old tarantool
-- versions (< 1.10.3-124-g3b1e75ece) did use
-- closures on local functions, which didn't allow to
-- monkey-patch generate_feedback()
function _daemon_mt.__index.start()
    start(daemon)
end

function _daemon_mt.__index.stop()
    stop(daemon)
end

-- Finally, monkey-patch generate_feedback function
-- and inject additional information about rocks
local _generate_feedback = _daemon_mt.__index.generate_feedback
function _daemon_mt.__index.generate_feedback()
    local feedback, err = _generate_feedback()
    if feedback == nil then
        return nil, err
    end

    if feedback.rocks == nil then
        feedback.rocks = {}
    end

    feedback.rocks['cartridge'] = require('cartridge').VERSION

    local searchroot
    if package.searchroot ~= nil then
        searchroot = package.searchroot()
    else
        searchroot = fio.abspath(fio.dirname(arg[0]))
    end

    local manifest = {}
    local manifest_path = fio.pathjoin(searchroot,
        '.rocks/share/tarantool/rocks/manifest'
    )

    if not pcall(loadfile(manifest_path, 't', manifest))
    or type(manifest.dependencies) ~= 'table'
    then
        return feedback
    end

    for rock_name, versions in pairs(manifest.dependencies) do
        if feedback.rocks[rock_name] == nil then
            feedback.rocks[rock_name] = next(versions)
        end
    end

    return feedback
end

return daemon
