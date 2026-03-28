-- tests/components/test_scene_canvas.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay
display.contentWidth = 375
display.contentHeight = 812
native = { systemFont = "systemFont", systemFontBold = "systemFontBold" }
timer = { performWithDelay = function() return {} end, cancel = function() end }

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
local SceneCanvas = require("components.SceneCanvas")
local SceneAdapter = require("components.SceneAdapter")
local ce = React.createElement

T.describe("SceneAdapter: newScene", function()
    T.it("creates a scene with addEventListener and dispatchEvent", function()
        local scene = SceneAdapter.newScene()
        T.expect(scene).toBeTruthy()
        T.expect(type(scene.addEventListener)).toBe("function")
        T.expect(type(scene.dispatchEvent)).toBe("function")
    end)

    T.it("dispatches events to registered table listeners", function()
        local scene = SceneAdapter.newScene()
        local received = nil

        local handler = {}
        function handler:create(event)
            received = event
        end
        scene:addEventListener("create", handler)

        scene:dispatchEvent({ name = "create", view = "test" })
        T.expect(received).toBeTruthy()
        T.expect(received.view).toBe("test")
    end)

    T.it("dispatches events to registered function listeners", function()
        local scene = SceneAdapter.newScene()
        local received = nil

        scene:addEventListener("create", function(event)
            received = event
        end)

        scene:dispatchEvent({ name = "create", view = "test2" })
        T.expect(received).toBeTruthy()
        T.expect(received.view).toBe("test2")
    end)

    T.it("ignores unregistered events", function()
        local scene = SceneAdapter.newScene()
        -- Should not error
        scene:dispatchEvent({ name = "nonexistent" })
    end)
end)

T.describe("SceneCanvas: lifecycle events", function()
    T.it("dispatches create and show events on mount", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)

        local scene = SceneAdapter.newScene()
        local events = {}

        local handler = {}
        function handler:create(event)
            table.insert(events, { name = "create", view = event.view })
        end
        function handler:show(event)
            table.insert(events, { name = "show", phase = event.phase, view = event.view })
        end
        function handler:hide(event)
            table.insert(events, { name = "hide", phase = event.phase })
        end
        function handler:destroy(event)
            table.insert(events, { name = "destroy" })
        end

        scene:addEventListener("create", handler)
        scene:addEventListener("show", handler)
        scene:addEventListener("hide", handler)
        scene:addEventListener("destroy", handler)

        reconciler.render(
            ce(SceneCanvas, {
                style = { width = 300, height = 200 },
                scene = scene,
            }),
            container
        )

        -- Should have received create, show(will), show(did)
        T.expect(#events).toBe(3)
        T.expect(events[1].name).toBe("create")
        T.expect(events[1].view).toBeTruthy()
        T.expect(events[1].view._type).toBe("group")
        T.expect(events[2].name).toBe("show")
        T.expect(events[2].phase).toBe("will")
        T.expect(events[3].name).toBe("show")
        T.expect(events[3].phase).toBe("did")
    end)

    T.it("passes params to scene events", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)

        local scene = SceneAdapter.newScene()
        local receivedParams = nil

        local handler = {}
        function handler:create(event)
            receivedParams = event.params
        end

        scene:addEventListener("create", handler)

        reconciler.render(
            ce(SceneCanvas, {
                style = { width = 300, height = 200 },
                scene = scene,
                params = { level = 5, mode = "easy" },
            }),
            container
        )

        T.expect(receivedParams).toBeTruthy()
        T.expect(receivedParams.level).toBe(5)
        T.expect(receivedParams.mode).toBe("easy")
    end)
end)

T.describe("SceneCanvas: scene creates display objects", function()
    T.it("scene can add objects to the provided view group", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)

        local scene = SceneAdapter.newScene()
        local handler = {}
        function handler:create(event)
            local view = event.view
            display.newRect(view, 0, 0, 100, 100)
            display.newCircle(view, 50, 50, 25)
        end
        scene:addEventListener("create", handler)

        reconciler.render(
            ce(SceneCanvas, {
                style = { width = 300, height = 200 },
                scene = scene,
            }),
            container
        )

        -- Find the surface group inside the View
        local outerView = container[1]
        T.expect(outerView).toBeTruthy()

        -- Look for a group child that has the scene's objects
        local surface = nil
        for i = 1, outerView.numChildren do
            local child = outerView[i]
            if child._type == "group" and child.numChildren == 2 then
                surface = child
                break
            end
        end

        T.expect(surface).toBeTruthy()
        T.expect(surface.numChildren).toBe(2)
    end)
end)

T.describe("SceneCanvas: without scene", function()
    T.it("works when no scene is provided", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(HostConfig)

        -- Should not error
        reconciler.render(
            ce(SceneCanvas, {
                style = { width = 100, height = 100 },
            }),
            container
        )

        T.expect(container.numChildren).toBe(1)
    end)
end)

T.summary()
