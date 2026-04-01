--- Linear gradient component for Solar2D.
-- Drop-in replacement for react-native-linear-gradient.
-- Delegates to the host "LinearGradient" element handled by HostConfig.
-- @module lib.linear-gradient

local React = require("react")
local ce = React.createElement

--- LinearGradient component.
-- @param props table
--   colors table       Array of color strings (e.g. {"#FF0000", "#0000FF"})
--   start table        Gradient start point {x, y} in 0..1 range (default {0, 0})
--   _end table         Gradient end point {x, y} in 0..1 range (default {0, 1})
--   locations table    Optional array of stop positions matching colors
--   style table        Layout and visual style
--   children any       Child elements rendered on top of the gradient
-- @return table React element
local function LinearGradient(props)
    return ce("LinearGradient", props, props and props.children)
end

local M = {
    LinearGradient = LinearGradient,
    default = LinearGradient,
}

--- Module is callable: `require("lib.linear-gradient")(props)`.
return setmetatable(M, {
    __call = function(_, ...)
        return LinearGradient(...)
    end,
})
