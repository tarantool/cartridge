.. _cartridge-error-handling:

-------------------------------------------------------------------------------
Error handling guidelines
-------------------------------------------------------------------------------

Almost all errors in Cartridge follow the ``return nil, err`` style, where
``err`` is an error object produced by Tarantool's
`errors <https://github.com/tarantool/errors>`_ module. Cartridge
doesn't raise errors except for bugs and functions contracts mismatch.
Developing new roles should follow these guidelines as well.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Error objects in Lua
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Error classes help to locate the problem's source. For this purpose, an
error object contains its class, stack traceback, and a message.

.. code-block:: lua

    local errors = require('errors')
    local DangerousError = errors.new_class("DangerousError")

    local function some_fancy_function()

        local something_bad_happens = true

        if something_bad_happens then
            return nil, DangerousError:new("Oh boy")
        end

        return "success" -- not reachable due to the error
    end

    print(some_fancy_function())

.. code-block:: text

    nil	DangerousError: Oh boy
    stack traceback:
    	test.lua:9: in function 'some_fancy_function'
    	test.lua:15: in main chunk

For uniform error handling, ``errors`` provides the ``:pcall`` API:

.. code-block:: lua

    local ret, err = DangerousError:pcall(some_fancy_function)
    print(ret, err)

.. code-block:: text

    nil	DangerousError: Oh boy
    stack traceback:
    	test.lua:9: in function <test.lua:4>
    	[C]: in function 'xpcall'
    	.rocks/share/tarantool/errors.lua:139: in function 'pcall'
    	test.lua:15: in main chunk

.. code-block:: lua

   print(DangerousError:pcall(error, 'what could possibly go wrong?'))

.. code-block:: text

    nil	DangerousError: what could possibly go wrong?
    stack traceback:
    	[C]: in function 'xpcall'
    	.rocks/share/tarantool/errors.lua:139: in function 'pcall'
    	test.lua:15: in main chunk

For ``errors.pcall`` there is no difference between the ``return nil, err`` and
``error()`` approaches.

Note that ``errors.pcall`` API differs from the vanilla Lua
`pcall <https://www.lua.org/pil/8.4.html>`_. Instead of ``true`` the former
returns values returned from the call. If there is an error, it returns
``nil`` instead of ``false``, plus an error message.

Remote ``net.box`` calls keep no stack trace from the remote. In that
case, ``errors.netbox_eval`` comes to the rescue. It will find a stack trace
from local and remote hosts and restore metatables.

.. code-block:: text

    > conn = require('net.box').connect('localhost:3301')
    > print( errors.netbox_eval(conn, 'return nil, DoSomethingError:new("oops")') )
    nil     DoSomethingError: oops
    stack traceback:
            eval:1: in main chunk
    during net.box eval on localhost:3301
    stack traceback:
            [string "return print( errors.netbox_eval("]:1: in main chunk
            [C]: in function 'pcall'

However, ``vshard`` implemented in Tarantool doesn't utilize the ``errors``
module. Instead it uses
`its own errors <https://github.com/tarantool/vshard/blob/master/vshard/error.lua>`_.
Keep this in mind when working with ``vshard`` functions.

Data included in an error object (class name, message, traceback) may be
easily converted to string using the ``tostring()`` function.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
GraphQL
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

GraphQL implementation in Cartridge wraps the ``errors`` module, so a typical
error response looks as follows:

.. code-block:: json

    {
        "errors":[{
            "message":"what could possibly go wrong?",
            "extensions":{
                "io.tarantool.errors.stack":"stack traceback: ...",
                "io.tarantool.errors.class_name":"DangerousError"
            }
        }]
    }

Read more about errors in the
`GraphQL specification <http://spec.graphql.org/draft/#sec-Errors.Error-result-format>`_.

If you're going to implement a GraphQL handler, you can add your own
extension like this:

.. code-block:: lua

    local err = DangerousError:new('I have extension')
    err.graphql_extensions = {code = 403}

It will lead to the following response:

.. code-block:: json

    {
        "errors":[{
            "message":"I have extension",
            "extensions":{
                "io.tarantool.errors.stack":"stack traceback: ...",
                "io.tarantool.errors.class_name":"DangerousError",
                "code":403
            }
        }]
    }

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
HTTP
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In a nutshell, an ``errors`` object is a table. This means that it can be
swiftly represented in JSON. This approach is used by Cartridge to
handle errors via http:

.. code-block:: lua

    local err = DangerousError:new('Who would have thought?')

    local resp = req:render({
        status = 500,
        headers = {
            ['content-type'] = "application/json; charset=utf-8"
        },
        json = json.encode(err),
    })

.. code-block:: json

    {
        "line":27,
        "class_name":"DangerousError",
        "err":"Who would have thought?",
        "file":".../app/roles/api.lua",
        "stack":"stack traceback:..."
    }
