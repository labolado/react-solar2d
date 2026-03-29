-- tests/renderer/test_resize.lua — Window resize support tests
package.path = "./?.lua;./?/init.lua;" .. package.path

-- Preload a stub layout module to prevent loading the C Yoga library
-- (which may segfault outside Solar2D). Layout pass will still run using
-- the stub, allowing us to test handleResize control flow.
local stubNode = {}
stubNode.__index = stubNode
function stubNode:setWidth(v) self._w = v end
function stubNode:setHeight(v) self._h = v end
function stubNode:setFlexBasis(v) self._flexBasis = v end
function stubNode:setFlexShrink(v) self._flexShrink = v end
function stubNode:insertChild(child, idx) self._children[idx] = child end
function stubNode:calculateLayout()
    -- Simple: assign 0,0 position and propagated width/height
    self._lx, self._ly = 0, 0
    self._lw = self._w or 0
    self._lh = self._h or 0
    for _, c in pairs(self._children) do
        c._lx, c._ly = 0, 0
        c._lw = c._w or 0
        c._lh = c._h or 0
    end
end
function stubNode:getLayout() return self._lx or 0, self._ly or 0, self._lw or 0, self._lh or 0 end
function stubNode:getChild(idx) return self._children[idx] end
function stubNode:freeRecursive() end

local stubLayout = {}
function stubLayout.newNode(style)
    local n = setmetatable({ _children = {}, _w = style and style.width, _h = style and style.height }, stubNode)
    return n
end
package.loaded["layout"] = stubLayout

local T = require("tests.helpers.test_runner")

local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay
display.contentWidth = 375
display.contentHeight = 812
display.screenOriginX = 0
display.screenOriginY = 0
display.actualContentWidth = 375
display.actualContentHeight = 812
display.safeScreenOriginX = 0
display.safeScreenOriginY = 0
display.safeActualContentWidth = 375
display.safeActualContentHeight = 812
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
local ReactSolar2D = require("renderer")

T.describe("ReactSolar2D.handleResize", function()
    T.it("exists as a function", function()
        T.expect(type(ReactSolar2D.handleResize)).toBe("function")
    end)

    T.it("does not error when no render has occurred", function()
        local container = mockDisplay.newGroup()
        -- Should be a no-op, not crash
        ReactSolar2D.handleResize(container)
    end)

    T.it("updates container position on resize", function()
        local container = mockDisplay.newGroup()
        container.x = 0
        container.y = 0

        ReactSolar2D.render(
            React.createElement("View", { style = { backgroundColor = "#FFFFFF" } },
                React.createElement("Text", { children = "Hello" })
            ),
            container
        )

        -- Simulate screen origin change (e.g. letterbox resize)
        display.screenOriginX = -10
        display.screenOriginY = -20
        display.actualContentWidth = 400
        display.actualContentHeight = 900

        ReactSolar2D.handleResize(container)

        T.expect(container.x).toBe(-10)
        T.expect(container.y).toBe(-20)

        -- Cleanup
        display.screenOriginX = 0
        display.screenOriginY = 0
        display.actualContentWidth = 375
        display.actualContentHeight = 812
        ReactSolar2D.unmount(container)
    end)
end)

T.describe("ReactSolar2D.startResizeListener", function()
    T.it("exists as a function", function()
        T.expect(type(ReactSolar2D.startResizeListener)).toBe("function")
    end)

    T.it("registers a resize event listener on Runtime", function()
        local container = mockDisplay.newGroup()
        local beforeCount = Runtime._listeners["resize"] and #Runtime._listeners["resize"] or 0

        ReactSolar2D.startResizeListener(container)

        local afterCount = Runtime._listeners["resize"] and #Runtime._listeners["resize"] or 0
        T.expect(afterCount).toBe(beforeCount + 1)
    end)
end)

T.summary()
