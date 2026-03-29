-- KitchenSinkApp.lua
-- Kitchen Sink: comprehensive component showcase
-- Uses a top category bar + stack navigator per category (no nested TabNavigator)
-- Responsive: narrow screen uses top horizontal bar, wide screen uses left sidebar
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useCallback = React.useCallback
local Navigation = require("navigation")
local T = require("kitchen_sink.theme")
local RN = require("react_solar2d")

-- Safe area
local W = display and display.contentWidth or 320
local SCALE = W / 1536
local function s(v) return math.floor(v * SCALE + 0.5) end
local SAFE_TOP = 0
if display and display.safeScreenOriginY and display.screenOriginY then
    SAFE_TOP = math.abs(display.safeScreenOriginY - display.screenOriginY)
end
if SAFE_TOP < s(40) then SAFE_TOP = s(40) end

-- Responsive breakpoint (will be checked at render time for responsiveness)
local SIDEBAR_WIDTH = 160
local function isWideScreen()
    -- Allow force wide mode via global for testing
    if _G.FORCE_WIDE_MODE ~= nil then
        return _G.FORCE_WIDE_MODE
    end
    return display and display.contentWidth >= 600
end

-- Safe require: if a screen module fails, log the error and use empty table
local function safeRequire(mod)
    local ok, result = pcall(require, mod)
    if ok then return result end
    print("[KitchenSink] ERROR loading " .. mod .. ": " .. tostring(result))
    return {}
end

-- Category definitions
local CATEGORIES = {
    { key = "Basics",    label = "基础", screens = safeRequire("kitchen_sink.BasicsScreens") },
    { key = "Forms",     label = "表单", screens = safeRequire("kitchen_sink.FormsScreens") },
    { key = "Lists",     label = "列表", screens = safeRequire("kitchen_sink.ListsScreens") },
    { key = "Nav",       label = "导航", screens = safeRequire("kitchen_sink.NavigationScreens") },
    { key = "Animation", label = "动画", screens = safeRequire("kitchen_sink.AnimationScreens") },
    { key = "Overlay",   label = "弹层", screens = safeRequire("kitchen_sink.OverlayScreens") },
    { key = "Layout",    label = "布局", screens = safeRequire("kitchen_sink.LayoutScreens") },
    { key = "Advanced",  label = "高级", screens = safeRequire("kitchen_sink.AdvancedScreens") },
    { key = "Interop",   label = "互操", screens = safeRequire("kitchen_sink.InteropScreens") },
    { key = "Canvas",    label = "Canvas", screens = safeRequire("kitchen_sink.CanvasScreens") },
}

-- ListScreen: renders a card list for the selected category
local function ListScreen(props)
    local screens = props.screens or {}
    local onSelect = props.onSelect
    local items = {}
    for _, s in ipairs(screens) do
        items[#items + 1] = ce(RN.Pressable, {
            key = s.name,
            style = {
                flexDirection = "row", alignItems = "center",
                backgroundColor = T.surface,
                borderRadius = T.radius, padding = T.pad,
                marginBottom = T.gap,
                borderWidth = 1, borderColor = T.border,
            },
            onPress = function()
                print("[KS] List item tap: " .. s.name)
                if onSelect then onSelect(s) end
            end,
        },
            -- Icon circle
            ce("View", {
                style = {
                    width = 44, height = 44, borderRadius = 22,
                    backgroundColor = T.accent,
                    justifyContent = "center", alignItems = "center",
                    marginRight = T.pad,
                },
            }, ce("Text", {
                style = { fontSize = 18, color = "#FFFFFF", fontWeight = "bold" },
            }, s.icon or s.name:sub(1, 1))),
            -- Text
            ce("View", { style = { flex = 1 } },
                ce("Text", {
                    style = { fontSize = 16, color = T.textPrimary, fontWeight = "bold" },
                }, s.name),
                ce("Text", {
                    style = { fontSize = 12, color = T.textSecondary },
                }, s.description or "")
            )
        )
    end
    return ce("ScrollView", {
        style = { flex = 1, backgroundColor = T.bg },
        contentInset = { bottom = 70 },
    }, items)
end

-- Note: KitchenSinkApp is rendered inside main.lua's NavigationContainer —
-- do NOT wrap in a second NavigationContainer.
local function KitchenSinkApp()
    local activeCategory, setActiveCategory = useState(1)
    local activeDemo, setActiveDemo = useState(nil)
    -- Global overlay stack - supports multiple modals layered
    local overlayStack, setOverlayStack = useState({})

    -- Listen for external navigation events from test server
    -- Store pending route navigation when category changes
    local pendingRouteRef = React.useRef(nil)

    React.useEffect(function()
        local function onExternalNavigate(event)
            local route = event.route
            local category = event.category
            print("[KitchenSink] External navigate: route=" .. tostring(route) .. ", category=" .. tostring(category))

            if category then
                -- Find category index
                for i, cat in ipairs(CATEGORIES) do
                    if cat.key == category then
                        setActiveCategory(i)
                        -- If there's a route, store it for after category update
                        if route then
                            pendingRouteRef.current = route
                        end
                        return
                    end
                end
            end

            if route then
                -- Find demo by name in ALL categories (not just current)
                for _, cat in ipairs(CATEGORIES) do
                    if cat.screens then
                        for _, screen in ipairs(cat.screens) do
                            if screen.name == route then
                                -- Switch to correct category first
                                for i, c in ipairs(CATEGORIES) do
                                    if c.key == cat.key then
                                        setActiveCategory(i)
                                        break
                                    end
                                end
                                setActiveDemo(screen)
                                return
                            end
                        end
                    end
                end
                print("[KitchenSink] Route not found: " .. route)
            end
        end

        Runtime:addEventListener("kitchensink_navigate", onExternalNavigate)
        return function()
            Runtime:removeEventListener("kitchensink_navigate", onExternalNavigate)
        end
    end, {})  -- Empty deps - handler doesn't depend on activeCategory

    -- Callback for demos to push content to global overlay stack
    local pushOverlay = useCallback(function(content)
        setOverlayStack(function(stack)
            local newStack = {}
            for _, v in ipairs(stack) do table.insert(newStack, v) end
            table.insert(newStack, content)
            return newStack
        end)
    end, {})

    -- Pop top overlay from stack
    local popOverlay = useCallback(function()
        setOverlayStack(function(stack)
            if #stack == 0 then return stack end
            local newStack = {}
            for i = 1, #stack - 1 do
                newStack[i] = stack[i]
            end
            return newStack
        end)
    end, {})

    -- Clear all overlays
    local clearOverlay = useCallback(function()
        setOverlayStack({})
    end, {})

    -- Category button press handler (shared between narrow and wide modes)
    local onCategoryPress = useCallback(function(i, cat)
        print("[KS] Category tap: " .. cat.label .. " (" .. i .. ")")
        setActiveCategory(i)
        setActiveDemo(nil)
        clearOverlay()
    end, {})

    -- Build category buttons for narrow mode (horizontal)
    local narrowCatButtons = {}
    for i, cat in ipairs(CATEGORIES) do
        local isActive = (i == activeCategory)
        narrowCatButtons[#narrowCatButtons + 1] = ce(RN.Pressable, {
            key = cat.key,
            style = {
                paddingHorizontal = 6,
                paddingVertical = 4,
                marginRight = 2,
                marginBottom = 2,
                borderRadius = T.radiusSmall,
                backgroundColor = isActive and T.accent or "transparent",
            },
            onPress = function() onCategoryPress(i, cat) end,
        }, ce("Text", {
            style = {
                fontSize = 12,
                fontWeight = isActive and "bold" or "normal",
                color = isActive and "#FFFFFF" or T.textSecondary,
            },
        }, cat.label))
    end

    -- Build category buttons for wide mode (vertical sidebar)
    local wideCatButtons = {}
    for i, cat in ipairs(CATEGORIES) do
        local isActive = (i == activeCategory)
        wideCatButtons[#wideCatButtons + 1] = ce(RN.Pressable, {
            key = cat.key,
            style = {
                paddingHorizontal = 12,
                paddingVertical = 10,
                marginBottom = 2,
                borderRadius = T.radiusSmall,
                backgroundColor = isActive and T.accent or "transparent",
            },
            onPress = function() onCategoryPress(i, cat) end,
        }, ce("Text", {
            style = {
                fontSize = 14,
                fontWeight = isActive and "bold" or "normal",
                color = isActive and "#FFFFFF" or T.textSecondary,
            },
        }, cat.label))
    end

    -- Narrow mode: horizontal scrollable category bar
    local narrowCategoryBar = ce(RN.ScrollView, {
        horizontal = true,
        contentInset = { right = 40 },
        style = {
            backgroundColor = T.surface,
            paddingTop = SAFE_TOP + 8,
            paddingBottom = 8,
            borderBottomWidth = 1,
            borderColor = T.border,
            zIndex = 100,
            height = SAFE_TOP + 50,
        },
    }, ce("View", {
        style = {
            flexDirection = "row",
            paddingHorizontal = T.pad,
        },
    }, narrowCatButtons))

    -- Wide mode: left sidebar with vertical category list
    local wideSidebar = ce("View", {
        style = {
            width = SIDEBAR_WIDTH,
            backgroundColor = T.surface,
            paddingTop = SAFE_TOP + 8,
            borderRightWidth = 1,
            borderColor = T.border,
            zIndex = 100,
        },
    }, ce("ScrollView", {
        style = { flex = 1 },
        contentContainerStyle = { paddingHorizontal = 8, paddingBottom = 16 },
    }, wideCatButtons))

    -- Content: either demo list or active demo component
    local content
    if activeDemo then
        local backBtn = ce(RN.Pressable, {
            style = {
                flexDirection = "row", alignItems = "center",
                paddingHorizontal = 12, paddingVertical = 8,
                backgroundColor = T.surface,
                borderBottomWidth = 1, borderColor = T.border,
            },
            onPress = function()
                setActiveDemo(nil)
                clearOverlay()
            end,
        }, ce("Text", {
            style = { fontSize = 14, color = T.accent },
        }, "← " .. activeDemo.name))

        content = ce("View", { style = { flex = 1, backgroundColor = T.bg } },
            backBtn,
            ce("View", { style = { flex = 1, paddingHorizontal = 12, paddingBottom = 0 } },
                ce(activeDemo.component, {
                    navigation = { goBack = function() setActiveDemo(nil) end },
                    route = { name = activeDemo.name, params = {} },
                    pushOverlay = pushOverlay,
                    popOverlay = popOverlay,
                    clearOverlay = clearOverlay,
                })
            )
        )
    else
        local cat = CATEGORIES[activeCategory]
        content = ce("View", { style = { flex = 1, paddingBottom = 0 } },
            ce(ListScreen, {
                screens = cat and cat.screens or {},
                onSelect = function(s)
                    setActiveDemo(s)
                end,
            })
        )
    end

    -- Main layout structure based on screen width (checked at render time)
    local IS_WIDE = isWideScreen()
    local mainContent
    if IS_WIDE then
        -- Wide mode: sidebar on left, content on right
        mainContent = ce("View", { style = { flex = 1, flexDirection = "row" } },
            wideSidebar,
            ce("View", { style = { flex = 1 } }, content)
        )
    else
        -- Narrow mode: horizontal bar at top, content below
        mainContent = ce("View", { style = { flex = 1 } },
            narrowCategoryBar,
            content
        )
    end

    -- Structure:
    -- 1. Main content (responsive layout)
    -- 2. Global overlay layer (renders ABOVE everything)
    return ce("View", { style = { flex = 1, backgroundColor = T.bg } },
        -- Main content layer
        mainContent,
        -- Global overlay layer - always on top when content exists
        (#overlayStack > 0) and ce("View", {
            style = {
                position = "absolute",
                top = 0, left = 0,
                width = display.contentWidth,
                height = display.contentHeight,
                zIndex = 99999,
            },
        }, overlayStack[#overlayStack]) or nil
    )
end

return KitchenSinkApp
