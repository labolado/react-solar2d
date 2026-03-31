--- ShowcaseApp — Launcher for showcase demos.
-- Lists available showcases, tap to launch full-screen.

local RN = require("react_solar2d")
local React = require("react")
local ce = React.createElement
local useState = React.useState
local Navigation = require("navigation")

local DEMOS = {
    { name = "SwipeDeck",      title = "Swipe Deck",       desc = "Tinder-style card stack",       color = "#FF6B6B", icon = "♠" },
    { name = "NeonDashboard",  title = "Neon Dashboard",   desc = "Animated stats & glowing UI",   color = "#58A6FF", icon = "◈" },
    { name = "OnboardingFlow", title = "Onboarding Flow",  desc = "Elegant app introduction",      color = "#6366F1", icon = "✦" },
    { name = "MusicPlayer",    title = "Music Player",     desc = "Sleek player with equalizer",   color = "#1DB954", icon = "♪" },
}

local Stack = Navigation.createStackNavigator()

-- ─── Demo List ───────────────────────────────────────────────────────────
local function DemoList(props)
    local nav = props.navigation
    local cards = {}
    for i, demo in ipairs(DEMOS) do
        cards[i] = ce("View", {
            key = demo.name,
            style = {
                backgroundColor = "#111827",
                borderRadius = 16,
                padding = 20,
                marginBottom = 12,
                borderWidth = 1,
                borderColor = demo.color,
                flexDirection = "row",
                alignItems = "center",
                gap = 16,
            },
            onPress = function()
                nav.navigate(demo.name)
            end,
        },
            -- Icon circle
            ce("View", {
                style = {
                    width = 48, height = 48, borderRadius = 24,
                    backgroundColor = demo.color,
                    justifyContent = "center", alignItems = "center",
                },
            },
                ce("Text", { style = { fontSize = 22, color = "#FFF" } }, demo.icon)
            ),
            -- Text
            ce("View", { style = { flex = 1 } },
                ce("Text", {
                    style = { color = "#FFF", fontSize = 17, fontWeight = "bold" },
                }, demo.title),
                ce("Text", {
                    style = { color = "rgba(255,255,255,0.5)", fontSize = 13, marginTop = 2 },
                }, demo.desc)
            ),
            -- Arrow
            ce("Text", { style = { color = "rgba(255,255,255,0.3)", fontSize = 20 } }, "›")
        )
    end

    return ce(RN.ScrollView, {
        style = { flex = 1, backgroundColor = "#0A0A1A" },
        contentContainerStyle = { padding = 16, paddingTop = 20, paddingBottom = 40 },
    },
        ce("Text", {
            style = {
                color = "#FFF", fontSize = 24, fontWeight = "bold",
                marginBottom = 4,
            },
        }, "Showcase"),
        ce("Text", {
            style = { color = "rgba(255,255,255,0.4)", fontSize = 13, marginBottom = 20 },
        }, "Design-forward demos built with React-Solar2D"),
        unpack(cards)
    )
end

-- ─── App ─────────────────────────────────────────────────────────────────
local function ShowcaseApp()
    -- Lazy-load demo modules
    local screens = {}
    for _, demo in ipairs(DEMOS) do
        local ok, mod = pcall(require, "showcase." .. demo.name)
        if ok then
            screens[demo.name] = mod
        else
            print("[Showcase] Failed to load " .. demo.name .. ": " .. tostring(mod))
            screens[demo.name] = function()
                return ce("View", {
                    style = { flex = 1, backgroundColor = "#0A0A1A", justifyContent = "center", alignItems = "center" },
                },
                    ce("Text", { style = { color = "#E74C3C", fontSize = 16 } }, "Failed to load " .. demo.name)
                )
            end
        end
    end

    return ce(Navigation.NavigationContainer, {},
        ce(Stack.Navigator, { initialRouteName = "_list" },
            ce(Stack.Screen, {
                name = "_list",
                component = DemoList,
                options = { headerShown = false },
            }),
            unpack((function()
                local items = {}
                for i, demo in ipairs(DEMOS) do
                    items[i] = ce(Stack.Screen, {
                        key = demo.name,
                        name = demo.name,
                        component = screens[demo.name],
                        options = { title = demo.title },
                    })
                end
                return items
            end)())
        )
    )
end

return ShowcaseApp
