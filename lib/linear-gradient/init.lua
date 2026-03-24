-- lib/linear-gradient/init.lua
-- react-native-linear-gradient implementation for Solar2D

local React = require("react")
local ce = React.createElement

local function LinearGradient(props)
    return ce("LinearGradient", props, props and props.children)
end

local M = {
    LinearGradient = LinearGradient,
    default = LinearGradient,
}

return setmetatable(M, {
    __call = function(_, ...)
        return LinearGradient(...)
    end,
})
