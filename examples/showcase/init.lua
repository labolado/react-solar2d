--- Showcase launcher.
-- Run a showcase demo: require("showcase").run("SwipeDeck")
-- Available: SwipeDeck, NeonDashboard, OnboardingFlow, MusicPlayer

local RN = require("react_solar2d")

local DEMOS = {
    SwipeDeck      = "showcase.SwipeDeck",
    NeonDashboard  = "showcase.NeonDashboard",
    OnboardingFlow = "showcase.OnboardingFlow",
    MusicPlayer    = "showcase.MusicPlayer",
}

local M = {}

function M.run(name)
    local mod = DEMOS[name]
    if not mod then
        print("Available showcases: SwipeDeck, NeonDashboard, OnboardingFlow, MusicPlayer")
        return
    end
    local App = require(mod)
    local root = display.newGroup()
    root.x = display.screenOriginX or 0
    root.y = display.screenOriginY or 0
    RN.render(RN.createElement(App), root)
    RN.startAutoFlush(root)
    return root
end

--- List all available demos.
function M.list()
    local names = {}
    for k in pairs(DEMOS) do names[#names + 1] = k end
    table.sort(names)
    return names
end

return M
