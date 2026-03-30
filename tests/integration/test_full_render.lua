-- tests/integration/test_full_render.lua — End-to-end render + state update tests
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay
display.contentWidth = 375
display.contentHeight = 812
display.safeScreenOriginX = 0
display.safeScreenOriginY = 0
display.screenOriginX = 0
display.screenOriginY = 0
display.actualContentWidth = 375
display.actualContentHeight = 812
native = { systemFont = "systemFont", systemFontBold = "systemFontBold" }
timer = { performWithDelay = function() return {} end, cancel = function() end }
network = { download = function() end }
system = { TemporaryDirectory = "/tmp" }
Runtime = {
    _listeners = {},
    addEventListener = function(self, event, fn)
        self._listeners[event] = self._listeners[event] or {}
        table.insert(self._listeners[event], fn)
    end,
    removeEventListener = function() end,
}

local React = require("react")
local Reconciler = require("react.Reconciler")
local HostConfig = require("renderer.HostConfig")

T.describe("Integration: simple component render", function()
    T.it("renders View with Text child", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)

        reconciler.render(
            React.createElement("View", { style = { backgroundColor = "#FFFFFF" } },
                React.createElement("Text", { children = "Hello World" })
            ),
            container
        )

        T.expect(container.numChildren).toBe(1) -- View
        local view = container[1]
        T.expect(view._type).toBe("group")
        -- Without explicit size, _bg creation is deferred to applyLayout.
        -- Either _bg (if size was known) or _pendingBg (deferred) must be set.
        T.expect(view._bg or view._pendingBg).toBeTruthy()
        -- View has Text child (+ bg rect if layout has run)
        T.expect(view.numChildren >= 1).toBe(true)
    end)

    T.it("renders function component", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)

        local function MyCard(props)
            return React.createElement("View", {
                style = { backgroundColor = "#F0F0F0", width = 200, height = 100 }
            },
                React.createElement("Text", { children = props.title })
            )
        end

        reconciler.render(
            React.createElement(MyCard, { title = "Test Card" }),
            container
        )

        T.expect(container.numChildren).toBe(1)
    end)
end)

T.describe("Integration: useState re-render", function()
    T.it("state change updates rendered text", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)
        local setCount

        local function Counter()
            local count, set = React.useState(0)
            setCount = set
            return React.createElement("View", {},
                React.createElement("Text", { children = "Count: " .. tostring(count) })
            )
        end

        reconciler.render(React.createElement(Counter), container)

        -- Find the text object
        local function findText(group)
            if not group or not group.numChildren then return nil end
            for i = 1, group.numChildren do
                local c = group[i]
                if c and c._textObj then return c._textObj end
                local found = findText(c)
                if found then return found end
            end
            return nil
        end

        local textObj = findText(container)
        T.expect(textObj).toBeTruthy()
        T.expect(textObj.text).toBe("Count: 0")

        -- Update state
        setCount(5)
        reconciler.flushUpdates()

        textObj = findText(container)
        T.expect(textObj.text).toBe("Count: 5")
    end)

    T.it("functional updater increments correctly", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)
        local setCount

        local function Counter()
            local count, set = React.useState(0)
            setCount = set
            return React.createElement("Text", { children = tostring(count) })
        end

        reconciler.render(React.createElement(Counter), container)

        setCount(function(prev) return prev + 1 end)
        setCount(function(prev) return prev + 1 end)
        setCount(function(prev) return prev + 1 end)
        reconciler.flushUpdates()

        local function findText(group)
            if not group or not group.numChildren then return nil end
            for i = 1, group.numChildren do
                local c = group[i]
                if c and c._textObj then return c._textObj end
                local found = findText(c)
                if found then return found end
            end
            return nil
        end

        local textObj = findText(container)
        T.expect(textObj.text).toBe("3")
    end)
end)

T.describe("Integration: conditional rendering", function()
    T.it("shows/hides child based on state", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)
        local setShow

        local function Toggle()
            local show, set = React.useState(true)
            setShow = set
            if show then
                return React.createElement("Text", { children = "visible" })
            else
                return React.createElement("Text", { children = "hidden" })
            end
        end

        reconciler.render(React.createElement(Toggle), container)

        local function findText(group)
            if not group or not group.numChildren then return nil end
            for i = 1, group.numChildren do
                local c = group[i]
                if c and c._textObj then return c._textObj end
                local found = findText(c)
                if found then return found end
            end
            return nil
        end

        T.expect(findText(container).text).toBe("visible")

        setShow(false)
        reconciler.flushUpdates()
        T.expect(findText(container).text).toBe("hidden")
    end)
end)

T.describe("Integration: nested function components", function()
    T.it("renders nested components correctly", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)

        local function Inner(props)
            return React.createElement("Text", { children = props.label })
        end

        local function Outer()
            return React.createElement("View", {},
                React.createElement(Inner, { label = "nested" })
            )
        end

        reconciler.render(React.createElement(Outer), container)

        local function findText(group)
            if not group or not group.numChildren then return nil end
            for i = 1, group.numChildren do
                local c = group[i]
                if c and c._textObj then return c._textObj end
                local found = findText(c)
                if found then return found end
            end
            return nil
        end

        local textObj = findText(container)
        T.expect(textObj).toBeTruthy()
        T.expect(textObj.text).toBe("nested")
    end)
end)

T.describe("Integration: ScrollView with children", function()
    T.it("renders children into contentGroup", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)

        reconciler.render(
            React.createElement("ScrollView", { style = { width = 300, height = 400 } },
                React.createElement("Text", { children = "Item 1" }),
                React.createElement("Text", { children = "Item 2" })
            ),
            container
        )

        local sv = container[1]
        T.expect(sv._contentGroup).toBeTruthy()
        T.expect(sv._contentGroup.numChildren).toBe(2)
    end)
end)

T.summary()
