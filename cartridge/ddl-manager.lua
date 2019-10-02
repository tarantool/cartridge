#!/usr/bin/env tarantool

local log = require('log')
local ddl = require('ddl')
local checks = require('checks')
local errors = require('errors')

local failover = require('cartridge.failover')

local CheckSchemaError = errors.new_class('CheckSchemaError')

local _section_name = 'schema.yml'

local function apply_config(conf, opts)
    checks('table', {is_master = 'boolean'})

    if not opts.is_master then
        return true
    end

    local schema = conf[_section_name]
    if schema == nil then
        return true
    end

    local ok, err = ddl.set_schema(schema)
    if not ok then
        return nil, err
    end

    return true
end

local function validate_config(conf_new, conf_old)
    checks('table', 'table')

    local schema_new = conf_new[_section_name] or {}
    local schema_old = conf_old[_section_name] or {}

    if type(schema_new) ~= 'table' then
        local err = CheckSchemaError:new(
            'Schema must be a table, got %s',
            type(schema_new)
        )
        return nil, err
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
            return true
        end

        local active_masters = failover.get_active_leaders()
        if active_masters[box.info.cluster.uuid] ~= box.info.uuid then
            log.info(
                "Schema validation skipped because" ..
                " instance isn't a leader"
            )
            return true
        end

        local ok, err = ddl.check_schema(schema_new)
        if not ok then
            return nil, CheckSchemaError:new(err)
        end
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
