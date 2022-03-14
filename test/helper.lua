require('strict').on()

local fio = require('fio')
local checks = require('checks')
local digest = require('digest')
local helpers = table.copy(require('cartridge.test-helpers'))
local utils = require('cartridge.utils')

local errno = require('errno')
local errno_list = getmetatable(errno).__index
setmetatable(errno_list, {
    __index = function(_, k)
        error("errno '" .. k .. "' is not declared")
    end,
})

helpers.project_root = fio.dirname(debug.sourcedir())

fio.tempdir = function(base)
    base = base or os.getenv('TMPDIR') or '/tmp'
    local random = digest.urandom(9)
    local suffix = digest.base64_encode(random, {urlsafe = true})
    local path = fio.pathjoin(base, 'tmp.cartridge.' .. suffix)
    fio.mktree(path)
    return path
end

function helpers.entrypoint(name)
    local path = fio.pathjoin(
        helpers.project_root,
        'test', 'entrypoint',
        string.format('%s.lua', name)
    )
    if not fio.path.exists(path) then
        error(path .. ': no such entrypoint', 2)
    end
    return path
end

function helpers.table_find_by_attr(tbl, key, value)
    for _, v in pairs(tbl) do
        if v[key] == value then
            return v
        end
    end
end

function helpers.list_cluster_issues(server)
    return server:graphql({query = [[{
        cluster {
            issues {
                level
                message
                replicaset_uuid
                instance_uuid
                topic
            }
        }
    }]]}).data.cluster.issues
end

function helpers.get_suggestions(server)
    return server:graphql({
        query = [[{
            cluster { suggestions {
                refine_uri {
                    uuid
                    uri_old
                    uri_new
                }
                force_apply {
                    uuid
                    config_locked
                    config_mismatch
                    operation_error
                }
                disable_servers  {
                    uuid
                }
                restart_replication  {
                    uuid
                }
            }}
        }]]
    }).data.cluster.suggestions
end

function helpers.box_cfg()
    if type(box.cfg) ~= 'function' then
        return
    end

    local tempdir = fio.tempdir()
    box.cfg({
        memtx_dir = tempdir,
        wal_mode = 'none',
    })
    fio.rmtree(tempdir)
end

function helpers.wish_state(srv, desired_state, timeout)
    srv.net_box:eval([[
        local confapplier = require('cartridge.confapplier')
        local desired_state, timeout = ...
        local state = confapplier.wish_state(desired_state, timeout)
        if state ~= desired_state then
            local err = string.format(
                'Inappropriate state %q ~= desired %q',
                state, desired_state
            )
            error(err, 0)
        end
    ]], {desired_state, timeout})
end

function helpers.protect_from_rw(srv)
    srv.net_box:eval([[
        local log = require('log')
        local fiber = require('fiber')
        local function protection()
            log.warn('Instance protected from becoming rw')
            if pcall(box.ctl.wait_rw) then
                log.error('DANGER! Instance is rw!')
                os.exit(-1)
            end
        end
        _G._protection_fiber = fiber.new(protection)
        fiber.sleep(0)
    ]])
end

function helpers.unprotect(srv)
    srv.net_box:eval([[
        _G._protection_fiber:cancel()
    ]])
end

function helpers.assert_ge(actual, expected, message)
    if not (actual >= expected) then
        local err = string.format('expected: %s >= %s', actual, expected)
        if message ~= nil then
            err = message .. '\n' .. err
        end
        error(err, 2)
    end
end

function helpers.assert_le(actual, expected, message)
    if not (actual <= expected) then
        local err = string.format('expected: %s <= %s', actual, expected)
        if message ~= nil then
            err = message .. '\n' .. err
        end
        error(err, 2)
    end
end

function helpers.random_cookie()
    return digest.urandom(6):hex()
end

function helpers.run_remotely(srv, fn)
    checks('table', 'function')
    utils.assert_upvalues(fn, {})

    local ok, ret = srv.net_box:eval([[
        local fn = loadstring(...)
        return pcall(fn)
    ]], {string.dump(fn)})

    if not ok then
        error(ret, 0)
    end

    return ret
end

function helpers.tarantool_version_ge(version)
    local function parse_version(version)
        local version = version:split('-')[1]:split('.')
        for ind, val in ipairs(version) do
            version[ind] = tonumber(val)
        end
        return version
    end

    local tarantool_version = parse_version(_G._TARANTOOL)
    local requested_version = parse_version(version)

    for ind=1,3 do
        if tarantool_version[ind] > requested_version[ind] then
            return true
        elseif tarantool_version[ind] < requested_version[ind] then
            return false
        end
    end

    return true
end

-- Function to check if the error is a timeout error. The function
-- works for old and new error type in net.box functions.
function helpers.is_timeout_error(error_msg)
    if type(error_msg) ~= "string" then
        error_msg = tostring(error_msg)
    end
    return  string.find(error_msg, 'Timeout exceeded') ~= nil or  string.find(error_msg, 'timed out') ~= nil
end

return helpers
