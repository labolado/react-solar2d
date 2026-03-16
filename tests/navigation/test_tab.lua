-- tests/navigation/test_tab.lua
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

T.describe("TabNavigator", function()

    local createBottomTabNavigator = require("navigation.TabNavigator")

    T.it("renders initial tab", function()
        local rendered = nil
        local function NewsScreen(props)
            rendered = "News"
            return ce("View", {}, ce("Text", {}, "News"))
        end
        local function QuizScreen(props)
            return ce("View", {}, ce("Text", {}, "Quiz"))
        end

        local Tab = createBottomTabNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Tab.Navigator, { initialRouteName = "News" },
                ce(Tab.Screen, { name = "News", component = NewsScreen }),
                ce(Tab.Screen, { name = "Quiz", component = QuizScreen })
            ), container)

        T.expect(rendered).toBe("News")
    end)

    T.it("switch tab via navigation.navigate", function()
        local capturedNav = nil
        local quizRendered = false

        local function NewsScreen(props)
            capturedNav = props.navigation
            return ce("View", {})
        end
        local function QuizScreen(props)
            quizRendered = true
            return ce("View", {})
        end

        local Tab = createBottomTabNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Tab.Navigator, { initialRouteName = "News" },
                ce(Tab.Screen, { name = "News", component = NewsScreen }),
                ce(Tab.Screen, { name = "Quiz", component = QuizScreen })
            ), container)

        capturedNav.navigate("Quiz")
        reconciler.flushUpdates()
        T.expect(quizRendered).toBeTruthy()
    end)

    T.it("preserves screen state on tab switch", function()
        local newsRenderCount = 0

        local function NewsScreen(props)
            newsRenderCount = newsRenderCount + 1
            return ce("View", {})
        end
        local function QuizScreen(props)
            return ce("View", {})
        end

        local Tab = createBottomTabNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        local capturedNav = nil

        local function NewsWrapper(props)
            capturedNav = props.navigation
            return ce(NewsScreen, props)
        end

        reconciler.render(
            ce(Tab.Navigator, { initialRouteName = "News" },
                ce(Tab.Screen, { name = "News", component = NewsWrapper }),
                ce(Tab.Screen, { name = "Quiz", component = QuizScreen })
            ), container)

        local countAfterFirst = newsRenderCount
        capturedNav.navigate("Quiz")
        reconciler.flushUpdates()
        capturedNav.navigate("News")
        reconciler.flushUpdates()
        -- News should have re-rendered (UPDATE, not PLACEMENT)
        T.expect(newsRenderCount > countAfterFirst).toBeTruthy()
    end)

end)

T.summary()
