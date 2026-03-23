-- Simple screenshot test
local function testScreenshot()
    print("=== SOLAR2D SCREENSHOT TEST STARTING ===")

    -- Create a simple visual
    local bg = display.newRect(display.contentCenterX, display.contentCenterY, 320, 480)
    bg:setFillColor(0.1, 0.1, 0.2)

    local text = display.newText({
        text = "Screenshot Test",
        x = display.contentCenterX,
        y = 100,
        font = native.systemFont,
        fontSize = 24,
    })
    text:setFillColor(0, 0.5, 1)

    local redBox = display.newRect(display.contentCenterX, 200, 100, 100)
    redBox:setFillColor(1, 0, 0)

    local greenBox = display.newRect(display.contentCenterX, 320, 100, 100)
    greenBox:setFillColor(0, 1, 0)

    print("Visual elements created")

    -- Capture screenshot
    timer.performWithDelay(500, function()
        print("Capturing screenshot...")
        local stage = display.getCurrentStage()

        -- Try with baseDir
        local success = pcall(function()
            display.capture(stage, {
                filename = "output/simple_test.png",
                baseDir = system.DocumentsDirectory,
                saveToPhotoLibrary = false,
            })
        end)

        if success then
            print("SCREENSHOT_SUCCESS: simple_test.png")
        else
            print("SCREENSHOT_FAILED")
        end
    end)
end

testScreenshot()
