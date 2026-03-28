-- tests/components/test_pagelet.lua
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
local ce = React.createElement
local Reconciler = require("react.Reconciler")
local HostConfig = require("renderer.HostConfig")
local Pagelet = require("components.Pagelet")

T.describe("Pagelet", function()
    T.it("is callable as component", function()
        local created = false
        local reconciler = Reconciler.create(HostConfig)
        local container = HostConfig.createInstance("View", {})

        local function App()
            return ce(Pagelet, {
                name = "solo",
                onCreate = function() created = true end,
            },
                ce("Text", {}, "Solo page")
            )
        end

        reconciler.render(ce(App), container)
        reconciler.flushUpdates()
        T.expect(created).toBe(true)
    end)

    T.it("fires onShow with will/did phases on mount", function()
        local phases = {}
        local reconciler = Reconciler.create(HostConfig)
        local container = HostConfig.createInstance("View", {})

        local function App()
            return ce(Pagelet, {
                name = "test",
                onShow = function(e) phases[#phases + 1] = e.phase end,
            },
                ce("Text", {}, "Content")
            )
        end

        reconciler.render(ce(App), container)
        reconciler.flushUpdates()
        T.expect(#phases).toBe(2)
        T.expect(phases[1]).toBe("will")
        T.expect(phases[2]).toBe("did")
    end)

    T.it("passes params in lifecycle events", function()
        local receivedParams = nil
        local reconciler = Reconciler.create(HostConfig)
        local container = HostConfig.createInstance("View", {})

        local function App()
            return ce(Pagelet, {
                name = "test",
                params = { score = 100 },
                onCreate = function(e) receivedParams = e.params end,
            },
                ce("Text", {}, "Content")
            )
        end

        reconciler.render(ce(App), container)
        reconciler.flushUpdates()
        T.expect(receivedParams).toBeTruthy()
        T.expect(receivedParams.score).toBe(100)
    end)
end)

T.describe("Pagelet.Container", function()
    T.it("renders only the active pagelet", function()
        local aShow = 0
        local bShow = 0
        local reconciler = Reconciler.create(HostConfig)
        local container = HostConfig.createInstance("View", {})

        local function App()
            return ce(Pagelet.Container, { current = "page-a" },
                ce(Pagelet, {
                    name = "page-a",
                    onShow = function() aShow = aShow + 1 end,
                },
                    ce("Text", {}, "Page A")
                ),
                ce(Pagelet, {
                    name = "page-b",
                    onShow = function() bShow = bShow + 1 end,
                },
                    ce("Text", {}, "Page B")
                )
            )
        end

        reconciler.render(ce(App), container)
        reconciler.flushUpdates()
        T.expect(aShow > 0).toBe(true)
        T.expect(bShow).toBe(0)
    end)

    T.it("switches pages via current prop", function()
        local bShow = 0
        local reconciler = Reconciler.create(HostConfig)
        local container = HostConfig.createInstance("View", {})

        local currentPage = "page-a"

        local function App()
            return ce(Pagelet.Container, { current = currentPage },
                ce(Pagelet, { name = "page-a" },
                    ce("Text", {}, "A")
                ),
                ce(Pagelet, {
                    name = "page-b",
                    onShow = function() bShow = bShow + 1 end,
                },
                    ce("Text", {}, "B")
                )
            )
        end

        reconciler.render(ce(App), container)
        reconciler.flushUpdates()
        T.expect(bShow).toBe(0)

        -- Switch to page-b
        currentPage = "page-b"
        reconciler.render(ce(App), container)
        reconciler.flushUpdates()

        T.expect(bShow > 0).toBe(true)
    end)

    T.it("renders nothing for unknown page name", function()
        local reconciler = Reconciler.create(HostConfig)
        local container = HostConfig.createInstance("View", {})

        local function App()
            return ce(Pagelet.Container, { current = "nonexistent" },
                ce(Pagelet, { name = "page-a" },
                    ce("Text", {}, "A")
                )
            )
        end

        -- Should not error
        reconciler.render(ce(App), container)
        reconciler.flushUpdates()
    end)
end)
