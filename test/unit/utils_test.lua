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

function g.test_is_email_valid()
    t.assert(utils.is_email_valid('simple@example.com'), 'correct email')
    t.assert(utils.is_email_valid('very.common@example.com'), 'correct email')
    t.assert(utils.is_email_valid('disposable.style.email.with+symbol@example.com'), 'correct email')
    t.assert(utils.is_email_valid('other.email-with-hyphen@example.com'), 'correct email')
    t.assert(utils.is_email_valid('fully-qualified-domain@example.com'), 'correct email')
    t.assert(utils.is_email_valid('x@example.com'), 'one-letter local-part')
    t.assert(utils.is_email_valid('example-indeed@strange-example.com'), 'correct email')
    t.assert(utils.is_email_valid('example@s.example'), 'correct email')
    t.assert(utils.is_email_valid('username@sub.example.org'), 'correct email')

    local function is_email_valid_xc(value)
        local _, err = utils.is_email_valid(value)
        if err ~= nil then
            error(err)
        end
    end

    t.assert_error_msg_contains('No TLD found in domain', is_email_valid_xc, 'aaaaa')
    t.assert_error_msg_contains('Email pattern test failed', is_email_valid_xc, 'aa.aa')
    t.assert_error_msg_contains('No TLD found in domain', is_email_valid_xc, 'aa@aa')
    t.assert_error_msg_contains('Email pattern test failed', is_email_valid_xc, '@a.a')
    t.assert_error_msg_contains('Invalid @ symbol usage in local part', is_email_valid_xc, 'a@@@a.a')
    t.assert_error_msg_contains('Email pattern test failed', is_email_valid_xc, 'some\xfe@mail.dmn')
    t.assert_error_msg_contains('Email pattern test failed', is_email_valid_xc, 'some@.dmn')
    t.assert_error_msg_contains('Email pattern test failed', is_email_valid_xc, 'some@`ls>/tmp/KITTY`.dmn')
    t.assert_error_msg_contains('Email pattern test failed', is_email_valid_xc, 'some@$HOME/.profile.dmn')
    t.assert_error_msg_contains('Email pattern test failed', is_email_valid_xc, 'some@%01%02%03%04%0a%0d%0aADSF.dmn')
    t.assert_error_msg_contains('Email pattern test failed', is_email_valid_xc, 'some@mail/./././././././.')
    t.assert_error_msg_contains('Symbol @ not found', is_email_valid_xc, '')
end
