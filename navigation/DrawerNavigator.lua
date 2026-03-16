-- navigation/DrawerNavigator.lua
-- Drawer navigator: slide-out side panel (V1: button-only, no swipe gesture).
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useMemo = React.useMemo
local NavState = require("navigation.NavigationState")

local function createDrawerNavigator()

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
            or NavState.createState("drawer", routeConfigs, initialRouteName)

        local state, setState = useState(initState)
        local drawerOpen, setDrawerOpen = useState(false)

        local drawerWidth = props.drawerWidth or 280
        local drawerPosition = props.drawerPosition or "left"
        local drawerStyle = props.drawerStyle or {}

        local navigation = useMemo(function()
            local nav = {}
            function nav.navigate(name, params)
                setState(function(prev)
                    return NavState.switchTab(prev, name) -- drawer uses same switch logic
                end)
                setDrawerOpen(false)
            end
            function nav.goBack()
                setDrawerOpen(false)
            end
            function nav.openDrawer()
                setDrawerOpen(true)
            end
            function nav.closeDrawer()
                setDrawerOpen(false)
            end
            function nav.toggleDrawer()
                setDrawerOpen(function(prev) return not prev end)
            end
            function nav.isFocused() return true end
            nav._getState = function() return state end
            return nav
        end, {})

        -- Render active screen (only active, drawer switches like tabs)
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

        -- Drawer panel
        local drawerContent
        if props.drawerContent then
            drawerContent = props.drawerContent({
                state = state,
                navigation = navigation,
            })
        else
            -- Default drawer: list of screen names
            local items = {}
            for i, s in ipairs(screens) do
                local opts = s.options
                local label = opts.drawerLabel or s.name
                local isActive = (state.routes[state.index].name == s.name)
                items[#items + 1] = ce("View", {
                    key = "drawer_" .. s.name,
                    onPress = function() navigation.navigate(s.name) end,
                    style = {
                        height = 48,
                        justifyContent = "center",
                        backgroundColor = isActive and "#333333" or "transparent",
                    },
                },
                    ce("Text", {
                        style = {
                            color = isActive and "#FFFFFF" or "#CCCCCC",
                            fontSize = 16,
                        },
                    }, label))
            end
            drawerContent = ce("View", {}, items)
        end

        local drawerPanel = ce("View", {
            key = "__drawer_panel",
            style = {
                display = drawerOpen and "flex" or "none",
                width = drawerWidth,
                height = display and display.contentHeight or 480,
                backgroundColor = drawerStyle.backgroundColor or "#1A1A2E",
                position = "absolute",
                left = drawerPosition == "left" and 0 or nil,
                right = drawerPosition == "right" and 0 or nil,
                top = 0,
                zIndex = 100,
            },
        }, drawerContent)

        -- Overlay (tap to close)
        local overlay = ce("View", {
            key = "__drawer_overlay",
            style = {
                display = drawerOpen and "flex" or "none",
                position = "absolute",
                top = 0, left = 0,
                width = display and display.contentWidth or 320,
                height = display and display.contentHeight or 480,
                backgroundColor = "rgba(0,0,0,0.5)",
                zIndex = 99,
            },
            onPress = function() navigation.closeDrawer() end,
        })

        -- Main content + overlay + drawer
        screenElements[#screenElements + 1] = overlay
        screenElements[#screenElements + 1] = drawerPanel

        return ce("View", { style = { flex = 1 } }, screenElements)
    end

    local function Screen(props) return nil end

    return {
        Navigator = Navigator,
        Screen = Screen,
    }
end

return createDrawerNavigator
