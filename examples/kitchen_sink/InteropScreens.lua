-- examples/kitchen_sink/InteropScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")

-- 1. ReactInSolar2DDemo
-- Demonstrates native Solar2D code hosting a React subtree via RN.render()
local function ReactInSolar2DDemo()
    local groupRef = useRef(nil)
    local rendererRef = useRef(nil)

    useEffect(function()
        -- Create the scene group that holds everything
        -- Offset down to avoid covering the category bar and back button
        local sceneGroup = display.newGroup()
        groupRef.current = sceneGroup
        local yOffset = 160 -- below category bar + back button + demo back button
        sceneGroup.y = yOffset

        -- Section 1: Native Solar2D objects (top, relative to yOffset)
        local headerText = display.newText({
            parent = sceneGroup, text = "Native Solar2D Header",
            x = display.contentCenterX, y = 30,
            fontSize = 16,
        })
        headerText:setFillColor(1, 0.4, 0) -- orange

        local circle = display.newCircle(sceneGroup, 80, 70, 20)
        circle:setFillColor(1, 0.3, 0.3) -- tomato

        local rect = display.newRect(sceneGroup, 180, 70, 60, 30)
        rect:setFillColor(1, 0.84, 0) -- gold

        -- Section 2: React subtree rendered into a sub-group
        local reactGroup = display.newGroup()
        sceneGroup:insert(reactGroup)
        reactGroup.y = 100

        -- Counter component rendered via RN.render
        local function CounterCard()
            local count, setCount = useState(0)
            return ce("View", {
                style = {
                    backgroundColor = "#161B22", borderRadius = 12,
                    padding = 16, borderWidth = 2, borderColor = "#58A6FF",
                    width = 280, alignSelf = "center",
                },
            },
                ce("Text", { style = { fontSize = 18, color = "#E6EDF3", fontWeight = "bold" } },
                    "React Subtree (RN.render)"),
                ce("Text", { style = { fontSize = 32, color = "#58A6FF", textAlign = "center", marginVertical = 8 } },
                    tostring(count)),
                ce("View", { style = { flexDirection = "row", gap = 8 } },
                    ce(RN.Button, { title = "-1", color = "#E74C3C", onPress = function()
                        setCount(function(c) return c - 1 end)
                    end }),
                    ce(RN.Button, { title = "+1", color = "#00C853", onPress = function()
                        setCount(function(c) return c + 1 end)
                    end })
                )
            )
        end

        rendererRef.current = RN.render(ce(CounterCard), reactGroup, { width = 300, height = 200 })

        -- Section 3: Native footer (relative to sceneGroup)
        local footerText = display.newText({
            parent = sceneGroup, text = "Native Solar2D Footer",
            x = display.contentCenterX, y = 320,
            fontSize = 14,
        })
        footerText:setFillColor(1, 0.4, 0) -- orange

        return function()
            -- Cleanup: unmount React tree and remove native objects
            if rendererRef.current then
                RN.unmount(reactGroup)
            end
            if sceneGroup and sceneGroup.removeSelf then
                sceneGroup:removeSelf()
            end
        end
    end, {})

    -- Render a back button within the React tree so user can always exit,
    -- even though the native display objects may overlay parts of the screen.
    local navigation = props and props.navigation
    return ce("View", { style = { flex = 1, backgroundColor = T.bg } },
        navigation and navigation.goBack and ce(RN.Pressable, {
            style = {
                padding = 12, backgroundColor = "#161B22",
                borderBottomWidth = 1, borderColor = T.border,
                zIndex = 999,
            },
            onPress = navigation.goBack,
        }, ce("Text", { style = { fontSize = 14, color = T.accent } }, "← Back to list")) or nil
    )
end

-- 2. Solar2DInReactDemo
-- React layout with native Solar2D display objects created inside via useEffect
local function Solar2DInReactDemo()
    local canvasRef = useRef(nil)
    local running, setRunning = useState(true)
    local runningRef = useRef(true)
    runningRef.current = running

    useEffect(function()
        -- We need access to the View's underlying display group.
        -- The View component creates a display group; we access it after mount.
        -- For this demo, we create a separate group positioned in the canvas area.
        local nativeGroup = display.newGroup()
        local canvasY = 200 -- approximate position of the canvas area
        nativeGroup.y = canvasY

        -- Create native display objects
        local ball = display.newCircle(nativeGroup, 160, 50, 15)
        ball:setFillColor(1, 0.3, 0.3) -- tomato

        local particle1 = display.newCircle(nativeGroup, 40, 30, 4)
        particle1:setFillColor(1, 0.84, 0) -- gold
        particle1.alpha = 0.7

        local particle2 = display.newCircle(nativeGroup, 80, 60, 3)
        particle2:setFillColor(0.53, 0.81, 0.92) -- skyblue
        particle2.alpha = 0.5

        local particle3 = display.newCircle(nativeGroup, 250, 40, 5)
        particle3:setFillColor(0, 0.78, 0.33) -- green
        particle3.alpha = 0.6

        -- Bouncing ball via enterFrame listener
        local direction = 1
        local speed = 3
        local function onEnterFrame()
            if not runningRef.current then return end
            ball.y = ball.y + direction * speed
            if ball.y >= 140 then
                direction = -1
            elseif ball.y <= 10 then
                direction = 1
            end
        end
        Runtime:addEventListener("enterFrame", onEnterFrame)

        -- Cleanup on unmount
        return function()
            Runtime:removeEventListener("enterFrame", onEnterFrame)
            if nativeGroup and nativeGroup.removeSelf then
                nativeGroup:removeSelf()
            end
        end
    end, {})

    return ce("ScrollView", {
        style = { flex = 1, backgroundColor = T.bg },
        contentContainerStyle = { padding = T.pad },
    },
        -- React header
        ce("View", { style = { marginBottom = T.gap } },
            ce("Text", { style = { fontSize = 14, color = T.accent, fontWeight = "bold", marginBottom = 8 } },
                "React Header (managed by React)"),
            ce("View", {
                style = { backgroundColor = T.surface, borderRadius = T.radius, padding = T.pad },
            },
                ce("Text", { style = { fontSize = 16, color = T.textPrimary } },
                    "This header is a normal React View + Text component.")
            )
        ),

        -- Canvas area — the native Solar2D objects are positioned here via useEffect
        ce("View", { style = { marginBottom = T.gap } },
            ce("Text", { style = { fontSize = 14, color = T.accent, fontWeight = "bold", marginBottom = 8 } },
                "Solar2D Canvas (useEffect + enterFrame)"),
            ce("View", {
                style = {
                    height = 180, backgroundColor = "#0A0A1A",
                    borderRadius = T.radius, borderWidth = 2, borderColor = "#FF6600",
                },
            },
                ce("Text", {
                    style = { fontSize = 10, color = "#FF6600", textAlign = "center", marginTop = 4 },
                }, "Native display objects rendered via useEffect + enterFrame listener")
            ),
            ce("View", { style = { flexDirection = "row", gap = 8, marginTop = 8 } },
                ce(RN.Button, {
                    title = running and "Pause" or "Resume",
                    color = T.accent,
                    onPress = function() setRunning(function(r) return not r end) end,
                })
            )
        ),

        -- React footer
        ce("View", { style = { marginBottom = T.gap } },
            ce("Text", { style = { fontSize = 14, color = T.accent, fontWeight = "bold", marginBottom = 8 } },
                "React Footer (managed by React)"),
            ce("View", {
                style = { backgroundColor = T.surface, borderRadius = T.radius, padding = T.pad },
            },
                ce("Text", { style = { fontSize = 16, color = T.textPrimary } },
                    "React manages layout and state. Solar2D handles the bouncing ball with enterFrame. Cleanup runs on unmount.")
            )
        )
    )
end

return {
    { name = "ReactInSolar", component = ReactInSolar2DDemo, description = "Native code hosts React subtree",     icon = "R" },
    { name = "Solar2DInReact", component = Solar2DInReactDemo, description = "React layout with native canvas", icon = "S" },
}
