#!/usr/bin/env tarantool

local log = require('log')
local json = require('json')
local checks = require('checks')
local errors = require('errors')

local auth = require('cartridge.auth')
local vars = require('cartridge.vars').new('cartridge.graphql')
local types = require('cartridge.graphql.types')
local parse = require('cartridge.graphql.parse')
local schema = require('cartridge.graphql.schema')
local execute = require('cartridge.graphql.execute')
local funcall = require('cartridge.graphql.funcall')
local validate = require('cartridge.graphql.validate')


vars:new('graphql_schema_fields', {})
vars:new('graphql_schema', {})
vars:new('model', {})
vars:new('callbacks', {})
vars:new('mutations', {})

local e_graphql_internal = errors.new_class('Graphql internal error')
local e_graphql_parse = errors.new_class('Graphql parsing failed')
local e_graphql_validate = errors.new_class('Graphql validation failed')
local e_graphql_execute = errors.new_class('Graphql execution failed')

local function set_model(model_entrypoints)
    vars.model = model_entrypoints
end

local function get_fields()
    return vars.graphql_schema_fields
end

local function funcall_wrap(fun_name)
    return function(...)
        local res, err = funcall.call(fun_name, ...)

        if res == nil then
            error(err)
        end

        return res
    end
end

local function add_callback_prefix(prefix, doc)
    checks("string", "?string")

    local kind = types.object{
        name = 'Api'..prefix,
        fields = {},
        description = doc,
    }
    local obj = {
        kind = kind,
        arguments = {},
        resolve = function(self, args)
            return {}
        end,
        description = doc,
    }
    vars.callbacks[prefix] = obj
    return obj
end



local function add_mutation_prefix(prefix, doc)
    checks("string", "?string")

    local kind = types.object({
        name = 'MutationApi'..prefix,
        fields = {},
        description = doc,
    })
    local obj = {
        kind = kind,
        arguments = {},
        resolve = function(self, args)
            return {}
        end,
        description = doc,
    }
    vars.mutations[prefix] = obj
    return obj
end

local function add_callback(opts)
    checks({
        prefix = '?string',
        name = 'string',
        doc = '?string',
        args = '?table',
        kind = 'table',
        callback = 'string',
    })

    if opts.prefix then
        local obj = vars.callbacks[opts.prefix]
        if obj == nil then
            error('No such callback prefix ' .. opts.prefix)
        end

        local oldkind = obj.kind
        oldkind.fields[opts.name] = {
            kind = opts.kind,
            arguments = opts.args,
            resolve = funcall_wrap(opts.callback),
            description = opts.doc,
        }

        obj.kind = types.object{
            name = oldkind.name,
            fields = oldkind.fields,
            description = oldkind.description,
        }
    else
        vars.callbacks[opts.name] = {
            kind = opts.kind,
            arguments = opts.args,
            resolve = funcall_wrap(opts.callback),
            description = opts.doc,
        }
    end
end

local function add_mutation(opts)
    checks({
        prefix = '?string',
        name = 'string',
        doc = '?string',
        args = '?table',
        kind = 'table',
        callback = 'string',
    })

    if opts.prefix then
        local obj = vars.mutations[opts.prefix]
        if obj == nil then
            error('No such mutation prefix ' .. opts.prefix)
        end

        local oldkind = obj.kind
        oldkind.fields[opts.name] = {
            kind = opts.kind,
            arguments = opts.args,
            resolve = funcall_wrap(opts.callback),
            description = opts.doc
        }

        obj.kind = types.object{
            name = oldkind.name,
            fields = oldkind.fields,
            description = oldkind.description,
        }
    else
        vars.mutations[opts.name] = {
            kind = opts.kind,
            arguments = opts.args,
            resolve = funcall_wrap(opts.callback),
            description = opts.doc,
        }
    end
end

local function get_schema()
    local fields = table.copy(get_fields())

    for name, fun in pairs(vars.callbacks) do
        fields[name] = fun
    end

    for name, entry in pairs(vars.model) do
        local original_resolve = entry.resolve
        entry.resolve = function(...)
            if original_resolve then
                return original_resolve(...)
            end
            return true
        end
        fields[name] = entry
    end

    local mutations = {}
    for name, fun in pairs(vars.mutations) do
        mutations[name] = fun
    end

    local root = {query = types.object {name = 'Query', fields=fields}}

    if next(mutations) then
        root.mutation = types.object {name = 'Mutation', fields=mutations}
    end

    vars.graphql_schema = schema.create(root)
    return vars.graphql_schema
end

local function http_finalize(obj)
    checks('table')
    return auth.render_response({
        status = 200,
        headers = {['content-type'] = "application/json; charset=utf-8"},
        body = json.encode(obj),
    })
end

local function _execute_graphql(req)
    if not auth.authorize_request(req) then
        return http_finalize({
            errors = {{message = "Unauthorized"}},
        })
    end

    local body = req:read_cached()

    if body == nil or body == '' then
        return http_finalize({
            errors = {{message = "Expected a non-empty request body"}},
        })
    end

    local parsed = json.decode(body)
    if parsed == nil then
        return http_finalize({
            errors = {{message = "Body should be a valid JSON"}},
        })
    end

    if parsed.query == nil or type(parsed.query) ~= "string" then
        return http_finalize({
            errors = {{message = "Body should have 'query' field"}},
        })
    end


    if parsed.operationName ~= nil and type(parsed.operationName) ~= "string" then
        return http_finalize({
            errors = {{message = "'operationName' should be string"}},
        })
    end

    if parsed.variables ~= nil and type(parsed.variables) ~= "table" then
        return http_finalize({
            errors = {{message = "'variables' should be a dictionary"}},
        })
    end

    local operationName = nil

    if parsed.operationName ~= nil then
        operationName = parsed.operationName
    end

    local variables = nil
    if parsed.variables ~= nil then
        variables = parsed.variables
    end
    local query = parsed.query

    local ast, err = e_graphql_parse:pcall(parse.parse, query)

    if not ast then
        log.error('%s', err)
        return http_finalize({
            errors = {{message = err.err}},
        })
    end

    local schema_obj = get_schema()
    local _, err = e_graphql_validate:pcall(validate.validate, schema_obj, ast)

    if err then
        log.error('%s', err)
        return http_finalize({
            errors = {{message = err.err}},
        })
    end

    local rootValue = {}

    local data, err = e_graphql_execute:pcall(execute.execute,
        schema_obj, ast, rootValue, variables, operationName
    )

    if data == nil then
        -- TODO replace with errors.is_error_object as we upgrade errors
        if not (type(err) == 'table'
            and err.err ~= nil
            and err.str ~= nil
            and err.line ~= nil
            and err.file ~= nil
            and err.class_name ~= nil
        ) then
            err = e_graphql_execute:new(err or "Unknown error")
        end

        if type(err.err) ~= 'string' then
            err.err = json.encode(err.err)
        end

        log.error('%s', err)

        -- Specification: https://spec.graphql.org/June2018/#sec-Errors
        return http_finalize({
            errors = {{
                message = err.err,
                extensions = {
                    ['io.tarantool.errors.class_name']  = err.class_name,
                    ['io.tarantool.errors.stack'] = err.stack,
                }
            }}
        })
    end

    return http_finalize({
        data = data,
    })

end

local function execute_graphql(req)
    local resp, err = e_graphql_internal:pcall(_execute_graphql, req)
    if resp == nil then
        log.error('%s', err)
        return {
            status = 500,
            body = tostring(err),
        }
    end

    return resp
end

local function init(httpd)
    httpd:route(
        {
            method = 'POST',
            path = '/admin/api',
            public = true,
        },
        execute_graphql
    )
end

return {
    init = init,
    set_model = set_model,
    execute_graphql = execute_graphql,

    add_callback_prefix = add_callback_prefix,
    add_mutation_prefix = add_mutation_prefix,
    add_callback = add_callback,
    add_mutation = add_mutation,
}
