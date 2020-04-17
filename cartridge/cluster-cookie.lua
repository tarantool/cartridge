local os = require('os')
local fio = require('fio')
local errno = require('errno')

local M = rawget(_G, '__module_cluster_cookie')
if not M then
    M = {
        workdir = nil,
        filenames = nil,
        cookie = nil,
    }
end
local COOKIEFILE = '.tarantool.cookie'

local function file_exists(name)
    return fio.stat(name) ~= nil
end

local function read_file(path)
    local file = fio.open(path)
    if file == nil then
        return nil
    end
    local val = file:read(256)

    file:close()
    return val
end

local function write_file(path, data)
    local rc, err = fio.mktree(fio.dirname(path))
    if not rc and err then
        error(err)
    end

    local file = fio.open(path, {'O_CREAT', 'O_WRONLY', 'O_TRUNC'}, tonumber(600, 8))
    if file == nil then
        error(('Failed to open file %s: %s'):format(path, errno.strerror()))
    end

    local res = file:write(data)
    if not res then
        file:close()
        error(('Failed to write to file %s: %s'):format(path, errno.strerror()))
    end

    file:close()
    return data
end

local function init(workdir)
    M.workdir = workdir or os.getenv('WORKDIR') or fio.cwd()

    local files = {
        fio.pathjoin(M.workdir, COOKIEFILE),
    }

    local homedir = os.getenv('HOME')
    if homedir then
        table.insert(files, fio.pathjoin(homedir, COOKIEFILE))
    end

    for _, path in ipairs(files) do
        if file_exists(path) then
            local attempt = read_file(path)
            if attempt ~= nil then
                M.filename = path
                M.cookie = attempt
                break
            end
        end
    end
end

local function cookie()
    return M.cookie
end

local function filename()
    return M.filename
end

local function username()
    return 'admin'
end

local function set_cookie(value)
    if M.workdir == nil then
        error('Cluster cookie not initialized', 2)
    end
    if value == nil then
        error('Could not set nil cluster cookie', 2)
    end
    if #value > 256 then
        error('Could not set cluster cookie with length more than 256', 2)
    end

    local bad_symbols = string.match(value, '[^%w%-%.~_]+')
    if bad_symbols ~= nil then
        error(string.format(
            'Invalid symbol %q in cluster cookie', bad_symbols
        ), 2)
    end

    write_file(fio.pathjoin(M.workdir, COOKIEFILE), value)

    init(M.workdir)
end

return {
    init = init,
    cookie = cookie,
    set_cookie = set_cookie,
    username = username,
    filename = filename,
}
