-- navigation/StackNavigator.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useMemo = React.useMemo
local useRef = React.useRef
local NavState = require("navigation.NavigationState")
local NavCtx = require("navigation.NavigationContext")

local function createStackNavigator()
    local function Navigator(props)
        local children = props.children or {}
        if type(children) ~= "table" or children["$$typeof"] then
            children = { children }
        end

        -- Collect Screen configs from children props
        local screens = {}
        for _, child in ipairs(children) do
            if child and child.props and child.props.name then
                screens[#screens + 1] = {
                    name = child.props.name,
                    component = child.props.component,
                    options = child.props.options,
                    listeners = child.props.listeners,
                }
            end
        end

        local initialRouteName = props.initialRouteName or (screens[1] and screens[1].name)

        local initState
        if props.initialState then
            initState = props.initialState
        else
            initState = NavState.createState("stack", { { name = initialRouteName } }, initialRouteName)
        end

        local state, setState = useState(initState)
        local stateRef = useRef(initState)
        stateRef.current = state
        local listenersRef = useRef({})

        -- Build navigation object
        local navigation = useMemo(function()
            local nav = {}

            function nav.navigate(name, params)
                setState(function(prev)
                    return NavState.navigate(prev, name, params)
                end)
            end

            function nav.push(name, params)
                setState(function(prev)
                    return NavState.push(prev, name, params)
                end)
            end

            function nav.goBack()
                setState(function(prev)
                    local current = NavState.getCurrentRoute(prev)
                    if current and listenersRef.current[current.key] then
                        local listener = listenersRef.current[current.key].beforeRemove
                        if listener then
                            local event = {
                                type = "beforeRemove",
                                defaultPrevented = false,
                                preventDefault = function(self)
                                    self.defaultPrevented = true
                                end,
                            }
                            listener(event)
                            if event.defaultPrevented then
                                return prev
                            end
                        end
                    end
                    return NavState.pop(prev)
                end)
            end

            function nav.replace(name, params)
                setState(function(prev)
                    return NavState.replace(prev, name, params)
                end)
            end

            function nav.reset(newState)
                setState(function(prev)
                    return NavState.reset(prev, newState.routes or {}, newState.index)
                end)
            end

            function nav.setParams(params)
                setState(function(prev)
                    return NavState.setParams(prev, params)
                end)
            end

            function nav.isFocused()
                return true
            end

            function nav.addListener(event, callback)
                local currentState = stateRef.current
                local route = NavState.getCurrentRoute(currentState)
                if route then
                    if not listenersRef.current[route.key] then
                        listenersRef.current[route.key] = {}
                    end
                    listenersRef.current[route.key][event] = callback
                end
                return function()
                    if route and listenersRef.current[route.key] then
                        listenersRef.current[route.key][event] = nil
                    end
                end
            end

            function nav.getParent()
                return props._parentNavigation or nil
            end

            nav._getState = function() return stateRef.current end

            return nav
        end, {})

        local Header = require("navigation.Header")

        -- Render screens in stack
        -- unmountOnBlur: only mount active + previous screen, unmount deeper ones
        local unmountOnBlur = props.screenOptions and props.screenOptions.unmountOnBlur
        local keepCount = unmountOnBlur and 2 or #state.routes  -- keep last 2 or all
        local screenElements = {}
        for i, route in ipairs(state.routes) do
            -- Skip screens beyond keepCount from the top
            if i < (#state.routes - keepCount + 1) then
                -- Don't render deep screens when unmountOnBlur is on
                goto continue
            end
            local screenConfig = nil
            for _, s in ipairs(screens) do
                if s.name == route.name then
                    screenConfig = s
                    break
                end
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

                -- Resolve options (table or function)
                local options = screenConfig.options or {}
                if type(options) == "function" then
                    options = options({ route = routeObj, navigation = screenNav })
                end
                local mergedOptions = {}
                if props.screenOptions then
                    for k, v in pairs(props.screenOptions) do mergedOptions[k] = v end
                end
                for k, v in pairs(options) do mergedOptions[k] = v end

                local screenStyle = {
                    display = isActive and "flex" or "none",
                }

                -- Register Screen-level listeners
                if screenConfig.listeners then
                    for event, fn in pairs(screenConfig.listeners) do
                        if not listenersRef.current[route.key] then
                            listenersRef.current[route.key] = {}
                        end
                        listenersRef.current[route.key][event] = fn
                    end
                end

                screenElements[#screenElements + 1] = ce("View", {
                    key = route.key,
                    style = screenStyle,
                },
                    ce(Header, {
                        options = mergedOptions,
                        navigation = screenNav,
                        route = routeObj,
                        canGoBack = i > 1,
                    }),
                    ce(screenConfig.component, {
                        navigation = screenNav,
                        route = routeObj,
                    })
                )
            end
            ::continue::
        end

        return ce("View", { style = props.style or {} }, screenElements)
    end

    local function Screen(props)
        return nil
    end

    return {
        Navigator = Navigator,
        Screen = Screen,
    }
end

return createStackNavigator
