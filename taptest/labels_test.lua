local tap = require("tap")
local test = tap.test("topology.config")
local label_utils = require("cluster.label-utils")
local errors = require("errors")
local e_label_config = errors.new_class("Label configuration error")

test:plan(16)

test.throws = function(self, expected_err, f, ...)
    local ok, err = f(...)
    self:is(err.class_name, expected_err.name)
end

--[[
  Instance labels assertions
  Instance labels keys and values must complain with DNS Labels RFC
  https://www.ietf.org/rfc/rfc1035.txt
]]
test:ok(label_utils.validate_labels("field", {}), "object without labels valid")
test:ok(label_utils.validate_labels("field", {labels = nil}), "labels of type nil valid")
test:ok(label_utils.validate_labels("field", {labels = {}}), "labels of type table valid")
test:ok(label_utils.validate_labels("field", {labels = {["key"] = "value"}}), "label key not exceeding 63 chars valid")
test:ok(
    label_utils.validate_labels("field", {labels = {["A-z_aZ.19"] = "val"}}),
    "label key may contain [a-zA-Z], [0-9], _, -, ."
)

test:throws(e_label_config, label_utils.validate_labels, "testing", {labels = 1})
test:throws(e_label_config, label_utils.validate_labels, "testing", {labels = true})
test:throws(
    e_label_config,
    label_utils.validate_labels,
    "testing",
    {
        labels = function()
        end
    }
)
test:throws(e_label_config, label_utils.validate_labels, "testing", {labels = "asdfsd"})

test:throws(e_label_config, label_utils.validate_labels, "testing", {labels = {[""] = ""}})
test:throws(e_label_config, label_utils.validate_labels, "testing", {labels = {[""] = "1234"}})

test:throws(e_label_config, label_utils.validate_labels, "testing", {labels = {[".label"] = "1234"}})
test:throws(e_label_config, label_utils.validate_labels, "testing", {labels = {["label."] = "1234"}})
test:throws(
    e_label_config,
    label_utils.validate_labels,
    "testing",
    {labels = {["io..tarantool"] = "1234"}}
)
test:throws(
    e_label_config,
    label_utils.validate_labels,
    "testing",
    {labels = {["io.tarantool..vshard"] = "1234"}}
)
test:throws(
    e_label_config,
    label_utils.validate_labels,
    "testing",
    {labels = {["io.tarantool/vshard"] = "1234"}}
)
