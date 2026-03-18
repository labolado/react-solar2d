-- Visual test for Modal - run in Solar2D
local React = require("react")
local ce = React.createElement
local useState = React.useState
local RN = require("react_solar2d")

local function TestModal()
    local visible, setVisible = useState(false)

    return ce("View", {
        style = {
            flex = 1,
            backgroundColor = "#F0F0F0",
            justifyContent = "center",
            alignItems = "center",
        }
    },
        ce(RN.Button, {
            title = "Show Modal",
            color = "#FF6600",
            onPress = function() setVisible(true) end
        }),
        ce(RN.Modal, {
            visible = visible,
            transparent = true,
            onRequestClose = function() setVisible(false) end
        },
            ce("View", {
                style = {
                    width = 250,
                    height = 150,
                    backgroundColor = "#FFFFFF",
                    borderRadius = 12,
                    justifyContent = "center",
                    alignItems = "center",
                    shadowColor = "#000",
                    shadowOpacity = 0.3,
                    shadowRadius = 10,
                }
            },
                ce("Text", {
                    style = { fontSize = 18, fontWeight = "bold", marginBottom = 20 }
                }, "Test Modal"),
                ce(RN.Button, {
                    title = "Close",
                    color = "#666",
                    onPress = function() setVisible(false) end
                })
            )
        )
    )
end

-- Mount
local container = display.newGroup()
require("react_solar2d").render(ce(TestModal), container)

print("[Modal Test] Mounted - tap 'Show Modal' to test")
