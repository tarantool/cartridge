#!/usr/bin/env tarantool

local log = require('log')
local json = require('json')
local roles = require('cartridge.roles')

local t = require('luatest')
local g = t.group()

local function check_error(expected_error, fn, ...)
    local _, err = fn(...)
    for _, l in pairs(string.split(tostring(err), '\n')) do
        log.info('%s', l)
    end
    return t.assert_str_matches(err.err, expected_error)
end

local function register_roles(...)
    return roles.cfg({...})
end

function g.test_error()
-------------------------------------------------------------------------------

check_error([[module 'unknown' not found:.+]],
    register_roles, 'unknown'
)

-------------------------------------------------------------------------------

package.preload['my-mod'] = function()
    error('My role cant be loaded', 0)
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
check_error([[Role "role%-a" name clash between mod%-a2 and mod%-a1]],
    register_roles, 'mod-a1', 'mod-a2'
)

-------------------------------------------------------------------------------

package.loaded['my-mod'] = nil
package.preload['my-mod'] = function() return true end
check_error([[Module "my%-mod" must return a table, got boolean]],
    register_roles, 'my-mod'
)

-------------------------------------------------------------------------------

package.loaded['my-mod'] = nil
package.preload['my-mod'] = function() return {role_name = 1} end
check_error([[Module "my%-mod" role_name must be a string, got number]],
    register_roles, 'my-mod'
)

-------------------------------------------------------------------------------

package.loaded['my-mod'] = nil
package.preload['my-mod'] = function() return {dependencies = 'no'} end
check_error([[Module "my%-mod" dependencies must be a table, got string]],
    register_roles, 'my-mod'
)

-------------------------------------------------------------------------------

package.loaded['my-mod'] = nil
package.preload['my-mod'] = function() return { dependencies = {'unknown'} } end
check_error([[module 'unknown' not found:.+]],
    register_roles, 'my-mod'
)

-------------------------------------------------------------------------------

package.loaded['my-mod'] = nil
package.preload['my-mod'] = function() return { dependencies = {'my-mod'} } end
check_error([[Module "my%-mod" circular dependency prohibited]],
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
check_error([[Module "mod%-a" circular dependency prohibited]],
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
    return { dependencies = {'cartridge.roles.vshard-storage'} }
end
local ok, err = register_roles(
    'cartridge.roles.vshard-storage',
    'cartridge.roles.vshard-router',
    'storage',
    'mod-a'
)
if not ok then
    log.error('%s', err)
end
t.assert_equals(ok, true, err)

local vars = require('cartridge.vars').new('cartridge.roles')
local roles_order = {}
for i, role in ipairs(vars.roles_by_number) do
    roles_order[i] = role.role_name
    log.info('%d) %s -> %s',
        i, role.role_name,
        json.encode(role.dependencies)
    )
end
t.assert_equals(roles_order, {
    'ddl-manager',
    'failover-coordinator',
    'vshard-storage',
    'vshard-router',
    'storage', 'role-c', 'role-d', 'role-b', 'role-a',
})
t.assert_equals(roles.get_role_dependencies('vshard-storage'), {})
t.assert_equals(roles.get_role_dependencies('vshard-router'), {})
t.assert_equals(roles.get_role_dependencies('storage'), {'vshard-storage'})
t.assert_equals(roles.get_role_dependencies('role-a'), {'role-b', 'role-c', 'role-d'})
t.assert_equals(roles.get_role_dependencies('role-b'), {'role-c', 'role-d'})
t.assert_equals(roles.get_role_dependencies('role-c'), {})
t.assert_equals(roles.get_role_dependencies('role-d'), {})

local known_roles = roles.get_known_roles()
t.assert_equals(known_roles, {
    'failover-coordinator', 'vshard-storage', 'vshard-router',
    'storage', 'role-c', 'role-d', 'role-b', 'role-a',
})

local enabled_roles = roles.get_enabled_roles({
    ['vshard-storage'] = false,
    ['storage'] = true,
    ['role-a'] = false,
})
t.assert_equals(enabled_roles, {
    ['ddl-manager'] = true,
    ['vshard-storage'] = true,
    ['storage'] = true,
})

end
