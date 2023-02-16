local fio = require('fio')
local fun = require('fun')
local log   = require('log')
local json  = require('json')
local fiber = require('fiber')
local http  = require('http.client')
local ffi = require('ffi')

local PREFIX = "feedback_daemon"
local METRICS_PREFIX = "metrics_collector"

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

-- copy-pasted from https://github.com/tarantool/tarantool/pull/8231/
local function collect_default_metrics()
    -- Do all the job in pcall for better reliability.
    local has_metrics, metrics = pcall(function()
        local metrics = require("metrics")
        -- Required version of metrics module is 0.16.0 or newer.
        -- A little cheat here - _VERSION field was introduced in 0.16.0,
        -- let's just check if it is not nil.
        if metrics._VERSION == nil then
            return nil
        end
        return metrics.collect({invoke_callbacks = true, default_only = true})
    end)
    if has_metrics then
        return metrics
    else
        return nil
    end
end

local trivial_obj_size = ffi.abi('gc64') and 0 or 8

-- copy-pasted from https://github.com/tarantool/tarantool/pull/8231/
local function obj_approx_size(obj)
    if type(obj) == 'table' then
        local size = 40
        for k, v in pairs(obj) do
            size = size + 16
            size = size + obj_approx_size(k)
            size = size + obj_approx_size(v)
        end
        return size
    elseif type(obj) == 'string' then
        return 17 + #obj
    else -- Number, boolean and nil
        return trivial_obj_size
    end
end

-- copy-pasted from https://github.com/tarantool/tarantool/pull/8231/
local function insert_metric(self, new_metric)
    local new_metric_size = obj_approx_size(new_metric)
    if self.metrics_size + new_metric_size <= self.metrics_limit then
        self.metrics_size = self.metrics_size + new_metric_size
        table.insert(self.metrics, new_metric)
    end
end

-- copy-pasted from https://github.com/tarantool/tarantool/pull/8231/
local function metrics_collect_loop(self)
    fiber.name(METRICS_PREFIX, { truncate = true })

    while true do
        local collect_timeout = self.metrics_collect_interval
        local st = pcall(fiber.sleep, collect_timeout)
        if not st then
            -- fiber was cancelled
            break
        end
        local new_metric = collect_default_metrics()
        if new_metric ~= nil then
            insert_metric(self, new_metric)
        end
    end
    self.shutdown:put("stopped")
end

-- copy-pasted from https://github.com/tarantool/tarantool/pull/8231/
local function guard_loop(self)
    fiber.name(string.format("guard of %s", PREFIX), {truncate=true})

    while true do

        if get_fiber_id(self.fiber) == 0 then
            self.fiber = fiber.create(feedback_loop, self)
            log.verbose("%s restarted", PREFIX)
        end
        if self.send_metrics and
            get_fiber_id(self.metrics_collect_fiber) == 0 then
            self.metrics_collect_fiber =
                fiber.create(metrics_collect_loop, self)
            log.verbose("%s restarted", METRICS_PREFIX)
        end
        local interval = self.interval
        if self.send_metrics then
            interval = math.min(interval, self.metrics_collect_interval)
        end
        local st = pcall(fiber.sleep, interval)

        if not st then
            -- fiber was cancelled
            break
        end
    end
    self.shutdown:put("stopped")
end

-- copy-pasted from https://github.com/tarantool/tarantool/pull/8231/
local function start(self)
    self:stop()
    if self.enabled then
        self.control = fiber.channel()
        self.shutdown = fiber.channel()
        self.metrics = {}
        self.metrics_size = 0
        self.metrics_sizes = {}
        self.guard = fiber.create(guard_loop, self)
    end
    log.verbose("%s started", PREFIX)
end

-- copy-pasted from https://github.com/tarantool/tarantool/pull/8231/
local function stop(self)
    if (get_fiber_id(self.guard) ~= 0) then
        self.guard:cancel()
        self.shutdown:get()
    end
    if (get_fiber_id(self.fiber) ~= 0) then
        self.control:put("stop")
        self.shutdown:get()
    end
    if get_fiber_id(self.metrics_collect_fiber) ~= 0 then
        self.metrics_collect_fiber:cancel()
        self.shutdown:get()
    end
    self.guard = nil
    self.fiber = nil
    self.metrics_collect_fiber = nil
    self.control = nil
    self.shutdown = nil
    self.metrics = {}
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

    local ok, listed_dir = pcall(fio.listdir, searchroot)
    if ok ~= true or listed_dir == nil then
        listed_dir = {}
    end

    local app_name_or = fun.iter(listed_dir):
        filter(function(x) return x:find('.rockspec') ~= nil end):totable()[1] or ''
    local app_name = app_name_or:gsub('%-scm%-1', ''):gsub('.rockspec', ''):match('[a-zA-z%-]+') or ''
    if app_name:sub(-1) == '-' then
        app_name = app_name:sub(1, -2)
    end
    local ok, app_version = pcall(require, 'VERSION')
    if ok ~= true then
        app_version = 'scm-1'
    end

    if feedback.app_name == nil and feedback.app_version == nil and app_name ~= '' then
        feedback.app_name = app_name
        feedback.app_version = app_version
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
