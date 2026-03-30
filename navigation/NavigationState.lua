--- NavigationState module.
-- Pure state tree operations for navigation. No display objects, no React.
-- All indices 1-based (Lua convention).
-- @module navigation.NavigationState

local M = {}

local keyCounter = 0
local function generateKey(name)
    keyCounter = keyCounter + 1
    return name .. "-" .. keyCounter
end

--- Create an initial navigation state.
-- @param navType string "stack", "tab", or "drawer"
-- @param routeConfigs table Array of {name, params}
-- @param initialRouteName string Name of the initial route
-- @return table Navigation state
function M.createState(navType, routeConfigs, initialRouteName)
    local routes = {}
    local initialIndex = 1
    for i, config in ipairs(routeConfigs) do
        routes[i] = {
            name = config.name,
            key = generateKey(config.name),
            params = config.params,
        }
        if config.name == initialRouteName then
            initialIndex = i
        end
    end
    return { type = navType, index = initialIndex, routes = routes }
end

--- Push a new route onto the stack.
-- @param state table Current state
-- @param name string Route name
-- @param[opt] params table Route params
-- @return table New state
function M.push(state, name, params)
    local routes = {}
    for i = 1, state.index do
        routes[i] = state.routes[i]
    end
    routes[#routes + 1] = {
        name = name, key = generateKey(name), params = params,
    }
    return { type = state.type, index = #routes, routes = routes }
end

--- Pop the top route from the stack.
-- @param state table Current state
-- @return table New state
function M.pop(state)
    if #state.routes <= 1 then return state end
    local routes = {}
    for i = 1, #state.routes - 1 do
        routes[i] = state.routes[i]
    end
    return { type = state.type, index = #routes, routes = routes }
end

--- Replace the current route.
-- @param state table Current state
-- @param name string New route name
-- @param[opt] params table Route params
-- @return table New state
function M.replace(state, name, params)
    local routes = {}
    for i = 1, #state.routes do routes[i] = state.routes[i] end
    routes[state.index] = {
        name = name, key = generateKey(name), params = params,
    }
    return { type = state.type, index = state.index, routes = routes }
end

--- Switch to a different tab/drawer item.
-- @param state table Current state
-- @param name string Route name to switch to
-- @return table New state
function M.switchTab(state, name)
    for i, route in ipairs(state.routes) do
        if route.name == name then
            return { type = state.type, index = i, routes = state.routes }
        end
    end
    return state
end

--- Reset the state to a new set of routes.
-- @param state table Current state
-- @param routeConfigs table Array of {name, params}
-- @param[opt] index number New active index
-- @return table New state
function M.reset(state, routeConfigs, index)
    local routes = {}
    for i, config in ipairs(routeConfigs) do
        routes[i] = {
            name = config.name, key = generateKey(config.name), params = config.params,
        }
    end
    return { type = state.type, index = index or #routes, routes = routes }
end

--- Set params on the current route.
-- @param state table Current state
-- @param newParams table Params to merge
-- @return table New state
function M.setParams(state, newParams)
    local routes = {}
    for i = 1, #state.routes do routes[i] = state.routes[i] end
    local current = routes[state.index]
    local merged = {}
    if current.params then
        for k, v in pairs(current.params) do merged[k] = v end
    end
    for k, v in pairs(newParams) do merged[k] = v end
    routes[state.index] = {
        name = current.name, key = current.key, params = merged, state = current.state,
    }
    return { type = state.type, index = state.index, routes = routes }
end

--- Navigate to a route (switch tab if exists, otherwise push).
-- @param state table Current state
-- @param name string Route name
-- @param[opt] params table Route params
-- @return table New state
function M.navigate(state, name, params)
    if state.type == "tab" or state.type == "drawer" then
        local next = M.switchTab(state, name)
        if params and next ~= state then
            local routes = {}
            for i = 1, #next.routes do routes[i] = next.routes[i] end
            local r = routes[next.index]
            routes[next.index] = { name = r.name, key = r.key, params = params, state = r.state }
            return { type = next.type, index = next.index, routes = routes }
        end
        return next
    end
    for i, route in ipairs(state.routes) do
        if route.name == name then
            local routes = {}
            for j = 1, i do routes[j] = state.routes[j] end
            if params then
                routes[i] = {
                    name = routes[i].name, key = routes[i].key,
                    params = params, state = routes[i].state,
                }
            end
            return { type = state.type, index = i, routes = routes }
        end
    end
    return M.push(state, name, params)
end

--- Get the currently active route.
-- @param state table Navigation state
-- @return table Current route
function M.getCurrentRoute(state)
    return state.routes[state.index]
end

return M
