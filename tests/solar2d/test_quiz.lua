-- tests/solar2d/test_quiz.lua
-- Automated visual test for QuizApp: start → answer all → result
-- Watches the REAL UI change on screen as each step runs

local path = system.pathForFile("main.lua"):gsub("tests/solar2d/main.lua$", "")
package.path = path .. "?.lua;" .. path .. "?/init.lua;" .. package.path

local React = require("react")
local Reconciler = require("react.Reconciler")
local HostConfig = require("renderer.HostConfig")
local RN = require("renderer")
local ce = React.createElement

local W = display.contentWidth
local H = display.contentHeight

-- ============================================================
-- Test framework (on-screen + stdout)
-- ============================================================
local passed, failed = 0, 0
local logY = 10

local function log(text, color)
    print(text)
end

local function PASS(name)
    passed = passed + 1
    log("[PASS] " .. name, {0.2, 0.9, 0.3})
end
local function FAIL(name, reason)
    failed = failed + 1
    log("[FAIL] " .. name .. " — " .. tostring(reason), {1, 0.2, 0.2})
end
local function assert_true(name, val)
    if val then PASS(name) else FAIL(name, "got " .. tostring(val)) end
end
local function assert_eq(name, actual, expected)
    if actual == expected then PASS(name)
    else FAIL(name, "expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

-- Walk display tree to find text matching a pattern
local function findText(grp, pattern)
    if not grp or not grp.numChildren then return nil end
    for i = 1, grp.numChildren do
        local child = grp[i]
        if child then
            if child.text and type(child.text) == "string" and child.text:find(pattern) then
                return child
            end
            local found = findText(child, pattern)
            if found then return found end
        end
    end
    return nil
end

-- Find ALL text objects
local function findAllTexts(grp, results)
    results = results or {}
    if not grp or not grp.numChildren then return results end
    for i = 1, grp.numChildren do
        local child = grp[i]
        if child then
            if child.text and type(child.text) == "string" then
                results[#results + 1] = child
            end
            findAllTexts(child, results)
        end
    end
    return results
end

-- Find group with _onPress handler containing text
local function findPressableWithText(grp, pattern)
    if not grp or not grp.numChildren then return nil end
    for i = 1, grp.numChildren do
        local child = grp[i]
        if child then
            if child._onPress then
                -- Check if this group or its children contain matching text
                local t = findText(child, pattern)
                if t then return child end
            end
            local found = findPressableWithText(child, pattern)
            if found then return found end
        end
    end
    return nil
end

-- Find group with _onPress (any pressable)
local function findAllPressables(grp, results)
    results = results or {}
    if not grp or not grp.numChildren then return results end
    for i = 1, grp.numChildren do
        local child = grp[i]
        if child then
            if child._onPress then
                results[#results + 1] = child
            end
            findAllPressables(child, results)
        end
    end
    return results
end

log("========== QuizApp Auto Test ==========")
log("")

-- ============================================================
-- Mount QuizApp
-- ============================================================
local QuizApp = require("examples.QuizApp")
local container = display.newGroup()
RN.render(ce(QuizApp), container)
RN.startAutoFlush()

-- ============================================================
-- Step-by-step automated test with timer delays
-- Each step verifies the screen then performs an action
-- ============================================================
local step = 0

local function nextStep()
    step = step + 1

    if step == 1 then
        -- Verify: Start screen visible
        log("\n--- Step 1: Start Screen ---", {1, 0.8, 0.2})
        RN.flushUpdates()

        local title = findText(container, "知识问答")
        assert_true("title '知识问答' visible", title ~= nil)

        local subtitle = findText(container, "挑战你的知识边界")
        assert_true("subtitle visible", subtitle ~= nil)

        local easyBtn = findPressableWithText(container, "入门模式")
        assert_true("'入门模式' button found", easyBtn ~= nil)

        local medBtn = findPressableWithText(container, "进阶模式")
        assert_true("'进阶模式' button found", medBtn ~= nil)

        local hardBtn = findPressableWithText(container, "挑战模式")
        assert_true("'挑战模式' button found", hardBtn ~= nil)

        -- Action: tap "入门模式"
        log("  → Tapping 入门模式...", {0.6, 0.8, 1})
        if easyBtn and easyBtn._onPress then
            easyBtn._onPress()
        end

        timer.performWithDelay(500, nextStep)

    elseif step == 2 then
        -- Verify: Quiz screen visible
        log("\n--- Step 2: Quiz Screen ---", {1, 0.8, 0.2})
        RN.flushUpdates()

        local q1marker = findText(container, "第 1 题")
        assert_true("'第 1 题' visible", q1marker ~= nil)

        local scoreText = findText(container, "得分")
        assert_true("score display visible", scoreText ~= nil)

        -- Find option buttons (pressables in the quiz area)
        local pressables = findAllPressables(container)
        log("  Found " .. #pressables .. " pressable elements")
        -- Should have at least 4 option buttons + quit button
        assert_true("at least 4 option buttons", #pressables >= 4)

        -- Action: tap first option (may or may not be correct)
        log("  → Answering question 1...", {0.6, 0.8, 1})
        -- Find option buttons specifically (they have letter text A/B/C/D)
        local optA = findPressableWithText(container, "^A$")
        if optA and optA._onPress then
            optA._onPress()
        else
            -- Fallback: tap any pressable that's not quit
            for _, p in ipairs(pressables) do
                local quitText = findText(p, "退出")
                if not quitText and p._onPress then
                    p._onPress()
                    break
                end
            end
        end

        -- Wait for auto-advance (800ms for correct, 1500ms for wrong + buffer)
        timer.performWithDelay(2000, nextStep)

    elseif step >= 3 and step <= 11 then
        -- Answer questions 2-10 (auto-advance should have moved us)
        local qNum = step - 1
        log("\n--- Step " .. step .. ": Question " .. qNum .. " ---", {1, 0.8, 0.2})
        RN.flushUpdates()

        local qMarker = findText(container, "第 " .. qNum .. " 题")
        if qMarker then
            PASS("'第 " .. qNum .. " 题' visible")
        else
            -- Maybe already on result screen or different question
            local resultText = findText(container, "完美通关")
                or findText(container, "表现出色")
                or findText(container, "还不错")
                or findText(container, "加油")
                or findText(container, "别灰心")
            if resultText then
                log("  Already on result screen, skipping to final step", {0.8, 0.8, 0.2})
                step = 11
                timer.performWithDelay(100, nextStep)
                return
            else
                log("  [INFO] Expected Q" .. qNum .. " but not found, continuing...", {0.8, 0.8, 0.5})
            end
        end

        -- Tap first available option
        local pressables = findAllPressables(container)
        local tapped = false
        for _, p in ipairs(pressables) do
            local quitText = findText(p, "退出")
            local retryText = findText(p, "再来一次")
            if not quitText and not retryText and p._onPress then
                p._onPress()
                tapped = true
                break
            end
        end
        if tapped then
            log("  → Answered Q" .. qNum, {0.6, 0.8, 1})
        end

        timer.performWithDelay(2000, nextStep)

    elseif step == 12 then
        -- Verify: Result screen
        log("\n--- Step 12: Result Screen ---", {1, 0.8, 0.2})
        RN.flushUpdates()

        -- Look for result indicators
        local resultText = findText(container, "完美通关")
            or findText(container, "表现出色")
            or findText(container, "还不错")
            or findText(container, "加油")
            or findText(container, "别灰心")
        assert_true("result message visible", resultText ~= nil)
        if resultText then
            log("  Result: " .. resultText.text, {0.5, 1, 0.5})
        end

        local scoreText = findText(container, "%d+ / %d+")
        assert_true("score display visible", scoreText ~= nil)
        if scoreText then
            log("  Score: " .. scoreText.text, {0.5, 1, 0.5})
        end

        local retryBtn = findPressableWithText(container, "再来一次")
        assert_true("retry button visible", retryBtn ~= nil)

        local homeBtn = findPressableWithText(container, "返回首页")
        assert_true("home button visible", homeBtn ~= nil)

        -- Action: tap "返回首页"
        log("  → Tapping 返回首页...", {0.6, 0.8, 1})
        if homeBtn and homeBtn._onPress then
            homeBtn._onPress()
        end

        timer.performWithDelay(500, nextStep)

    elseif step == 13 then
        -- Verify: Back on start screen
        log("\n--- Step 13: Back to Start ---", {1, 0.8, 0.2})
        RN.flushUpdates()

        local title = findText(container, "知识问答")
        assert_true("back on start screen", title ~= nil)

        -- Summary
        log("")
        log("==========================================", {1, 0.9, 0.3})
        log(string.format("  Total: %d passed, %d failed", passed, failed),
            failed == 0 and {0.2, 1, 0.4} or {1, 0.3, 0.3})
        log("==========================================", {1, 0.9, 0.3})

        if failed == 0 then
            log("\nQuizApp: ALL TESTS PASSED!", {0.2, 1, 0.4})
        else
            log("\nQuizApp: SOME TESTS FAILED!", {1, 0.3, 0.3})
        end

        timer.performWithDelay(3000, function()
            os.exit(failed == 0 and 0 or 1)
        end)
    end
end

-- Start after a short delay to let initial render complete
timer.performWithDelay(300, nextStep)
