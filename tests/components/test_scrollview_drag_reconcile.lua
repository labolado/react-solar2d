-- tests/components/test_scrollview_drag_reconcile.lua
-- Regression test for the drag-child reconciliation race in ScrollViewFactory.
--
-- Bug: ScrollView caches the drag target (e.g. a Slider's touch overlay) at the
-- "began" phase. If React reconciles the slider sub-tree between "began" and
-- "moved" — for example because the consumer called setState from onValueChange —
-- the cached View instance is destroyed and a fresh one mounts in its place
-- with the same _onDragHandler shape. The cached reference is now dead
-- (contentBounds == nil), so subsequent "moved"/"ended" events silently no-op
-- and the slider freezes mid-drag.
--
-- Fix: re-validate activeDragChild on each "moved"/"ended" and re-lookup using
-- the original began position when stale.

package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay
display.contentWidth = 1536
display.contentHeight = 2048
-- ScrollViewFactory.takeFocus calls display.getCurrentStage():setFocus(); the
-- mock only exports currentStage, so add a getter shim for the test environment.
display.getCurrentStage = function() return mockDisplay.currentStage end

native = { systemFont = "systemFont", systemFontBold = "systemFontBold" }
timer = { performWithDelay = function() return {} end, cancel = function() end }

local HostConfig = require("renderer.HostConfig")

-- Build a fake "drag overlay" child that mimics what Slider mounts. The child
-- must expose contentBounds (so findDragChild picks it up) and _onDragHandler
-- (so the ScrollView forwards events to it). dragLog captures every call so the
-- test can assert that handlers fire after the swap.
local function makeDragOverlay(xMin, yMin, xMax, yMax, dragLog, tag)
    local overlay = HostConfig.createInstance("View", {
        style = { width = xMax - xMin, height = yMax - yMin },
    })
    overlay.contentBounds = { xMin = xMin, yMin = yMin, xMax = xMax, yMax = yMax }
    overlay._tag = tag
    overlay._onDragHandler = function(event)
        -- Mimic real Slider behaviour: bail if our backing bounds were torn
        -- down (this is exactly the silent freeze path we are testing for).
        if not overlay.contentBounds then return end
        table.insert(dragLog, { tag = tag, phase = event.phase, x = event.x, y = event.y })
    end
    return overlay
end

T.describe("ScrollView: drag child reconciliation race", function()
    T.it("re-lookups drag child when cached instance is destroyed mid-gesture", function()
        local scrollView = HostConfig.createInstance("ScrollView", {
            style = { width = 300, height = 400 },
        })
        scrollView._contentH = 400

        local dragLog = {}
        local originalOverlay = makeDragOverlay(50, 50, 250, 100, dragLog, "original")
        HostConfig.appendChild(scrollView, originalOverlay)

        local touchOverlay = scrollView._touchOverlay
        local touchListener = touchOverlay._listeners["touch"][1]

        -- began: cache the original overlay as activeDragChild
        touchListener({ phase = "began", x = 150, y = 75, id = "finger1", target = touchOverlay })
        T.expect(#dragLog).toBe(1)
        T.expect(dragLog[1].tag).toBe("original")
        T.expect(dragLog[1].phase).toBe("began")

        -- Simulate React reconciliation: original overlay's bounds vanish
        -- (instance dead) and a fresh overlay takes its place in the tree.
        originalOverlay.contentBounds = nil
        HostConfig.removeChild(scrollView, originalOverlay)
        local newOverlay = makeDragOverlay(50, 50, 250, 100, dragLog, "replacement")
        HostConfig.appendChild(scrollView, newOverlay)

        -- moved: BEFORE the fix this silently no-ops because activeDragChild
        -- points at the dead instance. AFTER the fix it re-lookups using the
        -- began position and finds the replacement.
        touchListener({ phase = "moved", x = 180, y = 75, id = "finger1", target = touchOverlay })

        T.expect(#dragLog).toBe(2)
        T.expect(dragLog[2].tag).toBe("replacement")
        T.expect(dragLog[2].phase).toBe("moved")
        T.expect(dragLog[2].x).toBe(180)

        -- ended: should also reach the replacement instance.
        touchListener({ phase = "ended", x = 200, y = 75, id = "finger1", target = touchOverlay })
        T.expect(#dragLog).toBe(3)
        T.expect(dragLog[3].tag).toBe("replacement")
        T.expect(dragLog[3].phase).toBe("ended")
    end)

    T.it("falls through silently when re-lookup also fails", function()
        local scrollView = HostConfig.createInstance("ScrollView", {
            style = { width = 300, height = 400 },
        })
        scrollView._contentH = 400

        local dragLog = {}
        local overlay = makeDragOverlay(50, 50, 250, 100, dragLog, "only")
        HostConfig.appendChild(scrollView, overlay)

        local touchOverlay = scrollView._touchOverlay
        local touchListener = touchOverlay._listeners["touch"][1]

        touchListener({ phase = "began", x = 150, y = 75, id = "finger1", target = touchOverlay })
        T.expect(#dragLog).toBe(1)

        -- Tear the overlay out entirely — no replacement.
        overlay.contentBounds = nil
        HostConfig.removeChild(scrollView, overlay)

        -- moved must NOT throw, and must NOT call the dead handler.
        local ok = pcall(function()
            touchListener({ phase = "moved", x = 180, y = 75, id = "finger1", target = touchOverlay })
        end)
        T.expect(ok).toBe(true)
        T.expect(#dragLog).toBe(1) -- no extra entry

        -- ended must also be safe.
        ok = pcall(function()
            touchListener({ phase = "ended", x = 200, y = 75, id = "finger1", target = touchOverlay })
        end)
        T.expect(ok).toBe(true)
        T.expect(#dragLog).toBe(1)
    end)

    T.it("happy path still forwards every phase to a stable drag child", function()
        local scrollView = HostConfig.createInstance("ScrollView", {
            style = { width = 300, height = 400 },
        })
        scrollView._contentH = 400

        local dragLog = {}
        local overlay = makeDragOverlay(50, 50, 250, 100, dragLog, "stable")
        HostConfig.appendChild(scrollView, overlay)

        local touchOverlay = scrollView._touchOverlay
        local touchListener = touchOverlay._listeners["touch"][1]

        touchListener({ phase = "began", x = 150, y = 75, id = "f", target = touchOverlay })
        touchListener({ phase = "moved", x = 160, y = 75, id = "f", target = touchOverlay })
        touchListener({ phase = "moved", x = 170, y = 75, id = "f", target = touchOverlay })
        touchListener({ phase = "ended", x = 180, y = 75, id = "f", target = touchOverlay })

        T.expect(#dragLog).toBe(4)
        T.expect(dragLog[1].phase).toBe("began")
        T.expect(dragLog[2].phase).toBe("moved")
        T.expect(dragLog[3].phase).toBe("moved")
        T.expect(dragLog[4].phase).toBe("ended")
    end)
end)

T.summary()
