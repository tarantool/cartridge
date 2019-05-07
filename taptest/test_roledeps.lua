#!/usr/bin/env tarantool

local log = require('log')
local tap = require('tap')
local json = require('json')
local socket = require('socket')
local confapplier = require('cluster.confapplier')

local test = tap.test('cluster.register_role')

test:plan(16)

local function check_error(expected_error, fn, ...)
    local ok, err = fn(...)
    for _, l in pairs(string.split(tostring(err), '\n')) do
        test:diag('%s', l)
    end
    test:like(err.err, expected_error, expected_error)
end

local function register_roles(...)
    for _, role in ipairs({...}) do
        local ok, err = confapplier.register_role(role)
        if not ok then
            return nil, err
        end
    end

    return true
end

-------------------------------------------------------------------------------

check_error([[module 'unknown' not found]],
    register_roles, 'unknown'
)

-------------------------------------------------------------------------------

package.preload['my-mod'] = function()
    error('My role cant be loaded')
end
check_error([[My role cant be loaded]],
    register_roles, 'my-mod'
)
check_error([[loop or previous error loading module 'my%-mod']],
    register_roles, 'my-mod'
)

package.loaded['my-mod'] = nil
check_error([[My role cant be loaded]],
    register_roles, 'my-mod'
)

-------------------------------------------------------------------------------

package.loaded['mod-a1'] = nil
package.loaded['mod-a2'] = nil
package.preload['mod-a1'] = function() return {role_name = 'role-a'} end
package.preload['mod-a2'] = function() return {role_name = 'role-a'} end
check_error([[Role "role%-a" name clash]],
    register_roles, 'mod-a1', 'mod-a2'
)

-------------------------------------------------------------------------------

package.loaded['my-mod'] = nil
package.preload['my-mod'] = function() return true end
check_error([[Module "my%-mod" must return a table]],
    register_roles, 'my-mod'
)

-------------------------------------------------------------------------------

package.loaded['my-mod'] = nil
package.preload['my-mod'] = function() return {role_name = 1} end
check_error([[Module "my%-mod" role_name must be a string]],
    register_roles, 'my-mod'
)

-------------------------------------------------------------------------------

package.loaded['my-mod'] = nil
package.preload['my-mod'] = function() return {dependencies = 'no'} end
check_error([[Module "my%-mod" dependencies must be a table]],
    register_roles, 'my-mod'
)

-------------------------------------------------------------------------------

package.loaded['my-mod'] = nil
package.preload['my-mod'] = function() return { dependencies = {'unknown'} } end
check_error([[module 'unknown' not found]],
    register_roles, 'my-mod'
)

-------------------------------------------------------------------------------

package.loaded['my-mod'] = nil
package.preload['my-mod'] = function() return { dependencies = {'my-mod'} } end
check_error([[Module "my%-mod" circular dependency not allowed]],
    register_roles, 'my-mod'
)

-------------------------------------------------------------------------------

package.loaded['mod-a'] = nil
package.loaded['mod-b'] = nil
package.loaded['mod-c'] = nil
package.preload['mod-a'] = function()
    return { role_name = 'role-a', dependencies = {'mod-b'} }
end
package.preload['mod-b'] = function()
    return { role_name = 'role-b', dependencies = {'mod-c'} }
end
package.preload['mod-c'] = function()
    return { role_name = 'role-c', dependencies = {'mod-a'} }
end
check_error([[Module "mod%-a" circular dependency not allowed]],
    register_roles, 'mod-a'
)

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

package.loaded['mod-a'] = nil
package.loaded['mod-b'] = nil
package.loaded['mod-c'] = nil
package.loaded['mod-d'] = nil
package.loaded['storage'] = nil
package.preload['mod-a'] = function()
    return { role_name = 'role-a', dependencies = {'mod-b', 'mod-d'} }
end
package.preload['mod-b'] = function()
    return { role_name = 'role-b', dependencies = {'mod-c', 'mod-d'} }
end
package.preload['mod-c'] = function()
    return { role_name = 'role-c' }
end
package.preload['mod-d'] = function()
    return { role_name = 'role-d' }
end
package.preload['storage'] = function()
    return { dependencies = {'cluster.roles.vshard-storage'} }
end
local ok, err = register_roles(
    'cluster.roles.vshard-storage',
    'cluster.roles.vshard-router',
    'storage',
    'mod-a'
)
if not ok then
    log.error('%s', err)
end
test:is(ok, true, 'register_roles')

local vars = require('cluster.vars').new('cluster.confapplier')
local roles_order = {}
for i, mod in ipairs(vars.known_roles) do
    roles_order[i] = mod.role_name
    test:diag('%d) %s -> %s',
        i, mod.role_name,
        json.encode(vars.roles_dependencies[mod.role_name])
    )
end
test:is_deeply(roles_order, {
    'vshard-storage', 'vshard-router', 'storage', 'role-c', 'role-d', 'role-b', 'role-a',
}, 'roles_order')
test:is_deeply(vars.roles_dependencies, {
    ['vshard-storage'] = {},
    ['vshard-router'] = {},
    ['storage'] = {'vshard-storage'},
    ['role-a'] = {'role-b', 'role-c', 'role-d'},
    ['role-b'] = {'role-c', 'role-d'},
    ['role-c'] = {},
    ['role-d'] = {},
}, 'roles_dependencies')

for i, mod in ipairs(vars.known_roles) do
    test:diag('%d) %s <- %s',
        i, mod.role_name,
        json.encode(vars.roles_dependants[mod.role_name])
    )
end
test:is_deeply(vars.roles_dependants, {
    ['vshard-storage'] = {'storage'},
    ['vshard-router'] = {},
    ['storage'] = {},
    ['role-a'] = {},
    ['role-b'] = {'role-a'},
    ['role-c'] = {'role-b'},
    ['role-d'] = {'role-b', 'role-a'},
}, 'roles_dependants')

local known_roles = confapplier.get_known_roles()
test:diag('known_roles: %s', json.encode(known_roles))
test:is_deeply(known_roles, {
    'vshard-storage', 'vshard-router', 'storage', 'role-c', 'role-d', 'role-b', 'role-a',
}, 'known_roles')

os.exit(test:check() and 0 or 1)
