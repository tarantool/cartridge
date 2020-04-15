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



## GraphQL 

If error occurs, GraphQL returns the result that contains `errors` entry. GraphQL implemented in Cartridge additionally introduces `stack` and `class_name` extensions that originate from `errors` class object. As a result, all information about error provided by `errors` module is embedded in GraphQL response.  The rest is up to programmer. They must ensure correct error handling using tools from `errors` module. 

## HTTP

