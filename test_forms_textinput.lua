-- Forms TextInput integration test
-- Run via: curl -X POST http://localhost:9876/exec -d "code=$(cat test_forms_textinput.lua | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')"

print("=== Forms TextInput Integration Test ===")

-- Check if we can create TextInput within a form-like structure
local React = require("react")
local RN = require("react_solar2d")
local Renderer = require("renderer")

local ce = React.createElement
local useState = React.useState

local function FormWithTextInput()
    local name, setName = useState("")
    local email, setEmail = useState("")

    return ce("View", { style = { width = 400, height = 300, backgroundColor = "#FFFFFF", padding = 20 } },
        ce("Text", { style = { fontSize = 18, marginBottom = 10 } }, "Name:"),
        ce(RN.TextInput, {
            placeholder = "Enter name...",
            value = name,
            onChangeText = function(t) setName(t) end,
            style = {
                width = 360,
                height = 40,
                backgroundColor = "#F5F5F5",
                borderWidth = 1,
                borderColor = "#CCCCCC",
                marginBottom = 15,
            },
        }),
        ce("Text", { style = { fontSize = 18, marginBottom = 10 } }, "Email:"),
        ce(RN.TextInput, {
            placeholder = "Enter email...",
            value = email,
            onChangeText = function(t) setEmail(t) end,
            style = {
                width = 360,
                height = 40,
                backgroundColor = "#F5F5F5",
                borderWidth = 1,
                borderColor = "#CCCCCC",
            },
        })
    )
end

print("Creating FormWithTextInput element...")
local element = ce(FormWithTextInput)
print("Element created successfully")

if display then
    print("Rendering in Solar2D...")
    local container = display.newGroup()

    -- Clear any previous test container
    if _G._testContainer then
        _G._testContainer:removeSelf()
    end
    _G._testContainer = container

    local ok, err = pcall(function()
        Renderer.render(element, container)
    end)

    if ok then
        print("SUCCESS: Forms TextInput rendered without crash")
        print("TextInput crash fix verified!")
    else
        print("FAILED: " .. tostring(err))
    end
else
    print("No display available (not in Solar2D)")
end

print("=== Test Complete ===")
