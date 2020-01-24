local fio = require('fio')
local yaml = require('yaml')
local t = require('luatest')
local g = t.group()

local test_helper = require('test.helper')
local helpers = require('cartridge.test-helpers')

g.before_all = function()
    g.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        use_vshard = false,
        server_command = test_helper.server_command,
        replicasets = {{
            alias = 'loner',
            uuid = helpers.uuid('a'),
            roles = {'extensions'},
            servers = {{
                instance_uuid = helpers.uuid('a', 'a', 1)
            }},
        }},
    })

    g.cluster:start()
end

g.after_all = function()
    g.cluster:stop()
    fio.rmtree(g.cluster.datadir)
end

local function get_state()
    return g.cluster.main_server.net_box:eval([[
        return require('cartridge.confapplier').get_state()
    ]])
end

local error_prefix = "Invalid extensions config: "
local function set_sections(sections)
    return g.cluster.main_server:graphql({
        query = [[
            mutation($sections: [ConfigSectionInput!]) {
                cluster {
                    config(sections: $sections) {}
                }
            }
        ]],
        variables = {sections = sections},
    })
end

function g.test_require_errors()
    t.assert_error_msg_equals(
        "extensions/main.lua:1: bad argument #1 to 'require'" ..
        " (string expected, got cdata)",
        set_sections, {{
            filename = 'extensions/main.lua',
            content = 'require(box.NULL)',
        }}
    )

    t.assert_error_msg_equals(
        "extensions/main.lua:1: loop or previous error loading" ..
        " module 'extensions.main'",
        set_sections, {{
            filename = 'extensions/main.lua',
            content = 'require("extensions.main")',
        }}
    )

    t.assert_error_msg_equals(
        "extensions/main.lua:1: unexpected symbol near '!'",
        set_sections, {{
            filename = 'extensions/main.lua',
            content = '! Syntax error',
        }}
    )

    t.assert_error_msg_equals(
        "extensions/main.lua:1: ###",
        set_sections, {{
            filename = 'extensions/main.lua',
            content = 'error("###")',
        }}
    )

    t.assert_error_msg_equals(
        "module 'extensions.main' not found:\n" ..
        "\tno section 'extensions/main.lua' in config",
        set_sections, {{
            filename = 'extensions/main.lua.yml',
            content = '{"This is not a script"}',
        }}
    )

    t.assert_error_msg_equals(
        "extensions/pupa.lua:1: module 'extensions.lupa' not found:\n" ..
        "\tno section 'extensions/lupa.lua' in config",
        set_sections, {{
            filename = 'extensions/pupa.lua',
            content = 'require("extensions.lupa")',
        }}
    )

    t.assert_error_msg_matches(
        "extensions/pupa%.lua:1: module 'lupa' not found:\n" ..
        "\tno field package.preload%['lupa'%].+",
        set_sections, {{
            filename = 'extensions/pupa.lua',
            content = 'require("lupa")',
        }, {
            filename = 'lupa.lua',
            content = 'return {}',
        }}
    )

    t.assert_equals(get_state(), 'RolesConfigured')
end

function g.test_functions_errors()
    t.assert_error_msg_equals(
        error_prefix .. 'bad field functions (table expected, got cdata)',
        set_sections, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = box.NULL,
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. 'bad field functions (table keys must be strings, got number)',
        set_sections, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {1},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. 'bad field functions["x"] (table expected, got cdata)',
        set_sections, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {x = box.NULL},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. 'bad field functions["x"].module (string expected, got cdata)',
        set_sections, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {x = {
                    module = box.NULL,
                }},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. 'bad field functions["x"].handler (string expected, got number)',
        set_sections, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {x = {
                    module = '',
                    handler = 0,
                }},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. 'bad field functions["x"].events (table expected, got boolean)',
        set_sections, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {x = {
                    module = 'math',
                    handler = 'atan2',
                    events = false,
                }},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. "no module 'unknown' to handle function 'x'",
        set_sections, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {x = {
                    module = 'unknown',
                    handler = 'f',
                    events = {},
                }},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. "no function 'cat' in module 'box' to handle 'x'",
        set_sections, {{
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {x = {
                    module = 'box',
                    handler = 'cat',
                    events = {},
                }},
            }),
        }}
    )
end

function g.test_export_errors()
    local extensions_cfg = yaml.encode({
        functions = {F = {
            module = 'extensions.main',
            handler = 'operate',
            events = {{
                binary = {path = 'operate'}
            }}
        }}
    })

    t.assert_error_msg_equals(
        error_prefix .. "no module 'extensions.main'" ..
        " to handle function 'F'",
        set_sections, {{
            filename = 'extensions/config.yml',
            content = extensions_cfg,
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. "no function 'operate' in module 'extensions.main'" ..
        " to handle 'F'",
        set_sections, {{
            filename = 'extensions/config.yml',
            content = extensions_cfg,
        }, {
            filename = 'extensions/main.lua',
            content = 'return false',
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. "no function 'operate' in module 'extensions.main'" ..
        " to handle 'F'",
        set_sections, {{
            filename = 'extensions/config.yml',
            content = extensions_cfg,
        }, {
            filename = 'extensions/main.lua',
            content = 'return {operate = false}',
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. "collision of binary event 'operate'" ..
        " to handle function 'F'",
        set_sections, {{
            filename = 'extensions/main.lua',
            content = 'return {operate = function() end}',
        }, {
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {F = {
                    module = 'extensions.main',
                    handler = 'operate',
                    events = {
                        {binary = {path = 'operate'}},
                        {binary = {path = 'operate'}},
                    },
                }},
            }),
        }}
    )

    t.assert_error_msg_equals(
        error_prefix .. "can't override global 'box'" ..
        " to handle function 'F'",
        set_sections, {{
            filename = 'extensions/main.lua',
            content = 'return {operate = function() end}',
        }, {
            filename = 'extensions/config.yml',
            content = yaml.encode({
                functions = {F = {
                    module = 'extensions.main',
                    handler = 'operate',
                    events = {
                        {binary = {path = 'box'}},
                    },
                }},
            }),
        }}
    )

    t.assert_equals(get_state(), 'RolesConfigured')
end

function g.test_runtime()
    local extensions_cfg = yaml.encode({
        functions = {
            operate = {
                module = 'extensions.main',
                handler = 'operate',
                events = {{
                    binary = {path = 'operate'}
                }}
            },
            math_abs = {
                module = 'math',
                handler = 'abs',
                events = {{
                    binary = {path = 'math_abs'}
                }}
            }
        }
    })

    set_sections({{
        filename = 'extensions/config.yml',
        content = extensions_cfg,
    }, {
        filename = 'extensions/main.lua',
        content = [[
            local function M()
                return require('extensions.main')
            end

            local function operate()
                return 1
            end

            return {
                M = M,
                require = require,
                operate = operate,
            }
        ]],
    }})

    t.assert_equals(g.cluster.main_server.net_box:call('math_abs', {-3}), 3)
    t.assert_equals(g.cluster.main_server.net_box:call('operate'), 1)
    g.cluster.main_server.net_box:eval([[
        assert(package.loaded['extensions.main'], 'Extension not loaded')
        local M = require('extensions.main')
        assert(M == M.M(), 'Extension was reloaded twice')
        assert(require ~= M.require, 'Upvalue "require" is broken')
    ]])

    t.assert_error_msg_equals(
        error_prefix .. "no function 'operate'" ..
        " in module 'extensions.main' to handle 'operate'",
        set_sections, {{
            filename = 'extensions/main.lua',
            content = 'return {}',
        }, {
            filename = 'extensions/config.yml',
            content = extensions_cfg,
        }}
    )
    t.assert_error_msg_equals(
        error_prefix .. "no module 'extensions.main'" ..
        " to handle function 'operate'",
        set_sections, {{
            filename = 'extensions/main.lua',
            content = box.NULL,
        }, {
            filename = 'extensions/config.yml',
            content = extensions_cfg,
        }}
    )

    set_sections({{
        filename = 'extensions/config.yml',
        content = extensions_cfg,
    }, {
        filename = 'extensions/main.lua',
        content = [[
            local function operate()
                return 2
            end

            return {
                operate = operate,
            }
        ]],
    }})

    t.assert_equals(g.cluster.main_server.net_box:call('operate'), 2)

    t.assert_equals(get_state(), 'RolesConfigured')
end
