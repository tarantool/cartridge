local errors = require("errors")
local e_label_config = errors.new_class("Label configuration error")

local function validate_schema_labels(field, object)
    e_label_config:assert(
        type(object.labels) == "table" or object.labels == nil,
        "%s.labels must be a table or nil, got %s",
        field,
        type(object.labels)
    )

    if not object.labels then
        return true
    end

    for label_name, label_value in pairs(object.labels) do
        local label_name_field = ("%s.labels[%s] key"):format(field, label_name)

        e_label_config:assert(
            type(label_name) == "string",
            "%s must be string",
            label_name_field
        )

        e_label_config:assert(
            label_name:len() <= 63,
            "%s must not exceed 63 character",
            label_name_field
        )

        e_label_config:assert(
            label_name:match("^[%d%a_%-.]+$") ~= nil,
            [[%s must contain only alphanumerics [a-zA-Z], dots (.), underscores (_) or dashes (-)]],
            label_name_field
        )

        e_label_config:assert(
            label_name:sub(0, 1) ~= ".",
            "%s must not start with dot (.)",
            label_name_field
        )

        e_label_config:assert(
            label_name:sub(-1) ~= ".",
            "%s key must not end with dot (.)",
            label_name_field
        )

        e_label_config:assert(
            label_name:find('%.%.') == nil,
            "%s must not include 2 consequent dots (..)",
            label_name_field
        )

        local label_value_field = ("%s.labels[%s] value"):format(field, label_name)

        e_label_config:assert(
            type(label_value) == "string",
            "%s must be string",
            label_value_field
        )

        e_label_config:assert(
            label_value:len() <= 63,
            "%s must not exceed 63 character",
            label_value_field
        )

        e_label_config:assert(
            label_value:match("^[%d%a_%-.]+$") ~= nil,
            "%s must contain only alphanumerics [a-zA-Z], dots (.) and underscores (_)",
            label_value_field
        )

        e_label_config:assert(
            label_value:sub(0, 1) ~= ".",
            "%s must not start with dot (.)",
            label_value_field
        )

        e_label_config:assert(
            label_value:sub(-1) ~= ".",
            "%s must not end with dot (.)",
            label_value_field
        )
    end

    return true
end

return {
    validate_labels = function(...)
        return e_label_config:pcall(validate_schema_labels, ...)
    end
}
