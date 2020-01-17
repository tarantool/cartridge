#!/usr/bin/env tarantool

require('strict').on()

local remote_control = require('cartridge.remote-control')
local ok, err = remote_control.bind(
    '0.0.0.0',
    os.getenv('TARANTOOL_LISTEN') or '13301'
)
assert(ok, err)

remote_control.accept({
    username = 'admin',
    password = '',
})
