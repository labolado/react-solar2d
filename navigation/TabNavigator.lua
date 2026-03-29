-- navigation/TabNavigator.lua
-- Bottom tab navigator: parallel screens with tab bar.
-- All tabs rendered, only active visible (display="none" for inactive).
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useMemo = React.useMemo
local useRef = React.useRef
local NavState = require("navigation.NavigationState")

local function createBottomTabNavigator()

    local function Navigator(props)
        local children = props.children or {}
        if type(children) ~= "table" or children["$$typeof"] then
            children = { children }
        end

        local screens = {}
        for _, child in ipairs(children) do
            if child and child.props and child.props.name then
                screens[#screens + 1] = {
                    name = child.props.name,
                    component = child.props.component,
                    options = child.props.options or {},
                }
            end
        end

        local initialRouteName = props.initialRouteName or (screens[1] and screens[1].name)
        local routeConfigs = {}
        for _, s in ipairs(screens) do
            routeConfigs[#routeConfigs + 1] = { name = s.name }
        end

        local initState = props.initialState
            or NavState.createState("tab", routeConfigs, initialRouteName)

        local state, setState = useState(initState)
        local stateRef = useRef(initState)
        stateRef.current = state
        local tabBarOptions = props.tabBarOptions or {}

        local navigation = useMemo(function()
            local nav = {}
            function nav.navigate(name, params)
                setState(function(prev)
                    return NavState.navigate(prev, name, params)
                end)
            end
            function nav.goBack() end -- no-op for tabs
            function nav.isFocused() return true end
            nav._getState = function() return stateRef.current end
            return nav
        end, {})

        -- Render all tab screens
        local screenElements = {}
        for i, route in ipairs(state.routes) do
            local screenConfig = nil
            for _, s in ipairs(screens) do
                if s.name == route.name then screenConfig = s; break end
            end
            if screenConfig then
                local isActive = (i == state.index)
                local routeObj = {
                    name = route.name,
                    key = route.key,
                    params = route.params or {},
                }
                local screenNav = {}
                for k, v in pairs(navigation) do screenNav[k] = v end
                screenNav.isFocused = function() return isActive end

                screenElements[#screenElements + 1] = ce("View", {
                    key = route.key,
                    style = { display = isActive and "flex" or "none", flex = 1 },
                }, ce(screenConfig.component, {
                    navigation = screenNav,
                    route = routeObj,
                }))
            end
        end

        -- Tab bar
        local tabItems = {}
        for i, screen in ipairs(screens) do
            local isActive = (state.routes[state.index].name == screen.name)
            local opts = screen.options
            local label = opts.tabBarLabel or screen.name
            local icon = opts.tabBarIcon or ""
            local tint = isActive
                and (tabBarOptions.activeTintColor or "#2979FF")
                or (tabBarOptions.inactiveTintColor or "#888888")

            tabItems[#tabItems + 1] = ce("View", {
                key = "tab_" .. screen.name,
                onPress = function()
                    navigation.navigate(screen.name)
                end,
                style = {
                    flex = 1,
                    alignItems = "center",
                    justifyContent = "center",
                    height = 56,
                },
            },
                ce("Text", { style = { color = tint, fontSize = tabBarOptions.iconSize or 16 } }, icon),
                (tabBarOptions.showLabel ~= false)
                    and ce("Text", { style = { color = tint, fontSize = tabBarOptions.labelSize or 12 } }, label)
                    or nil
            )
        end

        local TAB_BAR_H = tabBarOptions.height or 56
        local tabBarBg = tabBarOptions.backgroundColor or "#FFFFFF"
        local contentW = display and display.contentWidth or 320
        local contentH = display and display.contentHeight or 480
        local tabBar = ce("View", {
            key = "__tabbar",
            style = {
                position = "absolute",
                bottom = 0, left = 0,
                flexDirection = "row",
                height = TAB_BAR_H,
                backgroundColor = tabBarBg,
                width = contentW,
            },
        }, (unpack or table.unpack)(tabItems))

        -- Layout: content area above tab bar + tab bar pinned at bottom
        local contentArea = ce("View", {
            key = "__content",
            style = {
                position = "absolute",
                top = 0, left = 0,
                width = contentW,
                height = contentH - TAB_BAR_H,
                overflow = "hidden",
            },
        }, screenElements)

        return ce("View", { style = { width = contentW, height = contentH } },
            contentArea,
            tabBar
        )
    end

    local function Screen(props) return nil end

    return {
        Navigator = Navigator,
        Screen = Screen,
    }
end

return createBottomTabNavigator
