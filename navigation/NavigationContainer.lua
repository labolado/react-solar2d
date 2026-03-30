--- NavigationContainer module.
-- Root component: wraps the navigator tree with NavigationContext.Provider.
-- @module navigation.NavigationContainer

local React = require("react")
local ce = React.createElement
local useState = React.useState
local NavCtx = require("navigation.NavigationContext")

-- Load DeepLinking gracefully (may not exist yet)
local ok, DeepLinking = pcall(require, "navigation.DeepLinking")
if not ok then
    DeepLinking = { resolve = function() return nil end }
end

--- NavigationContainer component.
-- @param props table {children, initialState, linking, initialURL}
-- @return table React element
local function NavigationContainer(props)
    local children = props.children

    -- Resolve initial state from deep linking or initialState prop
    local initialState = props.initialState
    if not initialState and props.linking then
        local url = props.initialURL
        if not url and _G.system and _G.system.LaunchArgs then
            url = _G.system.LaunchArgs.url
        end
        if url then
            initialState = DeepLinking.resolve(url, props.linking)
        end
    end

    -- Pass initialState down to child navigator if present
    if initialState and children and children.props then
        -- Clone child element with initialState injected
        local childProps = {}
        for k, v in pairs(children.props) do childProps[k] = v end
        childProps.initialState = initialState
        children = ce(children.type, childProps, children.props.children)
    end

    -- Wrap with NavigationContext.Provider so deeply nested screens
    -- can access navigation via useContext
    return ce(NavCtx.NavigationContext.Provider, { value = {
        linking = props.linking,
        initialState = initialState,
    } },
        ce("View", {
            style = {
                width = display and display.contentWidth or 320,
                height = display and display.contentHeight or 480,
            },
        }, children)
    )
end

return NavigationContainer
