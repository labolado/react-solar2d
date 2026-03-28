-- examples/kitchen_sink/AnimationScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useRef = React.useRef
local T = require("kitchen_sink.theme")
local RN = require("react_solar2d")
local Animated = require("animated")
local Hooks = require("hooks.useTimer")
local Section = T.Section
local DemoPage = T.DemoPage

-- 1. TimingDemo
local function TimingDemo()
    local posX = useRef(Animated.Value(0)).current
    local opacityVal = useRef(Animated.Value(1)).current
    local duration, setDuration = useState(500)

    local function slideRight()
        Animated.timing(posX, { toValue = 200, duration = duration }).start()
    end
    local function slideLeft()
        Animated.timing(posX, { toValue = 0, duration = duration }).start()
    end
    local function fadeOut()
        Animated.timing(opacityVal, { toValue = 0.1, duration = duration }).start()
    end
    local function fadeIn()
        Animated.timing(opacityVal, { toValue = 1, duration = duration }).start()
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Slide (translateX)" },
            ce(Animated.View, {
                style = {
                    width = 80, height = 80, backgroundColor = T.accent,
                    borderRadius = T.radius, translateX = posX,
                },
            }),
            ce("View", { style = { flexDirection = "row", gap = 8, marginTop = 12 } },
                ce(RN.Button, { title = "Right →", color = T.accent, onPress = slideRight }),
                ce(RN.Button, { title = "← Left", color = T.textSecondary, onPress = slideLeft })
            )
        ),
        ce(Section, { title = "Opacity Fade" },
            ce(Animated.View, {
                style = {
                    width = 80, height = 80, backgroundColor = "#FF6600",
                    borderRadius = T.radius, opacity = opacityVal,
                },
            }),
            ce("View", { style = { flexDirection = "row", gap = 8, marginTop = 12 } },
                ce(RN.Button, { title = "Fade Out", color = "#FF6600", onPress = fadeOut }),
                ce(RN.Button, { title = "Fade In", color = T.textSecondary, onPress = fadeIn })
            )
        ),
        ce(Section, { title = "Duration: " .. duration .. "ms" },
            ce("View", { style = { flexDirection = "row", gap = 8 } },
                ce(RN.Button, { title = "200ms", color = duration == 200 and T.accent or T.textSecondary, onPress = function() setDuration(200) end }),
                ce(RN.Button, { title = "500ms", color = duration == 500 and T.accent or T.textSecondary, onPress = function() setDuration(500) end }),
                ce(RN.Button, { title = "1000ms", color = duration == 1000 and T.accent or T.textSecondary, onPress = function() setDuration(1000) end })
            )
        )
    )
end

-- 2. SpringDemo
local function SpringDemo()
    local scaleVal = useRef(Animated.Value(1)).current
    local function bounce()
        scaleVal:setValue(0.5)
        Animated.spring(scaleVal, { toValue = 1 }).start()
    end
    return ce(DemoPage, {},
        ce(Section, { title = "Spring Scale (tap the box)" },
            ce(Animated.View, {
                style = {
                    width = 120, height = 120, backgroundColor = "#E74C3C",
                    borderRadius = T.radius, scaleX = scaleVal, scaleY = scaleVal,
                    alignSelf = "center",
                },
                onPress = bounce,
            }),
            ce("Text", {
                style = { fontSize = 14, color = T.textSecondary, textAlign = "center", marginTop = 12 },
            }, "Tap the red box for spring bounce")
        )
    )
end

-- 3. SequenceDemo
local function SequenceDemo()
    local posX = useRef(Animated.Value(0)).current
    local opacityVal = useRef(Animated.Value(1)).current
    local running, setRunning = useState(false)

    local function play()
        setRunning(true)
        posX:setValue(0)
        opacityVal:setValue(1)
        Animated.sequence({
            Animated.timing(posX, { toValue = 200, duration = 400 }),
            Animated.timing(opacityVal, { toValue = 0, duration = 300 }),
            Animated.parallel({
                Animated.timing(posX, { toValue = 0, duration = 400 }),
                Animated.timing(opacityVal, { toValue = 1, duration = 400 }),
            }),
        }).start(function() setRunning(false) end)
    end

    local function reset()
        posX:setValue(0)
        opacityVal:setValue(1)
        setRunning(false)
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Sequence: slide → fade → restore" },
            ce(Animated.View, {
                style = {
                    width = 80, height = 80, backgroundColor = "#00C853",
                    borderRadius = T.radius, translateX = posX, opacity = opacityVal,
                },
            }),
            ce("View", { style = { flexDirection = "row", gap = 8, marginTop = 12 } },
                ce(RN.Button, { title = running and "Playing..." or "Play", color = T.accent, onPress = play }),
                ce(RN.Button, { title = "Reset", color = T.textSecondary, onPress = reset })
            )
        )
    )
end

-- 4. ParallelDemo
local function ParallelDemo()
    local scaleVal = useRef(Animated.Value(1)).current
    local rotateVal = useRef(Animated.Value(0)).current
    local opacityVal = useRef(Animated.Value(1)).current

    local function play()
        scaleVal:setValue(1)
        rotateVal:setValue(0)
        opacityVal:setValue(1)
        Animated.parallel({
            Animated.timing(scaleVal, { toValue = 1.5, duration = 600 }),
            Animated.timing(rotateVal, { toValue = 180, duration = 600 }),
            Animated.timing(opacityVal, { toValue = 0.3, duration = 600 }),
        }).start()
    end

    local function reset()
        scaleVal:setValue(1)
        rotateVal:setValue(0)
        opacityVal:setValue(1)
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Parallel: scale + rotate + opacity" },
            ce(Animated.View, {
                style = {
                    width = 100, height = 100, backgroundColor = "#9C27B0",
                    borderRadius = T.radius, alignSelf = "center",
                    scaleX = scaleVal, scaleY = scaleVal,
                    rotation = rotateVal, opacity = opacityVal,
                },
            }),
            ce("View", { style = { flexDirection = "row", gap = 8, marginTop = 16 } },
                ce(RN.Button, { title = "Play All", color = "#9C27B0", onPress = play }),
                ce(RN.Button, { title = "Reset", color = T.textSecondary, onPress = reset })
            )
        )
    )
end

-- 5. LoopDemo
local function LoopDemo()
    local spinVal = useRef(Animated.Value(0)).current
    local pulseVal = useRef(Animated.Value(1)).current
    local spinAnim = useRef(nil)
    local pulseAnim = useRef(nil)
    local running, setRunning = useState(false)
    local tickCount, setTickCount = useState(0)

    -- useInterval-driven counter alongside animation
    Hooks.useInterval(function()
        setTickCount(function(c) return c + 1 end)
    end, running and 1000 or false)

    local function startAll()
        setRunning(true)
        setTickCount(0)
        spinVal:setValue(0)
        pulseVal:setValue(1)
        spinAnim.current = Animated.loop(
            Animated.timing(spinVal, { toValue = 360, duration = 1500 })
        )
        spinAnim.current:start()
        pulseAnim.current = Animated.loop(
            Animated.sequence({
                Animated.timing(pulseVal, { toValue = 0.3, duration = 500 }),
                Animated.timing(pulseVal, { toValue = 1, duration = 500 }),
            }),
            { iterations = 3 }
        )
        pulseAnim.current:start()
    end

    local function stopAll()
        setRunning(false)
        if spinAnim.current then spinAnim.current:stop() end
        if pulseAnim.current then pulseAnim.current:stop() end
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Infinite Rotation" },
            ce(Animated.View, {
                style = {
                    width = 80, height = 80, backgroundColor = T.accent,
                    borderRadius = 8, rotation = spinVal, alignSelf = "center",
                },
            }, ce("Text", {
                style = { fontSize = 24, color = "#FFF", textAlign = "center" },
            }, "+"))
        ),
        ce(Section, { title = "Pulsing Opacity (3 iterations)" },
            ce(Animated.View, {
                style = {
                    width = 80, height = 80, backgroundColor = "#FF6600",
                    borderRadius = 40, opacity = pulseVal, alignSelf = "center",
                },
            })
        ),
        ce(Section, { title = "useInterval Counter" },
            ce("Text", {
                style = { fontSize = 24, color = T.textPrimary, textAlign = "center" },
            }, "Ticks: " .. tickCount)
        ),
        ce("View", { style = { flexDirection = "row", gap = 8 } },
            ce(RN.Button, { title = running and "Running..." or "Start", color = T.accent, onPress = startAll }),
            ce(RN.Button, { title = "Stop", color = T.textSecondary, onPress = stopAll })
        )
    )
end

return {
    { name = "Timing",   component = TimingDemo,   description = "Slide, fade, duration control",       icon = "T" },
    { name = "Spring",   component = SpringDemo,   description = "Elastic bounce on tap",               icon = "S" },
    { name = "Sequence", component = SequenceDemo, description = "Chained multi-step animation",        icon = "Q" },
    { name = "Parallel", component = ParallelDemo, description = "Scale + rotate + fade at once",       icon = "P" },
    { name = "Loop",     component = LoopDemo,     description = "Infinite spin, pulse, useInterval",   icon = "L" },
}
