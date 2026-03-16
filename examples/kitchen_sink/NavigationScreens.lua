-- examples/kitchen_sink/NavigationScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local Navigation = require("navigation")
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")
local DemoPage = T.DemoPage

-- 1. StackDemo — embedded mini stack navigator
local function StackDemo()
    local Stack = Navigation.createStackNavigator()

    local function ScreenA(props)
        return ce(DemoPage, {},
            ce("Text", { style = { fontSize = 18, color = T.textPrimary, marginBottom = T.gap } }, "Screen A (root)"),
            ce("View", { style = { gap = 8 } },
                ce(RN.Button, { title = "Push Screen B", color = T.accent, onPress = function()
                    props.navigation.push("ScreenB", { from = "A" })
                end }),
                ce(RN.Button, { title = "Navigate to C", color = "#FF6600", onPress = function()
                    props.navigation.navigate("ScreenC", { from = "A" })
                end })
            )
        )
    end

    local function ScreenB(props)
        local params = props.route and props.route.params or {}
        return ce(DemoPage, {},
            ce("Text", { style = { fontSize = 18, color = T.textPrimary, marginBottom = 4 } }, "Screen B"),
            ce("Text", { style = { fontSize = 14, color = T.textSecondary, marginBottom = T.gap } },
                "Param from: " .. (params.from or "none")),
            ce("View", { style = { gap = 8 } },
                ce(RN.Button, { title = "Push Screen C", color = T.accent, onPress = function()
                    props.navigation.push("ScreenC", { from = "B" })
                end }),
                ce(RN.Button, { title = "Replace with C", color = "#E74C3C", onPress = function()
                    props.navigation.replace("ScreenC", { from = "B-replace" })
                end }),
                ce(RN.Button, { title = "Go Back", color = T.textSecondary, onPress = function()
                    props.navigation.goBack()
                end })
            )
        )
    end

    local function ScreenC(props)
        local params = props.route and props.route.params or {}
        return ce(DemoPage, {},
            ce("Text", { style = { fontSize = 18, color = T.textPrimary, marginBottom = 4 } }, "Screen C"),
            ce("Text", { style = { fontSize = 14, color = T.textSecondary, marginBottom = T.gap } },
                "Param from: " .. (params.from or "none")),
            ce("View", { style = { gap = 8 } },
                ce(RN.Button, { title = "Reset to A", color = "#E74C3C", onPress = function()
                    props.navigation.reset({ routes = { { name = "ScreenA" } }, index = 1 })
                end }),
                ce(RN.Button, { title = "Go Back", color = T.textSecondary, onPress = function()
                    props.navigation.goBack()
                end })
            )
        )
    end

    return ce(Stack.Navigator, {
        screenOptions = {
            headerStyle = { backgroundColor = T.surface },
            headerTintColor = T.textPrimary,
        },
    },
        ce(Stack.Screen, { name = "ScreenA", component = ScreenA, options = { title = "Stack Demo: A" } }),
        ce(Stack.Screen, { name = "ScreenB", component = ScreenB, options = { title = "Stack Demo: B" } }),
        ce(Stack.Screen, { name = "ScreenC", component = ScreenC, options = { title = "Stack Demo: C" } })
    )
end

-- 2. HeaderDemo — embedded stack showing header options
local function HeaderDemo()
    local Stack = Navigation.createStackNavigator()

    local function HeaderList(props)
        local items = {
            { name = "CustomTitle", label = "Custom Title" },
            { name = "StyledHeader", label = "Styled Header" },
            { name = "TintColor", label = "Header Tint Color" },
            { name = "CustomButtons", label = "Left/Right Buttons" },
            { name = "NoHeader", label = "No Header" },
        }
        local elements = {}
        for _, item in ipairs(items) do
            elements[#elements + 1] = ce(RN.Pressable, {
                key = item.name,
                style = { padding = T.pad, backgroundColor = T.surface, borderRadius = T.radiusSmall, marginBottom = T.gap },
                onPress = function() props.navigation.navigate(item.name) end,
            }, ce("Text", { style = { fontSize = 16, color = T.accent } }, item.label))
        end
        return ce("ScrollView", {
            style = { flex = 1, backgroundColor = T.bg },
            contentContainerStyle = { padding = T.pad },
        }, elements)
    end

    local function SimpleScreen(props)
        return ce("View", { style = { flex = 1, backgroundColor = T.bg, padding = T.pad } },
            ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, "Look at the header above!"),
            ce(RN.Button, { title = "Go Back", color = T.accent, onPress = function() props.navigation.goBack() end })
        )
    end

    return ce(Stack.Navigator, {
        screenOptions = {
            headerStyle = { backgroundColor = T.surface },
            headerTintColor = T.textPrimary,
        },
    },
        ce(Stack.Screen, { name = "HeaderList", component = HeaderList, options = { title = "Header Options" } }),
        ce(Stack.Screen, { name = "CustomTitle", component = SimpleScreen, options = { title = "My Custom Title" } }),
        ce(Stack.Screen, { name = "StyledHeader", component = SimpleScreen, options = {
            title = "Styled",
            headerStyle = { backgroundColor = "#E74C3C", height = 80 },
            headerTintColor = "#FFFFFF",
        } }),
        ce(Stack.Screen, { name = "TintColor", component = SimpleScreen, options = {
            title = "Tint Color",
            headerTintColor = "#00C853",
        } }),
        ce(Stack.Screen, { name = "CustomButtons", component = SimpleScreen, options = {
            title = "Buttons",
            headerLeft = function() return ce("Text", { style = { color = T.accent, fontSize = 14 } }, "[Menu]") end,
            headerRight = function() return ce("Text", { style = { color = "#FF6600", fontSize = 14 } }, "[Save]") end,
        } }),
        ce(Stack.Screen, { name = "NoHeader", component = SimpleScreen, options = { headerShown = false } })
    )
end

-- 3. DrawerDemo — embedded mini drawer navigator
local function DrawerDemo()
    local Drawer = Navigation.createDrawerNavigator()

    local function DrawerHome(props)
        return ce("View", { style = { flex = 1, backgroundColor = T.bg, padding = T.pad } },
            ce("Text", { style = { fontSize = 18, color = T.textPrimary, marginBottom = T.gap } }, "Drawer Home"),
            ce("View", { style = { gap = 8 } },
                ce(RN.Button, { title = "Open Drawer", color = T.accent, onPress = function()
                    props.navigation.openDrawer()
                end }),
                ce(RN.Button, { title = "Close Drawer", color = "#E74C3C", onPress = function()
                    props.navigation.closeDrawer()
                end }),
                ce(RN.Button, { title = "Toggle Drawer", color = "#FF6600", onPress = function()
                    props.navigation.toggleDrawer()
                end }),
                ce(RN.Button, { title = "Go to Settings", color = T.textSecondary, onPress = function()
                    props.navigation.navigate("DrawerSettings")
                end })
            )
        )
    end

    local function DrawerSettings(props)
        return ce("View", { style = { flex = 1, backgroundColor = T.bg, padding = T.pad } },
            ce("Text", { style = { fontSize = 18, color = T.textPrimary, marginBottom = T.gap } }, "Settings Screen"),
            ce(RN.Button, { title = "Open Drawer", color = T.accent, onPress = function()
                props.navigation.openDrawer()
            end })
        )
    end

    return ce(Drawer.Navigator, {
        drawerWidth = 220,
    },
        ce(Drawer.Screen, { name = "DrawerHome", component = DrawerHome }),
        ce(Drawer.Screen, { name = "DrawerSettings", component = DrawerSettings })
    )
end

return {
    { name = "StackNav",   component = StackDemo,  description = "Push, pop, replace, reset, params", icon = "S" },
    { name = "Headers",    component = HeaderDemo,  description = "Title, style, buttons, hidden",     icon = "H" },
    { name = "DrawerNav",  component = DrawerDemo,  description = "Open, close, toggle, navigate",     icon = "D" },
}
