local t = require('luatest')
local fio = require('fio')
local errors = require('errors')
local digest = require('digest')
local helpers = table.copy(require('cartridge.test-helpers'))

helpers.project_root = fio.dirname(debug.sourcedir())

local __fio_tempdir = fio.tempdir
fio.tempdir = function()
    local base = os.getenv('TMPDIR')
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

function helpers.assert_error_tuple(expected_err, tuple_ok, tuple_err)
    if type(expected_err) ~= 'table' then
        error(
            string.format('Bad argument #1 ' ..
                '(table expected, got %s)', type(expected_err)
            ), 2
        )
    end

    local ok, err = pcall(t.assert_equals, tuple_ok, nil, 'Bad first tuple element')
    if not ok then
        error(err.message, 2)
    end

    if not errors.is_error_object(tuple_err) then
        error(
            string.format('Bad second tuple element ' ..
                '(error object expected, got %s)', type(tuple_err)
            ), 2
        )
    end

    local ok, err = pcall(require('luatest').assert_covers, tuple_err, expected_err)
    if not ok then
        require('log').info(err)
        error(err.message, 2)
    end
    return true
end


return helpers
