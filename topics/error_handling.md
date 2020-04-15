# Error handling guidelines

## `errors`

The main tool of handling errors and exceptions in Tarantool is `errors` [module](https://github.com/tarantool/errors).   It allows you to create a specific error class which helps to locate the problem's source. For this purpose, exception object contains an exception type, stack traceback and a message.

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
print(DangerousError:pcall(some_fancy_function, 'what could possibly go wrong?'))
```

```
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

```
nil	DangerousError: what could possibly go wrong?
stack traceback:
	[C]: in function 'xpcall'
	.rocks/share/tarantool/errors.lua:139: in function 'pcall'
	test.lua:15: in main chunk
```

However, `net.box` doesn't keep stack trace from the remote. In that case `errors.netbox_eval` comes to the rescue. It will find stack trace from local and remote hosts and restore metatables.

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

Data included in exception object (exception type, message, traceback) may be easily converted to string using `tostring()` function.

## GraphQL 

If error occurs, GraphQL returns the result that contains `errors` entry. GraphQL implemented in Cartridge additionally introduces `stack` and `class_name` extensions that originate from `errors` class object. As a result, all information about error provided by `errors` module is embedded in GraphQL response.  The rest is up to programmer. They must ensure correct error handling using tools from `errors` module. 

If necessary, it is possible to provide additional error information with a help of `graphql_extensions`. 

```lua
local err = errors.new('SpecialError', 'I have some extra info in graphql_extensions!')
err.graphql_extensions = {code = 403}
```

In such way code of this `SpecialError` will be placed in the `errors` entry of GraphQL response alongside with `stack` trace and `class_name`. 

So, `graphql_extensions` is table that helps to specify error. Be sure not to use `io.tarantool.errors.stack` and `io.tarantool.errors.class_name` as key because values associated with them will be overwritten with `errors` object's `stack` and `class_name`. 

## HTTP

In a nutshell `errors` object is a table. This means that it can be swiftly represented as a json. Such approach is used for handling errors via http

```
req.render_response({
        status = http_code,
        headers = {
            ['content-type'] = "application/json; charset=utf-8"
        },
        body = json.encode(err),
    })
```

