#!/usr/bin/env tarantool

local t = require('luatest')
local g = t.group()

local label_utils = require("cartridge.label-utils")
local errors = require("errors")
local e_label_config = errors.new_class("Label configuration error")

--[[
  Instance labels assertions
  Instance labels keys and values must complain with DNS Labels RFC
  https://www.ietf.org/rfc/rfc1035.txt
]]
function g.test_labels_ok()
    t.assert_equals(
        label_utils.validate_labels("field", {}),
        true, "object without labels valid"
    )

    t.assert_equals(
        label_utils.validate_labels("field", {labels = nil}),
        true, "labels of type nil valid"
    )

    t.assert_equals(
        label_utils.validate_labels("field", {labels = {}}),
        true, "labels of type table valid"
    )

    t.assert_equals(
        label_utils.validate_labels("field", {labels = {["key"] = "value"}}),
        true, "label key not exceeding 63 chars valid"
    )

    t.assert_equals(
        label_utils.validate_labels("field", {labels = {["A-z_aZ.19"] = "val"}}),
        true, "label key may contain [a-zA-Z], [0-9], _, -, ."
    )
end

function g.test_labels_error()
    local function check_error(expected_err, labels_data)
        local ok, err = label_utils.validate_labels("testing", labels_data)
        t.assert_equals(ok, nil)
        t.assert_equals(err.class_name, expected_err.name)
    end

    check_error(e_label_config, {labels = 1})
    check_error(e_label_config, {labels = true})
    check_error(e_label_config, {
        labels = function()
        end
    })
    check_error(e_label_config, {labels = "asdfsd"})
    check_error(e_label_config, {labels = {[""] = ""}})
    check_error(e_label_config, {labels = {[""] = "1234"}})
    check_error(e_label_config, {labels = {[".label"] = "1234"}})
    check_error(e_label_config, {labels = {["label."] = "1234"}})
    check_error(e_label_config, {labels = {["io..tarantool"] = "1234"}})
    check_error(e_label_config, {labels = {["io.tarantool..vshard"] = "1234"}})
    check_error(e_label_config, {labels = {["io.tarantool/vshard"] = "1234"}})
end
