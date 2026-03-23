-- examples/kitchen_sink/AdvancedScreens.lua
-- Demos: Badge, ProgressBar, Accordion, Dropdown, Card patterns
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useRef = React.useRef
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")
local Animated = require("animated")
local Hooks = require("hooks.useTimer")
local GestureHandler = require("lib.gesture-handler")
local Section = T.Section
local DemoPage = T.DemoPage

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. BadgeDemo — notification badges, status tags, chips
-- ═══════════════════════════════════════════════════════════════════════════
local function BadgeDemo()
    local count, setCount = useState(3)

    local function Badge(props)
        return ce("View", {
            style = {
                backgroundColor = props.color or "#E74C3C",
                borderRadius = props.pill and 12 or 4,
                paddingHorizontal = props.pill and 10 or 6,
                paddingVertical = 2,
                minWidth = props.dot and 10 or 0,
                height = props.dot and 10 or nil,
            },
        }, not props.dot and ce("Text", {
            style = { fontSize = props.size or 11, color = "#FFF", fontWeight = "bold", textAlign = "center" },
        }, props.text or "") or nil)
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Number Badges" },
            ce("View", { style = { flexDirection = "row", gap = 20, alignItems = "center" } },
                -- Icon with badge
                ce("View", {},
                    ce("View", { style = { width = 44, height = 44, borderRadius = 10, backgroundColor = T.accent, justifyContent = "center", alignItems = "center" } },
                        ce("Text", { style = { fontSize = 20, color = "#FFF" } }, "M")
                    ),
                    ce("View", { style = { position = "absolute", right = -6, top = -4 } },
                        Badge({ text = tostring(count), color = "#E74C3C", pill = true })
                    )
                ),
                ce("View", {},
                    ce("View", { style = { width = 44, height = 44, borderRadius = 10, backgroundColor = "#2ECC71", justifyContent = "center", alignItems = "center" } },
                        ce("Text", { style = { fontSize = 20, color = "#FFF" } }, "N")
                    ),
                    ce("View", { style = { position = "absolute", right = -4, top = -4 } },
                        Badge({ text = "99+", color = "#E74C3C", pill = true })
                    )
                ),
                -- Dot badge
                ce("View", {},
                    ce("View", { style = { width = 44, height = 44, borderRadius = 10, backgroundColor = "#9B59B6", justifyContent = "center", alignItems = "center" } },
                        ce("Text", { style = { fontSize = 20, color = "#FFF" } }, "P")
                    ),
                    ce("View", { style = { position = "absolute", right = -2, top = -2 } },
                        Badge({ dot = true, color = "#2ECC71" })
                    )
                )
            ),
            ce("View", { style = { flexDirection = "row", gap = 8, marginTop = 12 } },
                ce(RN.Button, { title = "+1", color = T.accent, onPress = function() setCount(count + 1) end }),
                ce(RN.Button, { title = "-1", color = T.textSecondary, onPress = function() setCount(math.max(0, count - 1)) end }),
                ce(RN.Button, { title = "Clear", color = "#E74C3C", onPress = function() setCount(0) end })
            )
        ),
        ce(Section, { title = "Status Tags" },
            ce("View", { style = { flexDirection = "row", gap = 8, flexWrap = "wrap" } },
                Badge({ text = "Active", color = "#2ECC71", pill = true }),
                Badge({ text = "Pending", color = "#F39C12", pill = true }),
                Badge({ text = "Error", color = "#E74C3C", pill = true }),
                Badge({ text = "Info", color = T.accent, pill = true }),
                Badge({ text = "Draft", color = T.textSecondary, pill = true }),
                Badge({ text = "New", color = "#9B59B6", pill = true })
            )
        ),
        ce(Section, { title = "Chips (removable tags)" },
            ce("View", { style = { flexDirection = "row", gap = 6, flexWrap = "wrap" } },
                ce("View", { style = { flexDirection = "row", alignItems = "center", backgroundColor = T.surface, borderRadius = 16, borderWidth = 1, borderColor = T.border, paddingLeft = 10, paddingRight = 4, paddingVertical = 4 } },
                    ce("Text", { style = { fontSize = 12, color = T.textPrimary, marginRight = 4 } }, "React"),
                    ce(RN.Pressable, { style = { width = 18, height = 18, borderRadius = 9, backgroundColor = T.border, justifyContent = "center", alignItems = "center" } },
                        ce("Text", { style = { fontSize = 10, color = T.textSecondary } }, "x"))
                ),
                ce("View", { style = { flexDirection = "row", alignItems = "center", backgroundColor = T.surface, borderRadius = 16, borderWidth = 1, borderColor = T.border, paddingLeft = 10, paddingRight = 4, paddingVertical = 4 } },
                    ce("Text", { style = { fontSize = 12, color = T.textPrimary, marginRight = 4 } }, "Solar2D"),
                    ce(RN.Pressable, { style = { width = 18, height = 18, borderRadius = 9, backgroundColor = T.border, justifyContent = "center", alignItems = "center" } },
                        ce("Text", { style = { fontSize = 10, color = T.textSecondary } }, "x"))
                ),
                ce("View", { style = { flexDirection = "row", alignItems = "center", backgroundColor = T.surface, borderRadius = 16, borderWidth = 1, borderColor = T.accent, paddingLeft = 10, paddingRight = 4, paddingVertical = 4 } },
                    ce("Text", { style = { fontSize = 12, color = T.accent, marginRight = 4 } }, "Lua"),
                    ce(RN.Pressable, { style = { width = 18, height = 18, borderRadius = 9, backgroundColor = T.accent, justifyContent = "center", alignItems = "center" } },
                        ce("Text", { style = { fontSize = 10, color = "#FFF" } }, "x"))
                )
            )
        )
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. ProgressDemo — progress bars, circular indicator
-- ═══════════════════════════════════════════════════════════════════════════
local function ProgressDemo()
    local progress, setProgress = useState(0.3)
    local autoProgress, setAutoProgress = useState(0)
    local running, setRunning = useState(false)

    Hooks.useInterval(function()
        setAutoProgress(function(p)
            if p >= 1 then setRunning(false); return 1 end
            return p + 0.02
        end)
    end, running and 50 or false)

    local function ProgressBar(props)
        local pct = math.min(1, math.max(0, props.value or 0))
        return ce("View", {
            style = {
                height = props.height or 8,
                backgroundColor = T.border,
                borderRadius = (props.height or 8) / 2,
                overflow = "hidden",
            },
        }, ce("View", {
            style = {
                width = pct * (props.width or 250),
                height = props.height or 8,
                backgroundColor = props.color or T.accent,
                borderRadius = (props.height or 8) / 2,
            },
        }))
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Manual Progress" },
            ProgressBar({ value = progress, width = 260 }),
            ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginTop = 4 } }, math.floor(progress * 100) .. "%"),
            ce("View", { style = { flexDirection = "row", gap = 8, marginTop = 8 } },
                ce(RN.Button, { title = "0%", color = T.textSecondary, onPress = function() setProgress(0) end }),
                ce(RN.Button, { title = "25%", color = T.accent, onPress = function() setProgress(0.25) end }),
                ce(RN.Button, { title = "50%", color = "#F39C12", onPress = function() setProgress(0.5) end }),
                ce(RN.Button, { title = "75%", color = "#E67E22", onPress = function() setProgress(0.75) end }),
                ce(RN.Button, { title = "100%", color = "#2ECC71", onPress = function() setProgress(1) end })
            )
        ),
        ce(Section, { title = "Auto-Animated Progress" },
            ProgressBar({ value = autoProgress, width = 260, color = "#2ECC71", height = 12 }),
            ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginTop = 4 } }, math.floor(autoProgress * 100) .. "%"),
            ce("View", { style = { flexDirection = "row", gap = 8, marginTop = 8 } },
                ce(RN.Button, {
                    title = running and "Running..." or "Start",
                    color = "#2ECC71",
                    onPress = function()
                        if not running then setAutoProgress(0); setRunning(true) end
                    end
                }),
                ce(RN.Button, { title = "Reset", color = T.textSecondary, onPress = function() setRunning(false); setAutoProgress(0) end })
            )
        ),
        ce(Section, { title = "Color Variants" },
            ce("View", { style = { gap = 8 } },
                ProgressBar({ value = 0.8, color = "#2ECC71", width = 260 }),
                ProgressBar({ value = 0.6, color = "#3498DB", width = 260 }),
                ProgressBar({ value = 0.4, color = "#F39C12", width = 260 }),
                ProgressBar({ value = 0.2, color = "#E74C3C", width = 260 })
            )
        ),
        ce(Section, { title = "Sizes" },
            ce("View", { style = { gap = 8 } },
                ProgressBar({ value = 0.7, height = 4, width = 260 }),
                ProgressBar({ value = 0.7, height = 8, width = 260 }),
                ProgressBar({ value = 0.7, height = 16, width = 260 }),
                ProgressBar({ value = 0.7, height = 24, width = 260 })
            )
        )
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. AccordionDemo — collapsible sections
-- ═══════════════════════════════════════════════════════════════════════════
local function AccordionDemo()
    local expanded, setExpanded = useState({})

    local function toggle(key)
        setExpanded(function(prev)
            local next = {}
            for k, v in pairs(prev) do next[k] = v end
            next[key] = not next[key]
            return next
        end)
    end

    local sections = {
        { key = "faq1", title = "What is React-Solar2D?", content = "A React-like framework for building UI in Solar2D (Corona SDK). Write declarative components with hooks, state management, and a virtual DOM." },
        { key = "faq2", title = "How does navigation work?", content = "Three navigator types: StackNavigator (push/pop screens), TabNavigator (parallel screens with tab bar), and DrawerNavigator (side menu panel)." },
        { key = "faq3", title = "Can I use animations?", content = "Yes! Animated.timing, spring, sequence, parallel, and loop are all supported. Values drive translateX, opacity, rotation, scale, and more." },
        { key = "faq4", title = "What about performance?", content = "FlatList provides windowed rendering for 1000+ items. The reconciler minimizes display object creation. Use useMemo/useCallback for expensive computations." },
    }

    local items = {}
    for _, sec in ipairs(sections) do
        local isOpen = expanded[sec.key]
        items[#items + 1] = ce("View", {
            key = sec.key,
            style = {
                backgroundColor = T.surface, borderRadius = T.radiusSmall,
                borderWidth = 1, borderColor = isOpen and T.accent or T.border,
                marginBottom = 8, overflow = "hidden",
            },
        },
            -- Header (always visible)
            ce(RN.Pressable, {
                style = { flexDirection = "row", alignItems = "center", padding = 14 },
                onPress = function() toggle(sec.key) end,
            },
                ce("Text", {
                    style = { flex = 1, fontSize = 14, fontWeight = "bold", color = isOpen and T.accent or T.textPrimary },
                }, sec.title),
                ce("Text", {
                    style = { fontSize = 16, color = T.textSecondary },
                }, isOpen and "−" or "+")
            ),
            -- Body (conditionally shown)
            isOpen and ce("View", {
                style = { paddingHorizontal = 14, paddingBottom = 14, borderTopWidth = 1, borderColor = T.border, paddingTop = 10 },
            },
                ce("Text", { style = { fontSize = 13, color = T.textSecondary, lineHeight = 20 } }, sec.content)
            ) or nil
        )
    end

    return ce(DemoPage, {},
        ce(Section, { title = "FAQ Accordion" },
            ce("View", {}, items)
        ),
        ce(Section, { title = "Tip" },
            ce("Text", { style = { fontSize = 12, color = T.textSecondary } }, "Tap section headers to expand/collapse. Multiple sections can be open simultaneously.")
        )
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. GestureDemo — Pan/Tap/LongPress handlers
-- ═══════════════════════════════════════════════════════════════════════════
local function GestureDemo()
    local dragBaseRef = useRef({ x = 0, y = 0 })
    local dragPos, setDragPos = useState({ x = 0, y = 0 })
    local dragLabel, setDragLabel = useState("拖拽我 🔧")
    local tapCount, setTapCount = useState(0)
    local longPressActive, setLongPressActive = useState(false)

    local function resolvedTranslation(nativeEvent)
        local base = dragBaseRef.current
        local dx = (nativeEvent and nativeEvent.translationX) or 0
        local dy = (nativeEvent and nativeEvent.translationY) or 0
        return base.x + dx, base.y + dy
    end

    local function handlePanEvent(event)
        local x, y = resolvedTranslation(event.nativeEvent)
        setDragPos({ x = x, y = y })
    end

    local function handlePanState(event)
        local state = event.state
        if state == GestureHandler.State.BEGAN then
            setDragLabel("开始拖拽")
        elseif state == GestureHandler.State.ACTIVE then
            setDragLabel("拖拽中…")
        elseif state == GestureHandler.State.END then
            local x, y = resolvedTranslation(event.nativeEvent)
            dragBaseRef.current = { x = x, y = y }
            setDragPos({ x = x, y = y })
            setDragLabel("拖拽完成 ✅")
        elseif state == GestureHandler.State.FAILED or state == GestureHandler.State.CANCELLED then
            setDragPos({ x = dragBaseRef.current.x, y = dragBaseRef.current.y })
            setDragLabel("拖拽被取消")
        end
    end

    local function handleTap()
        setTapCount(function(prev) return prev + 1 end)
    end

    local function handleLongPressState(event)
        if event.state == GestureHandler.State.ACTIVE then
            setLongPressActive(true)
        elseif event.state == GestureHandler.State.END
            or event.state == GestureHandler.State.FAILED
            or event.state == GestureHandler.State.CANCELLED then
            setLongPressActive(false)
        end
    end

    return ce(DemoPage, {},
        ce(Section, { title = "PanGestureHandler - 拖拽卡片" },
            ce("View", { style = { height = 170, justifyContent = "center", alignItems = "center" } },
                ce(GestureHandler.PanGestureHandler, {
                    style = { width = "100%", height = 170 },
                    minDist = 5,
                    onGestureEvent = handlePanEvent,
                    onHandlerStateChange = handlePanState,
                },
                    ce("View", {
                        style = {
                            width = 160,
                            height = 110,
                            borderRadius = 18,
                            backgroundColor = "#4F46E5",
                            justifyContent = "center",
                            alignItems = "center",
                            shadowColor = "#00000040",
                            shadowOpacity = 0.3,
                            shadowRadius = 8,
                            transform = {
                                { translateX = dragPos.x },
                                { translateY = dragPos.y },
                            },
                        }
                    },
                        ce("Text", { style = { fontSize = 14, color = "#FFFFFF", textAlign = "center", paddingHorizontal = 12 } }, dragLabel),
                        ce("Text", { style = { fontSize = 11, color = "#CBD5F5", marginTop = 8 } }, "拖拽距离 X=" .. math.floor(dragPos.x) .. " Y=" .. math.floor(dragPos.y))
                    )
                )
            )
        ),
        ce(Section, { title = "TapGestureHandler - 轻触计数" },
            ce(GestureHandler.TapGestureHandler, {
                maxDist = 12,
                onActivated = handleTap,
            },
                ce("View", {
                    style = {
                        padding = 20,
                        borderRadius = 12,
                        borderWidth = 1,
                        borderColor = T.border,
                        backgroundColor = T.surface,
                        alignItems = "center",
                    }
                },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, "点击我"),
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginTop = 4 } }, "TapGestureHandler.onActivated")
                )
            ),
            ce("Text", { style = { marginTop = 8, fontSize = 14, color = T.textPrimary } }, "累计点击次数：" .. tapCount)
        ),
        ce(Section, { title = "LongPressGestureHandler - 长按操作" },
            ce(GestureHandler.LongPressGestureHandler, {
                minDurationMs = 600,
                maxDist = 12,
                onHandlerStateChange = handleLongPressState,
            },
                ce("View", {
                    style = {
                        padding = 18,
                        borderRadius = 12,
                        borderWidth = 1,
                        borderColor = longPressActive and "#F59E0B" or T.border,
                        backgroundColor = longPressActive and "#FDE68A" or T.surface,
                        alignItems = "center",
                    }
                },
                    ce("Text", { style = { fontSize = 15, color = T.textPrimary } }, longPressActive and "长按已触发" or "按住 0.6 秒触发"),
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginTop = 4 } }, "state=" .. tostring(longPressActive and "ACTIVE" or "待触发"))
                )
            )
        )
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. DropdownDemo — dropdown selector / picker
-- ═══════════════════════════════════════════════════════════════════════════
local function DropdownDemo()
    local selected1, setSelected1 = useState(nil)
    local selected2, setSelected2 = useState(nil)
    local open1, setOpen1 = useState(false)
    local open2, setOpen2 = useState(false)

    local function Dropdown(props)
        local items = props.items or {}
        local value = props.value
        local onSelect = props.onSelect
        local isOpen = props.isOpen
        local onToggle = props.onToggle
        local placeholder = props.placeholder or "Select..."

        local display_text = placeholder
        for _, item in ipairs(items) do
            if item.value == value then display_text = item.label; break end
        end

        local optionRows = {}
        if isOpen then
            for _, item in ipairs(items) do
                local isSelected = item.value == value
                optionRows[#optionRows + 1] = ce(RN.Pressable, {
                    key = item.value,
                    style = {
                        paddingVertical = 10, paddingHorizontal = 14,
                        backgroundColor = isSelected and "rgba(88,166,255,0.15)" or "transparent",
                        borderBottomWidth = 1, borderColor = T.border,
                    },
                    onPress = function()
                        onSelect(item.value)
                        onToggle()
                    end,
                },
                    ce("Text", {
                        style = { fontSize = 14, color = isSelected and T.accent or T.textPrimary },
                    }, (isSelected and "✓ " or "  ") .. item.label)
                )
            end
        end

        return ce("View", { style = { marginBottom = 8 } },
            -- Trigger
            ce(RN.Pressable, {
                style = {
                    flexDirection = "row", alignItems = "center", justifyContent = "space-between",
                    backgroundColor = T.surface, borderWidth = 1,
                    borderColor = isOpen and T.accent or T.border,
                    borderRadius = T.radiusSmall, padding = 12,
                },
                onPress = onToggle,
            },
                ce("Text", {
                    style = { fontSize = 14, color = value and T.textPrimary or T.textSecondary },
                }, display_text),
                ce("Text", { style = { fontSize = 12, color = T.textSecondary } }, isOpen and "▲" or "▼")
            ),
            -- Options
            isOpen and ce("View", {
                style = {
                    backgroundColor = T.surface, borderWidth = 1, borderColor = T.accent,
                    borderRadius = T.radiusSmall, marginTop = 4, overflow = "hidden",
                    maxHeight = 200,
                },
            }, optionRows) or nil
        )
    end

    local languages = {
        { value = "lua", label = "Lua" },
        { value = "js", label = "JavaScript" },
        { value = "py", label = "Python" },
        { value = "rs", label = "Rust" },
        { value = "go", label = "Go" },
        { value = "ts", label = "TypeScript" },
    }

    local colors = {
        { value = "red", label = "Red (#E74C3C)" },
        { value = "blue", label = "Blue (#3498DB)" },
        { value = "green", label = "Green (#2ECC71)" },
        { value = "gold", label = "Gold (#F39C12)" },
    }

    return ce(DemoPage, {},
        ce(Section, { title = "Language" },
            Dropdown({
                items = languages, value = selected1, isOpen = open1,
                placeholder = "Pick a language...",
                onSelect = function(v) setSelected1(v) end,
                onToggle = function() setOpen1(not open1); setOpen2(false) end,
            })
        ),
        ce(Section, { title = "Theme Color" },
            Dropdown({
                items = colors, value = selected2, isOpen = open2,
                placeholder = "Pick a color...",
                onSelect = function(v) setSelected2(v) end,
                onToggle = function() setOpen2(not open2); setOpen1(false) end,
            })
        ),
        ce(Section, { title = "Selected Values" },
            ce("Text", { style = { fontSize = 13, color = T.textPrimary } }, "Language: " .. (selected1 or "none")),
            ce("Text", { style = { fontSize = 13, color = T.textPrimary } }, "Color: " .. (selected2 or "none"))
        )
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. CardDemo — common card layout patterns
-- ═══════════════════════════════════════════════════════════════════════════
local function CardDemo()
    return ce(DemoPage, {},
        ce(Section, { title = "Basic Card" },
            ce("View", {
                style = {
                    backgroundColor = T.surface, borderRadius = T.radius,
                    borderWidth = 1, borderColor = T.border, padding = T.pad,
                },
            },
                ce("Text", { style = { fontSize = 16, fontWeight = "bold", color = T.textPrimary, marginBottom = 4 } }, "Card Title"),
                ce("Text", { style = { fontSize = 13, color = T.textSecondary } }, "This is a basic card with a title and description text. Cards are surface-level containers.")
            )
        ),
        ce(Section, { title = "Card with Header & Actions" },
            ce("View", {
                style = { backgroundColor = T.surface, borderRadius = T.radius, borderWidth = 1, borderColor = T.border, overflow = "hidden" },
            },
                -- Header
                ce("View", { style = { flexDirection = "row", alignItems = "center", padding = T.pad, borderBottomWidth = 1, borderColor = T.border } },
                    ce("View", { style = { width = 36, height = 36, borderRadius = 18, backgroundColor = "#9B59B6", justifyContent = "center", alignItems = "center", marginRight = 10 } },
                        ce("Text", { style = { fontSize = 16, color = "#FFF", fontWeight = "bold" } }, "J")
                    ),
                    ce("View", { style = { flex = 1 } },
                        ce("Text", { style = { fontSize = 14, fontWeight = "bold", color = T.textPrimary } }, "John Doe"),
                        ce("Text", { style = { fontSize = 11, color = T.textSecondary } }, "2 hours ago")
                    )
                ),
                -- Body
                ce("View", { style = { padding = T.pad } },
                    ce("Text", { style = { fontSize = 13, color = T.textSecondary, lineHeight = 20 } },
                        "Just shipped a new update to the React-Solar2D framework. New features include modal overlays, accordion components, and improved animation loops!")
                ),
                -- Actions
                ce("View", { style = { flexDirection = "row", borderTopWidth = 1, borderColor = T.border } },
                    ce(RN.Pressable, { style = { flex = 1, paddingVertical = 10, alignItems = "center" } },
                        ce("Text", { style = { fontSize = 13, color = T.accent } }, "Like")),
                    ce("View", { style = { width = 1, backgroundColor = T.border } }),
                    ce(RN.Pressable, { style = { flex = 1, paddingVertical = 10, alignItems = "center" } },
                        ce("Text", { style = { fontSize = 13, color = T.accent } }, "Comment")),
                    ce("View", { style = { width = 1, backgroundColor = T.border } }),
                    ce(RN.Pressable, { style = { flex = 1, paddingVertical = 10, alignItems = "center" } },
                        ce("Text", { style = { fontSize = 13, color = T.accent } }, "Share"))
                )
            )
        ),
        ce(Section, { title = "Stat Cards (row)" },
            ce("View", { style = { flexDirection = "row", gap = 8 } },
                ce("View", { style = { flex = 1, backgroundColor = T.surface, borderRadius = T.radiusSmall, padding = 12, borderWidth = 1, borderColor = T.border, alignItems = "center" } },
                    ce("Text", { style = { fontSize = 22, fontWeight = "bold", color = "#2ECC71" } }, "128"),
                    ce("Text", { style = { fontSize = 11, color = T.textSecondary } }, "Users")
                ),
                ce("View", { style = { flex = 1, backgroundColor = T.surface, borderRadius = T.radiusSmall, padding = 12, borderWidth = 1, borderColor = T.border, alignItems = "center" } },
                    ce("Text", { style = { fontSize = 22, fontWeight = "bold", color = T.accent } }, "47"),
                    ce("Text", { style = { fontSize = 11, color = T.textSecondary } }, "Active")
                ),
                ce("View", { style = { flex = 1, backgroundColor = T.surface, borderRadius = T.radiusSmall, padding = 12, borderWidth = 1, borderColor = T.border, alignItems = "center" } },
                    ce("Text", { style = { fontSize = 22, fontWeight = "bold", color = "#E74C3C" } }, "3"),
                    ce("Text", { style = { fontSize = 11, color = T.textSecondary } }, "Errors")
                )
            )
        ),
        ce(Section, { title = "List Card" },
            ce("View", {
                style = { backgroundColor = T.surface, borderRadius = T.radius, borderWidth = 1, borderColor = T.border, overflow = "hidden" },
            },
                ce("View", { style = { padding = 12, borderBottomWidth = 1, borderColor = T.border } },
                    ce("Text", { style = { fontSize = 14, fontWeight = "bold", color = T.textPrimary } }, "Recent Activity")),
                ce(RN.Pressable, { style = { flexDirection = "row", padding = 12, borderBottomWidth = 1, borderColor = T.border, alignItems = "center" } },
                    ce("View", { style = { width = 8, height = 8, borderRadius = 4, backgroundColor = "#2ECC71", marginRight = 10 } }),
                    ce("Text", { style = { fontSize = 13, color = T.textPrimary, flex = 1 } }, "Build succeeded"),
                    ce("Text", { style = { fontSize = 11, color = T.textSecondary } }, "2m ago")
                ),
                ce(RN.Pressable, { style = { flexDirection = "row", padding = 12, borderBottomWidth = 1, borderColor = T.border, alignItems = "center" } },
                    ce("View", { style = { width = 8, height = 8, borderRadius = 4, backgroundColor = "#F39C12", marginRight = 10 } }),
                    ce("Text", { style = { fontSize = 13, color = T.textPrimary, flex = 1 } }, "Test warning"),
                    ce("Text", { style = { fontSize = 11, color = T.textSecondary } }, "15m ago")
                ),
                ce(RN.Pressable, { style = { flexDirection = "row", padding = 12, alignItems = "center" } },
                    ce("View", { style = { width = 8, height = 8, borderRadius = 4, backgroundColor = "#E74C3C", marginRight = 10 } }),
                    ce("Text", { style = { fontSize = 13, color = T.textPrimary, flex = 1 } }, "Deploy failed"),
                    ce("Text", { style = { fontSize = 11, color = T.textSecondary } }, "1h ago")
                )
            )
        )
    )
end

return {
    { name = "Badge",     component = BadgeDemo,     description = "Number badges, status tags, chips",       icon = "B" },
    { name = "Progress",  component = ProgressDemo,  description = "Progress bars, auto-animate, sizes",      icon = "P" },
    { name = "Accordion", component = AccordionDemo, description = "Collapsible FAQ sections, expand/collapse", icon = "A" },
    { name = "Dropdown",  component = DropdownDemo,  description = "Dropdown selector/picker component",      icon = "D" },
    { name = "Card",      component = CardDemo,      description = "Card layouts, social, stats, list",        icon = "C" },
    { name = "Gesture Handler", component = GestureDemo, description = "Pan/Tap/LongPress 手势示例", icon = "G" },
}
