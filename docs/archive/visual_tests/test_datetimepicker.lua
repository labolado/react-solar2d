-- tests/visual/test_datetimepicker.lua
-- Standalone visual test for DateTimePicker component

local React = require("react")
local ReactSolar2D = require("react_solar2d")
local DateTimePicker = require("lib.datetime-picker")

local function TestApp()
    local useState = React.useState
    local ce = React.createElement

    local date, setDate = useState(os.time())
    local time, setTime = useState(os.time())

    -- Auto-capture screenshot
    timer.performWithDelay(1500, function()
        local stage = display.getCurrentStage()
        -- Save to project directory for verification
        local path = system.pathForFile("tests/visual/output/datetimepicker_test.png", system.ResourceDirectory)
        if path then
            -- Create directory if needed
            local dir = path:match("(.+)/[^/]+$")
            if dir then
                os.execute("mkdir -p '" .. dir .. "'")
            end
            display.capture(stage, {
                filename = "tests/visual/output/datetimepicker_test.png",
                baseDir = system.ResourceDirectory,
                saveToPhotoLibrary = false,
            })
            print("SCREENSHOT_SAVED: " .. path)
        else
            -- Fallback to default location
            display.capture(stage, {
                filename = "datetimepicker_test.png",
                saveToPhotoLibrary = false,
            })
            print("SCREENSHOT_SAVED: datetimepicker_test.png (default location)")
        end
    end)

    return ce("View", {
        style = {
            flex = 1,
            backgroundColor = "#1a1a2e",
            padding = 20,
        }
    },
        ce("Text", {
            style = { fontSize = 18, color = "#007AFF", marginBottom = 20 }
        }, "@react-native-community/datetimepicker"),

        -- Date picker
        ce("Text", { style = { fontSize = 12, color = "#888", marginBottom = 8 } }, "Date:"),
        ce(DateTimePicker.DateTimePicker, {
            value = date,
            mode = "date",
            onChange = function(e)
                if e.type == DateTimePicker.EventType.SET then
                    setDate(e.nativeEvent.timestamp)
                end
            end,
            style = { marginBottom = 30 },
        }),

        -- Time picker
        ce("Text", { style = { fontSize = 12, color = "#888", marginBottom = 8 } }, "Time:"),
        ce(DateTimePicker.DateTimePicker, {
            value = time,
            mode = "time",
            onChange = function(e)
                if e.type == DateTimePicker.EventType.SET then
                    setTime(e.nativeEvent.timestamp)
                end
            end,
        })
    )
end

-- Start app
ReactSolar2D.render(
    React.createElement(TestApp),
    display.newGroup()
)

ReactSolar2D.startAutoFlush()
