-- examples/KitchenSinkApp.lua
-- Kitchen Sink: comprehensive component showcase
local React = require("react")
local ce = React.createElement
local Navigation = require("navigation")
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")

-- Shared ListScreen: renders a card list from screen descriptors
-- Note: KitchenSinkApp is rendered inside main.lua's NavigationContainer —
-- do NOT wrap in a second NavigationContainer.
local function ListScreen(props)
    local screens = props.route and props.route.params and props.route.params.screens or {}
    local navigation = props.navigation
    local items = {}
    for i, s in ipairs(screens) do
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
                navigation.navigate(s.name)
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
        contentContainerStyle = { padding = T.pad },
    }, items)
end

-- Tab definitions
local TAB_CONFIGS = {
    { key = "Basics",     label = "基础",   icon = "B", screens = require("examples.kitchen_sink.BasicsScreens") },
    { key = "Forms",      label = "表单",   icon = "F", screens = require("examples.kitchen_sink.FormsScreens") },
    { key = "Lists",      label = "列表",   icon = "L", screens = require("examples.kitchen_sink.ListsScreens") },
    { key = "Nav",        label = "导航",   icon = "N", screens = require("examples.kitchen_sink.NavigationScreens") },
    { key = "Animation",  label = "动画",   icon = "A", screens = require("examples.kitchen_sink.AnimationScreens") },
    { key = "Interop",    label = "互操",   icon = "I", screens = require("examples.kitchen_sink.InteropScreens") },
}

-- Build a StackNavigator for each tab category
local function createTabStack(tabConfig)
    local Stack = Navigation.createStackNavigator()
    return function(props)
        local screenElements = {
            ce(Stack.Screen, {
                name = tabConfig.key .. "List",
                component = ListScreen,
                options = { title = tabConfig.label, headerShown = false },
            }),
        }
        for _, s in ipairs(tabConfig.screens) do
            screenElements[#screenElements + 1] = ce(Stack.Screen, {
                name = s.name,
                component = s.component,
                options = { title = s.name },
            })
        end
        return ce(Stack.Navigator, {
            initialRouteName = tabConfig.key .. "List",
            initialState = {
                type = "stack",
                index = 1,
                routes = { { name = tabConfig.key .. "List", key = tabConfig.key .. "List-1", params = { screens = tabConfig.screens } } },
            },
            screenOptions = {
                headerStyle = { backgroundColor = T.surface },
                headerTintColor = T.textPrimary,
            },
        }, screenElements)
    end
end

-- Build tab screen components
local tabStacks = {}
for _, config in ipairs(TAB_CONFIGS) do
    tabStacks[config.key] = createTabStack(config)
end

local Tab = Navigation.createBottomTabNavigator()

local function KitchenSinkApp()
    local tabScreens = {}
    for _, config in ipairs(TAB_CONFIGS) do
        tabScreens[#tabScreens + 1] = ce(Tab.Screen, {
            name = config.key,
            component = tabStacks[config.key],
            options = { tabBarLabel = config.label, tabBarIcon = config.icon },
        })
    end
    return ce(Tab.Navigator, {
        tabBarOptions = {
            activeTintColor = T.tabActive,
            inactiveTintColor = T.tabInactive,
            backgroundColor = T.surface,
        },
    }, tabScreens)
end

return KitchenSinkApp
