#!/usr/bin/env tarantool

local log = require('log')
local json = require('json')
local checks = require('checks')
local errors = require('errors')

local vars = require('cluster.vars').new('cluster.graphql')
local types = require('cluster.graphql.types')
local parse = require('cluster.graphql.parse')
local schema = require('cluster.graphql.schema')
local execute = require('cluster.graphql.execute')
local funcall = require('cluster.graphql.funcall')
local validate = require('cluster.graphql.validate')


vars:new('graphql_schema_fields', {})
vars:new('graphql_schema', {})
vars:new('model', {})
vars:new('callbacks', {})
vars:new('mutations', {})
vars:new('endpoint_middleware', nil)

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
        if vars.endpoint_middleware ~= nil then
            vars.endpoint_middleware(fun_name, ...)
        end


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
            if vars.endpoint_middleware ~= nil then
                vars.endpoint_middleware('model', ...)
            end
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

local function _execute_graphql(req)
    local body = req:read()

    if body == nil or body == '' then
        return {
            status = 200,
            body = json.encode({errors={{message="Expected a non-empty request body"}}})
        }
    end

    local parsed = json.decode(body)
    if parsed == nil then
        return {
            status = 200,
            body = json.encode({errors={{message="Body should be a valid JSON"}}})
        }
    end

    if parsed.query == nil or type(parsed.query) ~= "string" then
        return {
            status = 200,
            body = json.encode({errors={{message="Body should have 'query' field"}}})
        }
    end


    if parsed.operationName ~= nil and type(parsed.operationName) ~= "string" then
        return {
            status = 200,
            body = json.encode({errors={{message="'operationName' should be string"}}})
        }
    end

    if parsed.variables ~= nil and type(parsed.variables) ~= "table" then
        return {
            status = 200,
            body = json.encode({errors={{message="'variables' should be a dictionary"}}})
        }
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
        return {
            status = 200,
            body = json.encode({errors={{message=err.err}}})
        }
    end

    local schema_obj = get_schema()
    local _, err = e_graphql_validate:pcall(validate.validate, schema_obj, ast)

    if err then
        log.error('%s', err)
        return {
            status = 200,
            body = json.encode({errors={{message=err.err}}})
        }
    end

    local rootValue = {}

    local res, err = e_graphql_execute:pcall(execute.execute, schema_obj, ast, rootValue, variables, operationName)

    if res == nil then
        log.error('%s', err or "Unknown error")
        return {
            status = 200,
            body = json.encode({
                errors = {{
                    message = err and err.err or "Unknown error",
                }}
            })
        }
    end

    local result = {data = res}

    return {
        status = 200,
        headers = {
            ['content-type'] = "application/json; charset=utf-8"
        },
        body = json.encode(result)
    }

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

local function set_middleware(callback)
    vars.middleware = callback
end

local function set_endpoint_middleware(callback)
    vars.endpoint_middleware = callback
end

local function init(httpd)
    httpd:route(
        {
            method = 'POST',
            path = '/graphql',
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

    set_endpoint_middleware = set_endpoint_middleware,
}
