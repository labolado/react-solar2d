-- tests/solar2d/test_all.lua
-- All unit/integration tests (visual, on-screen)

local path = system.pathForFile("main.lua"):gsub("tests/solar2d/main.lua$", "")
package.path = path .. "?.lua;" .. path .. "?/init.lua;" .. package.path

local React = require("react")
local Reconciler = require("react.Reconciler")
local HostConfig = require("renderer.HostConfig")
local ce = React.createElement

local W = display.contentWidth
local H = display.contentHeight

-- ============================================================
-- Test framework with on-screen display
-- ============================================================
local passed, failed = 0, 0
local logGroup = display.newGroup()
local logY = 10

local function log(text, color)
    color = color or {1, 1, 1}
    print(text)
    local t = display.newText({
        parent = logGroup,
        text = text,
        x = 10, y = logY,
        font = native.systemFontBold,
        fontSize = 11,
        align = "left",
    })
    t.anchorX, t.anchorY = 0, 0
    t:setFillColor(color[1], color[2], color[3])
    logY = logY + 14
end

local function PASS(name)
    passed = passed + 1
    log("[PASS] " .. name, {0.2, 0.9, 0.3})
end
local function FAIL(name, reason)
    failed = failed + 1
    log("[FAIL] " .. name .. " — " .. tostring(reason), {1, 0.2, 0.2})
end
local function assert_eq(name, actual, expected)
    if actual == expected then PASS(name)
    else FAIL(name, "expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end
local function assert_true(name, val)
    if val then PASS(name) else FAIL(name, "expected truthy, got " .. tostring(val)) end
end
local function assert_near(name, actual, expected, tol)
    tol = tol or 1
    if math.abs(actual - expected) <= tol then PASS(name)
    else FAIL(name, "expected ~" .. expected .. ", got " .. actual) end
end

local function newTestEnv()
    local container = display.newGroup()
    local rec = Reconciler.create(HostConfig)
    return container, rec
end

local function findTextObj(grp)
    if not grp or not grp.numChildren then return nil end
    for i = 1, grp.numChildren do
        local child = grp[i]
        if child and child.text then return child end
        local found = findTextObj(child)
        if found then return found end
    end
    return nil
end

-- ============================================================
-- Test suites
-- ============================================================
local suites = {}

suites[#suites + 1] = { name = "display_basics", fn = function()
    log("\n--- Display Object Basics ---", {1, 0.8, 0.2})
    local g = display.newGroup()
    assert_true("newGroup", g ~= nil)
    local r = display.newRect(g, 50, 50, 100, 50)
    r.anchorX, r.anchorY = 0, 0
    r:setFillColor(1, 0, 0)
    assert_eq("rect.width", r.width, 100)
    local rr = display.newRoundedRect(g, 50, 120, 80, 80, 10)
    rr.anchorX, rr.anchorY = 0, 0
    rr:setFillColor(0, 0.7, 0)
    assert_true("roundedRect", rr ~= nil)
    local c = display.newCircle(g, 90, 240, 30)
    c:setFillColor(0, 0.4, 1)
    assert_near("circle.width", c.width, 60)
    return g
end}

suites[#suites + 1] = { name = "react_render", fn = function()
    log("\n--- React Render ---", {1, 0.8, 0.2})
    local container, rec = newTestEnv()
    rec.render(ce("View", { style = { width = 200, height = 80, backgroundColor = "#FF6600", borderRadius = 12 } },
        ce("Text", { children = "Hello from React!", style = { color = "#FFFFFF", fontSize = 16 } })
    ), container)
    assert_true("has children", container.numChildren > 0)
    local t = findTextObj(container)
    assert_true("text found", t ~= nil)
    if t then assert_eq("text content", t.text, "Hello from React!") end
    return container
end}

suites[#suites + 1] = { name = "use_state", fn = function()
    log("\n--- useState ---", {1, 0.8, 0.2})
    local container, rec = newTestEnv()
    local setCount
    local function Counter()
        local count, set = React.useState(0)
        setCount = set
        return ce("View", { style = { width = 250, height = 60, backgroundColor = "#2979FF", borderRadius = 8 } },
            ce("Text", { children = "Count: " .. tostring(count), style = { color = "#FFF", fontSize = 20 } })
        )
    end
    rec.render(ce(Counter), container)
    assert_eq("initial", findTextObj(container).text, "Count: 0")
    setCount(42); rec.flushUpdates()
    assert_eq("updated", findTextObj(container).text, "Count: 42")
    setCount(nil); rec.flushUpdates()
    assert_eq("nil", findTextObj(container).text, "Count: nil")
    setCount(99); rec.flushUpdates()
    assert_eq("recover", findTextObj(container).text, "Count: 99")
    return container
end}

suites[#suites + 1] = { name = "scroll_drag", fn = function()
    log("\n--- ScrollView Drag ---", {1, 0.8, 0.2})
    local container, rec = newTestEnv()
    rec.render(ce("ScrollView", { style = { width = W * 0.7, height = 120 } },
        ce("View", { style = { width = W * 0.7, height = 60, backgroundColor = "#E74C3C" } }),
        ce("View", { style = { width = W * 0.7, height = 60, backgroundColor = "#F39C12" } }),
        ce("View", { style = { width = W * 0.7, height = 60, backgroundColor = "#2ECC71" } }),
        ce("View", { style = { width = W * 0.7, height = 60, backgroundColor = "#3498DB" } })
    ), container)
    local sv = container[1]
    local overlay = sv[sv.numChildren]
    for i = 1, sv._contentGroup.numChildren do
        local child = sv._contentGroup[i]
        if child then child.y = (i - 1) * 60 end
    end
    assert_eq("starts 0", sv._scrollY, 0)
    overlay:dispatchEvent({ name = "touch", phase = "began", x = 100, y = 100, xStart = 100, yStart = 100, id = "d1" })
    overlay:dispatchEvent({ name = "touch", phase = "moved", x = 100, y = 40, xStart = 100, yStart = 100, id = "d1" })
    assert_true("scrolled", sv._scrollY < 0)
    overlay:dispatchEvent({ name = "touch", phase = "ended", x = 100, y = 40, xStart = 100, yStart = 100, id = "d1" })
    return container
end}

suites[#suites + 1] = { name = "scroll_rubber", fn = function()
    log("\n--- Rubber-band ---", {1, 0.8, 0.2})
    local container, rec = newTestEnv()
    rec.render(ce("ScrollView", { style = { width = W * 0.7, height = 150 } },
        ce("View", { style = { width = W * 0.7, height = 50, backgroundColor = "#9B59B6" } })
    ), container)
    local sv = container[1]
    local overlay = sv[sv.numChildren]
    overlay:dispatchEvent({ name = "touch", phase = "began", x = 100, y = 50, xStart = 100, yStart = 50, id = "d2" })
    overlay:dispatchEvent({ name = "touch", phase = "moved", x = 100, y = 150, xStart = 100, yStart = 50, id = "d2" })
    assert_near("dampened ~40", sv._scrollY, 40, 5)
    overlay:dispatchEvent({ name = "touch", phase = "ended", x = 100, y = 150, xStart = 100, yStart = 50, id = "d2" })
    assert_eq("snap back", sv._scrollY, 0)
    return container
end}

suites[#suites + 1] = { name = "scroll_mouse", fn = function()
    log("\n--- Mouse Wheel ---", {1, 0.8, 0.2})
    local container, rec = newTestEnv()
    rec.render(ce("ScrollView", { style = { width = W * 0.7, height = 100 } },
        ce("View", { style = { width = W * 0.7, height = 60, backgroundColor = "#1ABC9C" } }),
        ce("View", { style = { width = W * 0.7, height = 60, backgroundColor = "#27AE60" } }),
        ce("View", { style = { width = W * 0.7, height = 60, backgroundColor = "#2980B9" } })
    ), container)
    local sv = container[1]
    local overlay = sv[sv.numChildren]
    for i = 1, sv._contentGroup.numChildren do
        local child = sv._contentGroup[i]
        if child then child.y = (i - 1) * 60 end
    end
    overlay:dispatchEvent({ name = "mouse", type = "scroll", scrollX = 0, scrollY = -3, x = 100, y = 50 })
    local y1 = sv._scrollY
    assert_true("moved", y1 ~= 0)
    overlay:dispatchEvent({ name = "mouse", type = "scroll", scrollX = 0, scrollY = -3, x = 100, y = 50 })
    assert_true("accumulated", math.abs(sv._scrollY) > math.abs(y1))
    return container
end}

suites[#suites + 1] = { name = "cond_render", fn = function()
    log("\n--- Conditional Render ---", {1, 0.8, 0.2})
    local container, rec = newTestEnv()
    local setShow
    local function Toggle()
        local show, set = React.useState(true)
        setShow = set
        return ce("View", { style = { width = 200, height = 50, backgroundColor = show and "#2ECC71" or "#E74C3C", borderRadius = 8 } },
            ce("Text", { children = show and "VISIBLE" or "HIDDEN", style = { color = "#FFF", fontSize = 16 } })
        )
    end
    rec.render(ce(Toggle), container)
    assert_eq("initial", findTextObj(container).text, "VISIBLE")
    setShow(false); rec.flushUpdates()
    assert_eq("toggled", findTextObj(container).text, "HIDDEN")
    setShow(true); rec.flushUpdates()
    assert_eq("back", findTextObj(container).text, "VISIBLE")
    return container
end}

-- ============================================================
-- Run all suites with visual delay
-- ============================================================
local dbg = display.newRect(display.getCurrentStage(), 0, 0, W, H)
dbg.anchorX, dbg.anchorY = 0, 0
dbg:setFillColor(0.08, 0.08, 0.12)

log("========== Solar2D Unit Tests ==========", {1, 0.9, 0.3})

local sceneGroup = display.newGroup()
sceneGroup.x = W * 0.55

local divider = display.newRect(display.getCurrentStage(), W * 0.53, 0, 1, H)
divider.anchorX, divider.anchorY = 0, 0
divider:setFillColor(0.2, 0.2, 0.3)

local idx = 0
local cleanups = {}

local function runNext()
    idx = idx + 1
    if idx > #suites then
        log("")
        log("==========================================", {1, 0.9, 0.3})
        log(string.format("  Total: %d passed, %d failed (%d suites)", passed, failed, #suites),
            failed == 0 and {0.2, 1, 0.4} or {1, 0.3, 0.3})
        log("==========================================", {1, 0.9, 0.3})
        logGroup:toFront()
        timer.performWithDelay(3000, function()
            os.exit(failed == 0 and 0 or 1)
        end)
        return
    end
    for _, c in ipairs(cleanups) do
        if c and c.removeSelf then pcall(function() c:removeSelf() end) end
    end
    cleanups = {}
    local ok, result = pcall(suites[idx].fn)
    if not ok then
        FAIL(suites[idx].name .. " (ERROR)", tostring(result))
    elseif result and result.numChildren then
        result.y = 30
        sceneGroup:insert(result)
        cleanups[#cleanups + 1] = result
    end
    logGroup:toFront()
    timer.performWithDelay(600, runNext)
end

runNext()
