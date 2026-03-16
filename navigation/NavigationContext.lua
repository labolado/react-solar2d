-- navigation/NavigationContext.lua
-- React context for passing navigation/route to screen components.
local React = require("react")

local M = {}

-- Context for the navigation object (navigate, goBack, push, etc.)
M.NavigationContext = React.createContext(nil)

-- Context for the current route (name, params, key)
M.RouteContext = React.createContext(nil)

return M
