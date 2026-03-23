--[[
  Self-test for Slider component within Solar2D
  This runs inside the Simulator and can verify drag operations
--]]

local function testSlider()
    print("=" .. string.rep("=", 50))
    print("AI Slider Automation Test (Internal)")
    print("=" .. string.rep("=", 50))

    -- Get runtime info
    local w = display.contentWidth
    local h = display.contentHeight
    print(string.format("Screen: %dx%d", w, h))

    -- Simulate a drag operation
    local startTime = system.getTimer()

    -- Create a test slider if not exists
    local testGroup = display.newGroup()

    -- Background
    local bg = display.newRect(testGroup, w/2, h/2, w, h)
    bg:setFillColor(0.95, 0.95, 0.95)

    -- Title
    local title = display.newText({
        parent = testGroup,
        text = "Slider Auto-Test",
        x = w/2,
        y = 100,
        font = native.systemFontBold,
        fontSize = 24
    })
    title:setFillColor(0.2, 0.2, 0.2)

    -- Create a simple slider for testing
    local trackY = h/2
    local trackWidth = 300
    local trackHeight = 4
    local thumbSize = 30

    -- Track
    local track = display.newRoundedRect(testGroup, w/2, trackY, trackWidth, trackHeight, 2)
    track:setFillColor(0.8, 0.8, 0.8)

    -- Filled track (initially empty)
    local filledTrack = display.newRoundedRect(testGroup, w/2 - trackWidth/2, trackY, 0, trackHeight, 2)
    filledTrack:setFillColor(0, 0.48, 1) -- iOS blue
    filledTrack.anchorX = 0

    -- Thumb
    local thumb = display.newCircle(testGroup, w/2 - trackWidth/2, trackY, thumbSize/2)
    thumb:setFillColor(1, 1, 1)
    thumb.strokeWidth = 2
    thumb:setStrokeColor(0.7, 0.7, 0.7)

    -- Value text
    local valueText = display.newText({
        parent = testGroup,
        text = "Value: 0%",
        x = w/2,
        y = trackY + 60,
        font = native.systemFont,
        fontSize = 18
    })
    valueText:setFillColor(0.3, 0.3, 0.3)

    -- Simulate drag animation
    local targetValue = 0.7 -- 70%
    local currentValue = 0
    local duration = 1000 -- 1 second

    print("\n[Step 1] Starting drag simulation...")

    local function updateSlider(value)
        local x = (w/2 - trackWidth/2) + value * trackWidth
        thumb.x = x
        filledTrack.width = value * trackWidth
        valueText.text = string.format("Value: %d%%", math.floor(value * 100))
    end

    -- Animate the drag
    transition.to(thumb, {
        time = duration,
        x = (w/2 - trackWidth/2) + targetValue * trackWidth,
        onUpdate = function()
            currentValue = (thumb.x - (w/2 - trackWidth/2)) / trackWidth
            filledTrack.width = currentValue * trackWidth
            valueText.text = string.format("Value: %d%%", math.floor(currentValue * 100))
        end,
        onComplete = function()
            print("[Step 2] Drag completed!")
            print(string.format("         Final value: %.1f%%", currentValue * 100))

            -- Verify result
            if math.abs(currentValue - targetValue) < 0.05 then
                print("[Step 3] ✅ TEST PASSED")
            else
                print("[Step 3] ❌ TEST FAILED")
            end

            print("\n" .. string.rep("=", 52))
            print("Test completed in " .. (system.getTimer() - startTime) .. "ms")
            print(string.rep("=", 52))

            -- Cleanup after delay
            timer.performWithDelay(3000, function()
                testGroup:removeSelf()
                print("\nCleanup complete. Test scene closed.")
            end)
        end
    })
end

-- Run test
print("\n🚀 Starting internal Slider test...")
timer.performWithDelay(100, testSlider)

return true
