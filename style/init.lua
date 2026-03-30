--- Style module.
-- Aggregates StyleSheet and processColor utilities.
-- @module style

local StyleSheet = require("style.StyleSheet")
local processColor = require("style.processColor")

return {
    StyleSheet = StyleSheet,
    processColor = processColor,
}
