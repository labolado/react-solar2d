-- tests/renderer/test_hostconfig_touch_focus.lua
-- Regression tests for the onTouchMove / onLongPress focus-pin race in
-- renderer/HostConfig.lua's wireEvents.
--
-- Bug (root cause): Solar2D's addEventListener("touch", ...) does NOT
-- automatically lock the finger to the original target. Each subsequent touch
-- frame (moved/ended) re-runs hit-test. If React reconciles the underlying
-- display object mid-gesture (e.g. onTouchMove triggers setState which
-- rebuilds the View's _bg rect, common with PanGestureHandler), the new hit
-- can land on a sibling object and the original listener silently freezes —
-- same shape as the ScrollView drag-reconcile race fixed in commit 2f9edf3.
--
-- Fix: pin stage focus at "began" (only when the consumer actually declared
-- onTouchMove, to preserve the "finger drifts off → auto-release" semantics
-- for tap-like users) and release it at "ended"/"cancelled". onLongPress is
-- pinned unconditionally so a mid-press reconcile cannot leak the 500ms
-- timer that would otherwise fire after the user already lifted.

package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay
display.contentWidth = 1536
display.contentHeight = 2048

-- Override setFocus on the shared stage mock so we can inspect the calls.
local focusLog = {}
mockDisplay.currentStage.setFocus = function(self, obj, id)
    table.insert(focusLog, { obj = obj, id = id })
end
local function resetFocusLog() focusLog = {} end

native = { systemFont = "systemFont", systemFontBold = "systemFontBold" }

-- Trackable timer mock: every performWithDelay returns a handle that we can
-- inspect (cancelled / fired). The 500ms long-press timer never auto-fires in
-- tests — we just assert that cancel was called.
local timerHandles = {}
timer = {
    performWithDelay = function(_, fn)
        local h = { _cancelled = false, _fn = fn }
        table.insert(timerHandles, h)
        return h
    end,
    cancel = function(h)
        if h then h._cancelled = true end
    end,
}
local function resetTimers() timerHandles = {} end

local HostConfig = require("renderer.HostConfig")

local function touchListenerOf(instance)
    return instance._listeners["touch"][1]
end

T.describe("HostConfig: onTouchMove pins stage focus across phases", function()
    T.it("began claims focus, moved does not re-claim, ended releases", function()
        resetFocusLog()
        local moves = {}
        local instance = HostConfig.createInstance("View", {
            style = { width = 200, height = 200 },
            onTouchStart = function(e) end,
            onTouchMove = function(e) table.insert(moves, e.x) end,
            onTouchEnd = function(e) end,
        })

        local listener = touchListenerOf(instance)
        listener({ phase = "began", x = 10, y = 10, id = "f1", target = instance })
        T.expect(#focusLog).toBe(1)
        T.expect(focusLog[1].obj).toBe(instance)
        T.expect(focusLog[1].id).toBe("f1")

        listener({ phase = "moved", x = 20, y = 10, id = "f1", target = instance })
        listener({ phase = "moved", x = 30, y = 10, id = "f1", target = instance })
        T.expect(#focusLog).toBe(1)  -- moved must not re-claim
        T.expect(#moves).toBe(2)

        listener({ phase = "ended", x = 40, y = 10, id = "f1", target = instance })
        T.expect(#focusLog).toBe(2)
        T.expect(focusLog[2].obj).toBe(nil)
        T.expect(focusLog[2].id).toBe("f1")
    end)

    T.it("cancelled also releases focus", function()
        resetFocusLog()
        local instance = HostConfig.createInstance("View", {
            style = { width = 200, height = 200 },
            onTouchMove = function() end,
        })
        local listener = touchListenerOf(instance)
        listener({ phase = "began", x = 10, y = 10, id = "fc", target = instance })
        listener({ phase = "cancelled", x = 10, y = 10, id = "fc", target = instance })
        T.expect(#focusLog).toBe(2)
        T.expect(focusLog[2].obj).toBe(nil)
        T.expect(focusLog[2].id).toBe("fc")
    end)

    T.it("second finger does not steal focus while one is active", function()
        resetFocusLog()
        local moves = {}
        local instance = HostConfig.createInstance("View", {
            style = { width = 200, height = 200 },
            onTouchMove = function(e) table.insert(moves, e.id) end,
        })
        local listener = touchListenerOf(instance)

        listener({ phase = "began", x = 10, y = 10, id = "fA", target = instance })
        -- Second finger arrives mid-gesture — must be ignored entirely so it
        -- does not call setFocus with a wrong id (which would replace fA's
        -- focus and break the original drag).
        listener({ phase = "began", x = 20, y = 10, id = "fB", target = instance })
        T.expect(#focusLog).toBe(1)
        T.expect(focusLog[1].id).toBe("fA")

        -- moved frames carrying fB's id are dropped: they belong to a finger
        -- the listener never claimed.
        listener({ phase = "moved", x = 25, y = 10, id = "fB", target = instance })
        T.expect(#moves).toBe(0)

        -- fA's moved frame goes through.
        listener({ phase = "moved", x = 15, y = 10, id = "fA", target = instance })
        T.expect(#moves).toBe(1)
        T.expect(moves[1]).toBe("fA")

        -- A stray ended for fB must NOT release fA's focus.
        listener({ phase = "ended", x = 25, y = 10, id = "fB", target = instance })
        T.expect(#focusLog).toBe(1)

        -- fA's ended releases.
        listener({ phase = "ended", x = 30, y = 10, id = "fA", target = instance })
        T.expect(#focusLog).toBe(2)
        T.expect(focusLog[2].obj).toBe(nil)
        T.expect(focusLog[2].id).toBe("fA")
    end)

    T.it("does NOT pin focus when only onTouchStart / onTouchEnd are set", function()
        -- Tap-like consumers that never asked for moved frames keep the old
        -- "finger drifts off element → auto-release" semantics. Adding focus
        -- here would silently change behaviour for them.
        resetFocusLog()
        local started, ended = 0, 0
        local instance = HostConfig.createInstance("View", {
            style = { width = 200, height = 200 },
            onTouchStart = function() started = started + 1 end,
            onTouchEnd   = function() ended = ended + 1 end,
        })
        local listener = touchListenerOf(instance)
        listener({ phase = "began", x = 10, y = 10, id = "tap1", target = instance })
        listener({ phase = "ended", x = 10, y = 10, id = "tap1", target = instance })
        T.expect(#focusLog).toBe(0)
        T.expect(started).toBe(1)
        T.expect(ended).toBe(1)
    end)
end)

T.describe("HostConfig: onLongPress pins focus and cancels timer correctly", function()
    T.it("began claims focus + arms timer, ended releases focus + cancels timer", function()
        resetFocusLog()
        resetTimers()
        local fired = 0
        local instance = HostConfig.createInstance("View", {
            style = { width = 100, height = 100 },
            onLongPress = function() fired = fired + 1 end,
        })
        local listener = touchListenerOf(instance)

        listener({ phase = "began", x = 5, y = 5, id = "lp1", target = instance })
        T.expect(#focusLog).toBe(1)
        T.expect(focusLog[1].obj).toBe(instance)
        T.expect(focusLog[1].id).toBe("lp1")
        T.expect(#timerHandles).toBe(1)
        T.expect(timerHandles[1]._cancelled).toBe(false)

        listener({ phase = "ended", x = 5, y = 5, id = "lp1", target = instance })
        T.expect(#focusLog).toBe(2)
        T.expect(focusLog[2].obj).toBe(nil)
        T.expect(focusLog[2].id).toBe("lp1")
        T.expect(timerHandles[1]._cancelled).toBe(true)
        T.expect(fired).toBe(0)
    end)

    T.it("cancelled phase also releases focus + cancels timer", function()
        resetFocusLog()
        resetTimers()
        local instance = HostConfig.createInstance("View", {
            style = { width = 100, height = 100 },
            onLongPress = function() end,
        })
        local listener = touchListenerOf(instance)
        listener({ phase = "began", x = 5, y = 5, id = "lp2", target = instance })
        listener({ phase = "cancelled", x = 5, y = 5, id = "lp2", target = instance })
        T.expect(#focusLog).toBe(2)
        T.expect(focusLog[2].obj).toBe(nil)
        T.expect(focusLog[2].id).toBe("lp2")
        T.expect(timerHandles[1]._cancelled).toBe(true)
    end)

    T.it("stray ended for a different finger must not release focus or cancel timer", function()
        resetFocusLog()
        resetTimers()
        local instance = HostConfig.createInstance("View", {
            style = { width = 100, height = 100 },
            onLongPress = function() end,
        })
        local listener = touchListenerOf(instance)

        listener({ phase = "began", x = 5, y = 5, id = "primary", target = instance })
        -- Second finger lands while primary is armed — must NOT re-arm a
        -- second timer or re-claim focus, or we'd leak both on release.
        listener({ phase = "began", x = 10, y = 10, id = "extra", target = instance })
        T.expect(#focusLog).toBe(1)
        T.expect(#timerHandles).toBe(1)

        -- Wrong-id ended must not release focus or cancel the primary's timer.
        listener({ phase = "ended", x = 10, y = 10, id = "extra", target = instance })
        T.expect(#focusLog).toBe(1)
        T.expect(timerHandles[1]._cancelled).toBe(false)

        -- Primary's ended releases everything.
        listener({ phase = "ended", x = 5, y = 5, id = "primary", target = instance })
        T.expect(#focusLog).toBe(2)
        T.expect(focusLog[2].obj).toBe(nil)
        T.expect(focusLog[2].id).toBe("primary")
        T.expect(timerHandles[1]._cancelled).toBe(true)
    end)
end)

T.summary()
