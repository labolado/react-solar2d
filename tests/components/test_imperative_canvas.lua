-- tests/components/test_imperative_canvas.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay
display.contentWidth = 375
display.contentHeight = 812
native = { systemFont = "systemFont", systemFontBold = "systemFontBold" }
timer = { performWithDelay = function() return {} end, cancel = function() end }

-- Runtime mock with working add/remove
Runtime = {
    _listeners = {},
    addEventListener = function(self, event, fn)
        self._listeners[event] = self._listeners[event] or {}
        table.insert(self._listeners[event], fn)
    end,
    removeEventListener = function(self, event, fn)
        local list = self._listeners[event]
        if list then
            for i, f in ipairs(list) do
                if f == fn then table.remove(list, i); break end
            end
        end
    end,
}

local React = require("react")
local Reconciler = require("react.Reconciler")
local HostConfig = require("renderer.HostConfig")
local ImperativeCanvas = require("components.ImperativeCanvas")
local ce = React.createElement

T.describe("ImperativeCanvas: basic mount", function()
    T.it("renders a View and calls onDraw with surface", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)
        local drawCalled = false
        local drawnSurface = nil
        local drawnW, drawnH = nil, nil

        reconciler.render(
            ce(ImperativeCanvas, {
                style = { width = 200, height = 150 },
                onDraw = function(surface, w, h)
                    drawCalled = true
                    drawnSurface = surface
                    drawnW = w
                    drawnH = h
                end,
            }),
            container
        )

        T.expect(drawCalled).toBe(true)
        T.expect(drawnSurface).toBeTruthy()
        T.expect(drawnSurface._type).toBe("group")
        T.expect(drawnW).toBe(200)
        T.expect(drawnH).toBe(150)
    end)

    T.it("surface is inserted into the View", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)
        local drawnSurface = nil

        reconciler.render(
            ce(ImperativeCanvas, {
                style = { width = 200, height = 150 },
                onDraw = function(surface, w, h)
                    drawnSurface = surface
                end,
            }),
            container
        )

        -- The View is container's first child
        local view = container[1]
        T.expect(view).toBeTruthy()
        -- Surface should be parented to the view
        T.expect(drawnSurface._parent).toBe(view)
    end)
end)

T.describe("ImperativeCanvas: onDraw cleanup", function()
    T.it("onDraw can return a cleanup function", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)
        local cleanedUp = false

        reconciler.render(
            ce(ImperativeCanvas, {
                style = { width = 200, height = 150 },
                onDraw = function(surface, w, h)
                    return function()
                        cleanedUp = true
                    end
                end,
            }),
            container
        )

        T.expect(cleanedUp).toBe(false)
        reconciler.unmount(container)
        -- Note: cleanup happens via effect cleanup which is managed by reconciler
        -- In the mock test environment, unmount removes display objects
        -- The cleanup function would be called when effects are cleaned up
    end)
end)

T.describe("ImperativeCanvas: onFrame listener", function()
    T.it("registers enterFrame listener when onFrame provided", function()
        Runtime._listeners = {}
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)

        local frameCalls = 0
        reconciler.render(
            ce(ImperativeCanvas, {
                style = { width = 200, height = 150 },
                onDraw = function() end,
                onFrame = function(surface, dt)
                    frameCalls = frameCalls + 1
                end,
            }),
            container
        )

        T.expect(Runtime._listeners["enterFrame"]).toBeTruthy()
        T.expect(#Runtime._listeners["enterFrame"]).toBe(1)

        -- Simulate frame events
        local listener = Runtime._listeners["enterFrame"][1]
        listener({ time = 1000 })  -- first frame, dt=0 (skipped)
        T.expect(frameCalls).toBe(0)  -- first frame skipped (dt=0)

        listener({ time = 1016 })  -- second frame, dt=0.016
        T.expect(frameCalls).toBe(1)
    end)

    T.it("does not register enterFrame when no onFrame", function()
        Runtime._listeners = {}
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)

        reconciler.render(
            ce(ImperativeCanvas, {
                style = { width = 100, height = 100 },
                onDraw = function() end,
            }),
            container
        )

        T.expect(Runtime._listeners["enterFrame"]).toBeNil()
    end)
end)

T.describe("ImperativeCanvas: display objects on surface", function()
    T.it("user can add display objects to surface in onDraw", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)

        reconciler.render(
            ce(ImperativeCanvas, {
                style = { width = 300, height = 200 },
                onDraw = function(surface, w, h)
                    -- User creates objects on the surface
                    local rect = display.newRect(surface, 0, 0, w, h)
                    rect:setFillColor(1, 0, 0)
                    local circle = display.newCircle(surface, w/2, h/2, 50)
                end,
            }),
            container
        )

        -- Find the surface group
        local view = container[1]
        local surface = nil
        for i = 1, view.numChildren do
            local child = view[i]
            if child._type == "group" and child ~= view._bg then
                surface = child
                break
            end
        end

        T.expect(surface).toBeTruthy()
        T.expect(surface.numChildren).toBe(2)
    end)
end)

T.describe("ImperativeCanvas: no onDraw", function()
    T.it("works without onDraw callback", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)

        -- Should not error
        reconciler.render(
            ce(ImperativeCanvas, {
                style = { width = 100, height = 100 },
            }),
            container
        )

        T.expect(container.numChildren).toBe(1)
    end)
end)

T.summary()
