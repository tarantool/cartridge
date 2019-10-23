#!/usr/bin/env tarantool

local log = require('log')
local ddl = require('ddl')
local yaml = require('yaml')
local checks = require('checks')
local errors = require('errors')

local topology = require('cartridge.topology')

local CheckSchemaError = errors.new_class('CheckSchemaError')

local _section_name = 'schema.yml'

local function _from_yaml(schema_yml)
    if schema_yml == nil then
        return {}
    elseif type(schema_yml) ~= 'string' then
        local err = CheckSchemaError:new(
            'Section %q must be a string, got %s',
            _section_name, type(schema_yml)
        )
        return nil, err
    end

    local ok, schema_tbl = pcall(yaml.decode, schema_yml)
    if not ok then
        local err = CheckSchemaError:new(
            'Invalid YAML: %s',
            schema_tbl
        )
        return nil, err
    end

    if type(schema_tbl) ~= 'table' then
        local err = CheckSchemaError:new(
            'Schema must be a table, got %s',
            type(schema_tbl)
        )
        return nil, err
    end
    return schema_tbl
end

local function apply_config(conf, opts)
    checks('table', {is_master = 'boolean'})

    if not opts.is_master then
        return
    end

    if conf[_section_name] == nil then
        return
    end

    local schema, err = _from_yaml(conf[_section_name])
    if schema == nil then
        return nil, err
    end

    local ok, err = ddl.set_schema(schema)
    if not ok then
        return nil, err
    end

    return true
end

local function validate_config(conf_new, conf_old)
    checks('table', 'table')

    local schema_new, err = _from_yaml(conf_new[_section_name])
    if schema_new == nil then
        return nil, err
    end
    local schema_old, err = _from_yaml(conf_old[_section_name])
    if schema_old == nil then
        return nil, CheckSchemaError:new(
            'Error parsing old schema: %s',
            err.err
        )
    end

    if next(schema_new) ~= nil then
        if type(box.cfg) == 'function' then
            -- This case is almost impossible today
            -- because we don't have public API that
            -- can inject schema into bootstrap_from_scratch
            log.warn(
                "Schema validation is impossible because" ..
                " instance isn't bootstrapped yet." ..
                " Set it at your own risk"
            )
            goto skip
        end

        local active_masters = topology.get_active_masters()
        if active_masters[box.info.cluster.uuid] ~= box.info.uuid then
            log.info(
                "Schema validation skipped because" ..
                " instance isn't a leader"
            )
            goto skip
        end

        local ok, err = ddl.check_schema(schema_new)
        if not ok then
            return nil, CheckSchemaError:new(err)
        end

        ::skip::
    end

    for space_name, _ in pairs(schema_old.spaces or {}) do
        if schema_new.spaces == nil
        or schema_new.spaces[space_name] == nil
        then
            return nil, CheckSchemaError:new(
                "Missing space %q in schema," ..
                " removing spaces is forbidden",
                space_name
            )
        end
    end

    return true
end

return {
    _section_name = _section_name,
    validate_config = validate_config,
    apply_config = apply_config,
}
