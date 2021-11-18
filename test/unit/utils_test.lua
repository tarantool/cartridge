local t = require('luatest')
local g = t.group()

local utils = require('cartridge.utils')

function g.test_upvalues()
    local f
    do
        local t1, t2 = 1, 2
        function f() return t1, t2 end
    end

    utils.assert_upvalues(f, {'t1', 't2'})
    t.assert_error_msg_equals(
        'Unexpected upvalues, [t3] expected, got [t1, t2]',
        utils.assert_upvalues, f, {'t3'}
    )
end

function g.test_randomize_path()
    local digest = require('digest')
    local urandom_original = digest.urandom
    digest.urandom = function(n) return string.rep("\0", n) end

    t.assert_equals(
        utils.randomize_path('/some/file'),
        '/some/file.AAAAAAAAAAAA'
    )

    t.assert_equals(
        utils.randomize_path('/some/dir/'),
        '/some/dir.AAAAAAAAAAAA'
    )

    digest.urandom = urandom_original
end

function g.test_http_read_body()
    local body = '--c187dde3e9318fcc6509f45f76a89424\r\n'..
    'Content-Disposition: form-data; name="file"; filename="sample.txt"\r\n' ..
    'Content-Type: text/plain\r\n' ..
    '\r\n' ..
    'Content file\r\n' ..
    '--c187dde3e9318fcc6509f45f76a89424--'
    local req = {
        read = function()
            return body
        end,
        headers = {
            ['content-type'] = 'multipart/form-data; boundary=c187dde3e9318fcc6509f45f76a89424',
        }
    }
    local payload, err, meta = utils.http_read_body(req)
    t.assert_equals(payload, 'Content file')
    t.assert_not(err)
    t.assert_equals(meta, {filename = 'sample.txt'})

    local body = '--c187dde3e9318fcc6509f45f76a89424\r\n'..
    '\r\n' ..
    '\r\n' ..
    'Content file\r\n' ..
    '--c187dde3e9318fcc6509f45f76a89424--'
    local req = {
        read = function()
            return body
        end,
        headers = {
            ['content-type'] = 'multipart/form-data; boundary=c187dde3e9318fcc6509f45f76a89424',
        }
    }
    local payload, err, meta = utils.http_read_body(req)
    t.assert_equals(payload, 'Content file')
    t.assert_not(err)
    t.assert_equals(meta, {})
end
