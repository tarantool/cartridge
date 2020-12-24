local log = require('log')
local ddl = require('ddl')
local yaml = require('yaml')
local checks = require('checks')
local errors = require('errors')

local failover = require('cartridge.failover')

local SetSchemaError = errors.new_class('SetSchemaError')
local CheckSchemaError = errors.new_class('CheckSchemaError')
local DecodeYamlError = errors.new_class('DecodeYamlError')

local _section_name = 'schema.yml'
local _example_schema = [[## Example:
#
# spaces:
#   customer:
#     engine: memtx
#     is_local: false
#     temporary: false
#     sharding_key: [customer_id]
#     format:
#       - {name: customer_id, type: unsigned, is_nullable: false}
#       - {name: bucket_id, type: unsigned, is_nullable: false}
#       - {name: fullname, type: string, is_nullable: false}
#     indexes:
#     - name: customer_id
#       unique: true
#       type: TREE
#       parts:
#         - {path: customer_id, type: unsigned, is_nullable: false}
#
#     - name: bucket_id
#       unique: false
#       type: TREE
#       parts:
#         - {path: bucket_id, type: unsigned, is_nullable: false}
#
#     - name: fullname
#       unique: true
#       type: TREE
#       parts:
#         - {path: fullname, type: string, is_nullable: false}
]]

local function _from_yaml(schema_yml)
    if type(schema_yml) ~= 'string' then
        return nil, CheckSchemaError:new(
            'Section %q must be a string, got %s',
            _section_name, type(schema_yml)
        )
    end

    return DecodeYamlError:pcall(yaml.decode, schema_yml)
end

local function apply_config(conf, opts)
    checks('table', {is_master = 'boolean'})

    if not opts.is_master then
        return true
    end

    if conf[_section_name] == nil then
        return true
    end

    local schema, err = _from_yaml(conf[_section_name])
    if schema == nil then
        if err then
            return nil, err
        else
            return true
        end
    end

    local ok, err = ddl.set_schema(schema)
    if not ok then
        return nil, SetSchemaError:new(err)
    end

    return true
end

local function validate_config(conf_new, _)
    checks('table', 'table')

    if conf_new[_section_name] == nil then
        return true
    end

    local schema, err = _from_yaml(conf_new[_section_name])
    if schema == nil then
        if err then
            return nil, err
        else
            return true
        end
    end

    if type(box.cfg) == 'function' then
        log.info(
            "Schema validation skipped because" ..
            " the instance isn't bootstrapped yet"
        )
        return true
    elseif not failover.is_leader() then
        log.info(
            "Schema validation skipped because" ..
            " the instance isn't a leader"
        )
        return true
    end

    local ok, err = ddl.check_schema(schema)
    if not ok then
        return nil, CheckSchemaError:new(err)
    end

    return true
end

return {
    _section_name = _section_name,
    _example_schema = _example_schema,
    validate_config = validate_config,
    apply_config = apply_config,
}
