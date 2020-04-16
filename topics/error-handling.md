# Error handling guidelines

Almost all errors in Cartridge follow `return nil, err` style, where
`err` is an error object produced by `errors`
[module](https://github.com/tarantool/errors). Cartridge doesn't raise
errors except for bugs and functions contracts mismatch. Developing new
roles should follow these guidelines as well.

## Error objects in Lua

Error classes help to locate the problem's source. For this purpose, an
error object contains it's class, stack traceback and a message.

```lua
local errors = require('errors')
local DangerousError = errors.new_class("DangerousError")

local function some_fancy_function()

    local something_bad_happens = true

    if something_bad_happens then
        return nil, DangerousError:new("Oh boy")
    end

    return "success" -- no
end

print(some_fancy_function())
```

```
nil	DangerousError: Oh boy
stack traceback:
	test.lua:9: in function 'some_fancy_function'
	test.lua:15: in main chunk
```

For uniform error handling `errors` provides `pcall` API:

```lua
local ret, err = DangerousError:pcall(
    some_fancy_function, 'what could possibly go wrong?'
)
print(ret, err)
```

```text
nil	DangerousError: Oh boy
stack traceback:
	test.lua:9: in function <test.lua:4>
	[C]: in function 'xpcall'
	.rocks/share/tarantool/errors.lua:139: in function 'pcall'
	test.lua:15: in main chunk

```

```lua
print(DangerousError:pcall(error, 'what could possibly go wrong?'))
```

```text
nil	DangerousError: what could possibly go wrong?
stack traceback:
	[C]: in function 'xpcall'
	.rocks/share/tarantool/errors.lua:139: in function 'pcall'
	test.lua:15: in main chunk
```

Remote `net.box` calls don't keep stack trace from the remote. In that
case `errors.netbox_eval` comes to the rescue. It will find stack trace
from local and remote hosts and restore metatables.

```
> conn = require('net.box').connect('localhost:3301')
> print( errors.netbox_eval(conn, 'return nil, DoSomethingError:new("oops")') )
nil     DoSomethingError: oops
stack traceback:
        eval:1: in main chunk
during net.box eval on localhost:3301
stack traceback:
        [string "return print( errors.netbox_eval("]:1: in main chunk
        [C]: in function 'pcall'
```

Data included in error object (class name, message, traceback)
may be easily converted to string using `tostring()` function.

## GraphQL

GraphQL implementation in cartridge wraps `errors` module so a typical
error responce looks as follows:

```json
{
    "errors":[{
        "message":"what could possibly go wrong?",
        "extensions":{
            "io.tarantool.errors.stack":"stack traceback: ...",
            "io.tarantool.errors.class_name":"DangerousError"
        }
    }]
}
```

Read more about errors in GraphQL specification
[here](http://spec.graphql.org/draft/#sec-Errors.Error-result-format).

If you're going to implement GraphQL handler, you can add your own
extension like this:

```lua
local err = DangerousError:new('I have extension')
err.graphql_extensions = {code = 403}
```

## HTTP

In a nutshell `errors` object is a table. This means that it can be
swiftly represented as a json. Such approach is used by Cartridge to
handle errors via http:

```
req.render_response({
    status = 500,
    headers = {
        ['content-type'] = "application/json; charset=utf-8"
    },
    body = json.encode(err),
})
```

