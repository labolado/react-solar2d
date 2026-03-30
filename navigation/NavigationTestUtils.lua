--- NavigationTestUtils module.
-- Helpers for navigating to specific screens in tests.
-- @module navigation.NavigationTestUtils

local NavState = require("navigation.NavigationState")

local M = {}

--- Build an initialState that navigates to the given screen with params.
-- @param screenPath string Simple name "Detail" or nested "News/Detail"
-- @param[opt] params table Route params
-- @return table Initial navigation state
function M.buildInitialState(screenPath, params)
    local names = {}
    for name in screenPath:gmatch("[^/]+") do
        names[#names + 1] = name
    end

    local routes = {}
    for i, name in ipairs(names) do
        routes[i] = {
            name = name,
            params = (i == #names) and params or nil,
        }
    end

    return {
        type = "stack",
        index = #routes,
        routes = routes,
    }
end

--- Parse a .route file path like "news/detail/123" into app name + initialState.
-- @param routePath string Route path
-- @return string|nil App name
-- @return table|nil Initial navigation state
function M.parseRoutePath(routePath)
    local parts = {}
    for part in routePath:gmatch("[^/]+") do
        parts[#parts + 1] = part
    end

    if #parts == 0 then return nil, nil end

    local appName = parts[1]
    if #parts == 1 then
        return appName, nil -- just app, no screen routing
    end

    -- Remaining parts are screen path, last numeric part is a param
    local screenParts = {}
    local lastParam = nil
    for i = 2, #parts do
        if i == #parts and parts[i]:match("^%d+$") then
            lastParam = parts[i]
        else
            screenParts[#screenParts + 1] = parts[i]
        end
    end

    local screenPath = table.concat(screenParts, "/")
    local params = lastParam and { id = lastParam } or nil

    return appName, M.buildInitialState(screenPath, params)
end

return M
