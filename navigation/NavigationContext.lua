--- NavigationContext module.
-- React context for passing navigation/route to screen components.
-- @module navigation.NavigationContext

local React = require("react")

local M = {}

--- Context for the navigation object (navigate, goBack, push, etc.).
-- @field NavigationContext table React context
M.NavigationContext = React.createContext(nil)

--- Context for the current route (name, params, key).
-- @field RouteContext table React context
M.RouteContext = React.createContext(nil)

return M
