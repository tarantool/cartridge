require('strict').on()

local fio = require('fio')
local digest = require('digest')
local helpers = table.copy(require('cartridge.test-helpers'))

helpers.project_root = fio.dirname(debug.sourcedir())

local __fio_tempdir = fio.tempdir
fio.tempdir = function(base)
    base = base or os.getenv('TMPDIR')
    if base == nil or base == '/tmp' then
        return __fio_tempdir()
    else
        local random = digest.urandom(9)
        local suffix = digest.base64_encode(random, {urlsafe = true})
        local path = fio.pathjoin(base, 'tmp.cartridge.' .. suffix)
        fio.mktree(path)
        return path
    end
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

return helpers
