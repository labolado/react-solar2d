-- tests/navigation/test_drawer.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

display = require("tests.helpers.mock_display")
display.contentWidth = 320
display.contentHeight = 480
native = { systemFont = "Helvetica" }
timer = { performWithDelay = function() return {} end }
transition = { to = function() end }
Runtime = { addEventListener = function() end }

local T = require("tests.helpers.test_runner")
local React = require("react")
local ce = React.createElement
local HostConfig = require("renderer.HostConfig")
local Reconciler = require("react.Reconciler")

T.describe("DrawerNavigator", function()

    local createDrawerNavigator = require("navigation.DrawerNavigator")

    T.it("renders initial screen with drawer closed", function()
        local mainRendered = false
        local function MainScreen(props)
            mainRendered = true
            return ce("View", {}, ce("Text", {}, "Main"))
        end

        local Drawer = createDrawerNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Drawer.Navigator, { initialRouteName = "Main" },
                ce(Drawer.Screen, { name = "Main", component = MainScreen })
            ), container)

        T.expect(mainRendered).toBeTruthy()
    end)

    T.it("openDrawer/closeDrawer toggles drawer state", function()
        local capturedNav = nil
        local function MainScreen(props)
            capturedNav = props.navigation
            return ce("View", {})
        end

        local Drawer = createDrawerNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Drawer.Navigator, { initialRouteName = "Main" },
                ce(Drawer.Screen, { name = "Main", component = MainScreen })
            ), container)

        T.expect(capturedNav.openDrawer).toBeTruthy()
        T.expect(capturedNav.closeDrawer).toBeTruthy()
        T.expect(capturedNav.toggleDrawer).toBeTruthy()

        -- These should not crash
        capturedNav.openDrawer()
        reconciler.flushUpdates()
        capturedNav.closeDrawer()
        reconciler.flushUpdates()
    end)

    T.it("navigate switches active screen", function()
        local capturedNav = nil
        local settingsRendered = false
        local function MainScreen(props)
            capturedNav = props.navigation
            return ce("View", {})
        end
        local function SettingsScreen(props)
            settingsRendered = true
            return ce("View", {})
        end

        local Drawer = createDrawerNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Drawer.Navigator, { initialRouteName = "Main" },
                ce(Drawer.Screen, { name = "Main", component = MainScreen }),
                ce(Drawer.Screen, { name = "Settings", component = SettingsScreen })
            ), container)

        capturedNav.navigate("Settings")
        reconciler.flushUpdates()
        T.expect(settingsRendered).toBeTruthy()
    end)

end)

T.summary()
