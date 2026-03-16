-- tests/navigation/test_stack.lua
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

T.describe("StackNavigator", function()

    local createStackNavigator = require("navigation.StackNavigator")

    T.it("renders initial screen", function()
        local rendered = nil
        local function HomeScreen(props)
            rendered = "Home"
            return ce("View", {}, ce("Text", {}, "Home Screen"))
        end

        local Stack = createStackNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Stack.Navigator, { initialRouteName = "Home" },
                ce(Stack.Screen, { name = "Home", component = HomeScreen })
            ), container)

        T.expect(rendered).toBe("Home")
    end)

    T.it("passes navigation and route to screen component", function()
        local capturedNav = nil
        local capturedRoute = nil

        local function HomeScreen(props)
            capturedNav = props.navigation
            capturedRoute = props.route
            return ce("View", {})
        end

        local Stack = createStackNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Stack.Navigator, { initialRouteName = "Home" },
                ce(Stack.Screen, { name = "Home", component = HomeScreen })
            ), container)

        T.expect(capturedNav).toBeTruthy()
        T.expect(capturedNav.navigate).toBeTruthy()
        T.expect(capturedNav.goBack).toBeTruthy()
        T.expect(capturedNav.push).toBeTruthy()
        T.expect(capturedRoute).toBeTruthy()
        T.expect(capturedRoute.name).toBe("Home")
    end)

    T.it("navigate pushes new screen", function()
        local capturedNav = nil
        local detailRendered = false

        local function HomeScreen(props)
            capturedNav = props.navigation
            return ce("View", {})
        end
        local function DetailScreen(props)
            detailRendered = true
            return ce("View", {}, ce("Text", {}, "Detail"))
        end

        local Stack = createStackNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Stack.Navigator, { initialRouteName = "Home" },
                ce(Stack.Screen, { name = "Home", component = HomeScreen }),
                ce(Stack.Screen, { name = "Detail", component = DetailScreen })
            ), container)

        capturedNav.navigate("Detail", { id = 1 })
        reconciler.flushUpdates()
        T.expect(detailRendered).toBeTruthy()
    end)

    T.it("goBack pops current screen", function()
        local homeNav = nil
        local detailNav = nil
        local homeRenderCount = 0

        local function HomeScreen(props)
            homeNav = props.navigation
            homeRenderCount = homeRenderCount + 1
            return ce("View", {})
        end
        local function DetailScreen(props)
            detailNav = props.navigation
            return ce("View", {})
        end

        local Stack = createStackNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Stack.Navigator, { initialRouteName = "Home" },
                ce(Stack.Screen, { name = "Home", component = HomeScreen }),
                ce(Stack.Screen, { name = "Detail", component = DetailScreen })
            ), container)

        homeNav.navigate("Detail")
        reconciler.flushUpdates()
        T.expect(detailNav).toBeTruthy()

        detailNav.goBack()
        reconciler.flushUpdates()
        T.expect(homeRenderCount >= 2).toBeTruthy()
    end)

end)

T.summary()
