-- tests/visual/test_slider.lua
-- Standalone visual test for Slider component
-- Run in Solar2D Simulator, captures screenshot on startup

local React = require("react")
local ReactSolar2D = require("react_solar2d")
local Slider = require("lib.slider")

local function TestApp()
    local useState = React.useState
    local ce = React.createElement

    local value1, setValue1 = useState(0.5)
    local value2, setValue2 = useState(50)
    local value3, setValue3 = useState(10)

    -- Auto-capture screenshot after delay
    local function captureScreenshot()
        timer.performWithDelay(1500, function()
            local stage = display.getCurrentStage()
            -- Save to project directory for verification
            local path = system.pathForFile("tests/visual/output/slider_test.png", system.ResourceDirectory)
            if path then
                -- Create directory if needed
                local dir = path:match("(.+)/[^/]+$")
                if dir then
                    os.execute("mkdir -p '" .. dir .. "'")
                end
                display.capture(stage, {
                    filename = "tests/visual/output/slider_test.png",
                    baseDir = system.ResourceDirectory,
                    saveToPhotoLibrary = false,
                })
                print("SCREENSHOT_SAVED: " .. path)
            else
                -- Fallback to default location
                display.capture(stage, {
                    filename = "slider_test.png",
                    saveToPhotoLibrary = false,
                })
                print("SCREENSHOT_SAVED: slider_test.png (default location)")
            end
        end)
    end

    captureScreenshot()

    return ce("View", {
        style = {
            flex = 1,
            backgroundColor = "#1a1a2e",
            padding = 20,
        }
    },
        -- Title
        ce("Text", {
            style = { fontSize = 18, color = "#007AFF", marginBottom = 20 }
        }, "@react-native-community/slider"),

        -- Test 1: Basic
        ce("Text", { style = { fontSize = 12, color = "#888", marginBottom = 8 } },
            "Basic (0-1): " .. string.format("%.2f", value1)),
        ce(Slider.Slider, {
            value = value1,
            onValueChange = setValue1,
            style = { width = 280, marginBottom = 30 },
        }),

        -- Test 2: Custom color
        ce("Text", { style = { fontSize = 12, color = "#888", marginBottom = 8 } },
            "Custom color: " .. math.floor(value2)),
        ce(Slider.Slider, {
            value = value2,
            minimumValue = 0,
            maximumValue = 100,
            step = 1,
            onValueChange = setValue2,
            minimumTrackTintColor = "#00AA00",
            style = { width = 280, marginBottom = 30 },
        }),

        -- Test 3: With step
        ce("Text", { style = { fontSize = 12, color = "#888", marginBottom = 8 } },
            "With step (0-20, step=2): " .. math.floor(value3)),
        ce(Slider.Slider, {
            value = value3,
            minimumValue = 0,
            maximumValue = 20,
            step = 2,
            onValueChange = setValue3,
            minimumTrackTintColor = "#FF9500",
            style = { width = 280 },
        })
    )
end

-- Start app
ReactSolar2D.render(
    React.createElement(TestApp),
    display.newGroup()
)

ReactSolar2D.startAutoFlush()
