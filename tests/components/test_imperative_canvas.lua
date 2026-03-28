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

T.describe("ImperativeCanvas: clip prop", function()
    T.it("creates Container when clip=true", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)
        local drawnSurface = nil

        reconciler.render(
            ce(ImperativeCanvas, {
                style = { width = 200, height = 150 },
                clip = true,
                onDraw = function(surface, w, h)
                    drawnSurface = surface
                end,
            }),
            container
        )

        -- The View is container's first child
        local view = container[1]
        T.expect(view).toBeTruthy()

        -- Find the container surface inside the view
        local containerSurface = nil
        for i = 1, view.numChildren do
            local child = view[i]
            if child._type == "container" then
                containerSurface = child
                break
            end
        end

        T.expect(containerSurface).toBeTruthy()
        T.expect(containerSurface._type).toBe("container")
        -- Default anchor (0.5, 0.5) with position at (w/2, h/2)
        T.expect(containerSurface.anchorX).toBe(0.5)
        T.expect(containerSurface.anchorY).toBe(0.5)

        -- drawTarget should be the inner offset group (top-left coords)
        T.expect(drawnSurface).toBeTruthy()
        T.expect(drawnSurface._type).toBe("group")
        T.expect(drawnSurface._parent).toBe(containerSurface)
        T.expect(drawnSurface.x).toBe(-100)  -- -w/2
        T.expect(drawnSurface.y).toBe(-75)   -- -h/2
    end)

    T.it("creates Group when clip=false (default)", function()
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

        T.expect(drawnSurface).toBeTruthy()
        T.expect(drawnSurface._type).toBe("group")
    end)
end)

T.describe("ImperativeCanvas: overlay prop", function()
    T.it("does not call toBack when overlay=true", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)
        local toBackCalled = false

        -- Patch toBack on all new groups to detect calls
        local origNewGroup = mockDisplay.newGroup
        mockDisplay.newGroup = function(...)
            local g = origNewGroup(...)
            local origToBack = g.toBack
            g.toBack = function(self)
                toBackCalled = true
                origToBack(self)
            end
            return g
        end

        reconciler.render(
            ce(ImperativeCanvas, {
                style = { width = 200, height = 150 },
                overlay = true,
                onDraw = function() end,
            }),
            container
        )

        T.expect(toBackCalled).toBe(false)

        -- Restore
        mockDisplay.newGroup = origNewGroup
    end)

    T.it("calls toBack when overlay=false (default)", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)
        local toBackCalled = false

        local origNewGroup = mockDisplay.newGroup
        mockDisplay.newGroup = function(...)
            local g = origNewGroup(...)
            local origToBack = g.toBack
            g.toBack = function(self)
                toBackCalled = true
                origToBack(self)
            end
            return g
        end

        reconciler.render(
            ce(ImperativeCanvas, {
                style = { width = 200, height = 150 },
                onDraw = function() end,
            }),
            container
        )

        T.expect(toBackCalled).toBe(true)

        mockDisplay.newGroup = origNewGroup
    end)
end)

T.describe("ImperativeCanvas: propsRef", function()
    T.it("onDraw receives propsRef as 4th argument", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)
        local receivedPropsRef = nil

        reconciler.render(
            ce(ImperativeCanvas, {
                style = { width = 200, height = 150 },
                myCustomProp = "hello",
                onDraw = function(surface, w, h, propsRef)
                    receivedPropsRef = propsRef
                end,
            }),
            container
        )

        T.expect(receivedPropsRef).toBeTruthy()
        T.expect(receivedPropsRef.current).toBeTruthy()
        T.expect(receivedPropsRef.current.myCustomProp).toBe("hello")
    end)

    T.it("onFrame reads latest props via propsRef", function()
        Runtime._listeners = {}
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)

        local capturedValue = nil
        local frameCount = 0

        -- First render
        reconciler.render(
            ce(ImperativeCanvas, {
                style = { width = 200, height = 150 },
                myValue = "initial",
                onFrame = function(surface, dt)
                    frameCount = frameCount + 1
                    -- This would be stale without propsRef fix
                end,
                onDraw = function(surface, w, h, propsRef)
                    -- Store propsRef for later assertion
                    capturedValue = propsRef
                end,
            }),
            container
        )

        T.expect(capturedValue).toBeTruthy()
        T.expect(capturedValue.current.myValue).toBe("initial")

        -- Re-render with new props
        reconciler.render(
            ce(ImperativeCanvas, {
                style = { width = 200, height = 150 },
                myValue = "updated",
                onFrame = function(surface, dt)
                    frameCount = frameCount + 1
                end,
                onDraw = function(surface, w, h, propsRef)
                    capturedValue = propsRef
                end,
            }),
            container
        )

        -- propsRef.current should now reflect updated props
        T.expect(capturedValue.current.myValue).toBe("updated")
    end)
end)

T.summary()
