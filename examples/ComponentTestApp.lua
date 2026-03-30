-- examples/ComponentTestApp.lua
-- Component audit test app - validates all components render correctly
local React = require("react")
local ce = React.createElement
local useState = React.useState
local RN = require("react_solar2d")
local LinearGradient = require("lib.linear-gradient")

local W = display.contentWidth
local H = display.contentHeight

-- Test result tracking
local testResults = {}

local function recordTest(name, success, details)
    table.insert(testResults, { name = name, success = success, details = details })
    print(string.format("[TEST] %s: %s", name, success and "PASS" or "FAIL"))
    if details then print("       " .. details) end
end

-- 1. View Test
local function ViewTest()
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "View Component Test"),
        ce("View", { 
            style = { 
                width = 100, 
                height = 100, 
                backgroundColor = "#FF6B6B",
                borderRadius = 10,
                borderWidth = 2,
                borderColor = "#000000"
            } 
        }),
        ce("Text", { style = { fontSize = 12, color = "#666", marginTop = 5 } }, "Should see red rounded square with black border")
    )
end

-- 2. Text Test  
local function TextTest()
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "Text Component Test"),
        ce("Text", { style = { fontSize = 24, color = "#2196F3" } }, "Blue Large Text"),
        ce("Text", { style = { fontSize = 16, color = "#4CAF50", fontWeight = "bold" } }, "Bold Green Text"),
        ce("Text", { style = { fontSize = 14, color = "#FF5722", opacity = 0.7 } }, "Semi-transparent Orange")
    )
end

-- 3. Image Test
local function ImageTest()
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "Image Component Test"),
        ce("Text", { style = { fontSize = 12, color = "#666" } }, "Below should show placeholder (no image file):")
    )
end

-- 4. Button Test
local function ButtonTest()
    local count, setCount = useState(0)
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "Button Component Test"),
        ce("Text", { style = { fontSize = 16 } }, "Count: " .. count),
        ce(RN.Button, {
            title = "Tap Me",
            color = "#2196F3",
            onPress = function() 
                setCount(function(c) return c + 1 end)
                print("[TEST] Button pressed")
            end
        })
    )
end

-- 5. Pressable Test
local function PressableTest()
    local msg, setMsg = useState("Tap the box below")
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "Pressable Component Test"),
        ce("Text", { style = { fontSize = 14 } }, msg),
        ce(RN.Pressable, {
            style = {
                width = 150,
                height = 60,
                backgroundColor = "#9C27B0",
                borderRadius = 8,
                justifyContent = "center",
                alignItems = "center",
                marginTop = 10
            },
            onPress = function()
                setMsg("Pressed!")
                print("[TEST] Pressable pressed")
            end
        }, ce("Text", { style = { color = "#FFF", fontSize = 16 } }, "Pressable"))
    )
end

-- 6. TouchableOpacity Test
local function TouchableOpacityTest()
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "TouchableOpacity Test"),
        ce(RN.TouchableOpacity, {
            style = {
                backgroundColor = "#FF9800",
                padding = 20,
                borderRadius = 8
            },
            onPress = function() print("[TEST] TouchableOpacity pressed") end
        }, ce("Text", { style = { color = "#FFF" } }, "TouchableOpacity (should fade on press)"))
    )
end

-- 7. ScrollView Test
local function ScrollViewTest()
    local items = {}
    for i = 1, 50 do
        items[i] = ce("View", {
            key = tostring(i),
            style = {
                height = 50,
                backgroundColor = i % 2 == 0 and "#E3F2FD" or "#BBDEFB",
                justifyContent = "center",
                paddingLeft = 10
            }
        }, ce("Text", {}, "Item " .. i))
    end
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "ScrollView Test"),
        ce("ScrollView", { style = { flex = 1, backgroundColor = "#F5F5F5" } }, items)
    )
end

-- 8. FlatList Test
local function FlatListTest()
    local data = {}
    for i = 1, 100 do
        data[i] = { id = i, title = "Item " .. i }
    end
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "FlatList Test"),
        ce(RN.FlatList, {
            data = data,
            keyExtractor = function(item) return tostring(item.id) end,
            renderItem = function(info)
                return ce("View", {
                    style = {
                        height = 50,
                        backgroundColor = info.index % 2 == 0 and "#E8F5E9" or "#C8E6C9",
                        justifyContent = "center",
                        paddingLeft = 10
                    }
                }, ce("Text", {}, info.item.title))
            end
        })
    )
end

-- 9. SectionList Test
local function SectionListTest()
    local sections = {
        { title = "Section A", data = {{ name = "A1" }, { name = "A2" }, { name = "A3" }} },
        { title = "Section B", data = {{ name = "B1" }, { name = "B2" }} },
        { title = "Section C", data = {{ name = "C1" }, { name = "C2" }, { name = "C3" }, { name = "C4" }} },
    }
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "SectionList Test"),
        ce(RN.SectionList, {
            sections = sections,
            keyExtractor = function(item, index) return item.name end,
            renderSectionHeader = function(info)
                return ce("View", {
                    style = {
                        backgroundColor = "#1976D2",
                        padding = 10
                    }
                }, ce("Text", { style = { color = "#FFF", fontWeight = "bold" } }, info.section.title))
            end,
            renderItem = function(info)
                return ce("View", {
                    style = {
                        padding = 15,
                        backgroundColor = "#FFF",
                        borderBottomWidth = 1,
                        borderBottomColor = "#EEE"
                    }
                }, ce("Text", {}, info.item.name))
            end
        })
    )
end

-- 10. TextInput Test
local function TextInputTest()
    local text, setText = useState("")
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "TextInput Test"),
        ce("TextInput", {
            style = {
                height = 50,
                borderWidth = 1,
                borderColor = "#CCC",
                borderRadius = 8,
                paddingHorizontal = 10,
                backgroundColor = "#FFF"
            },
            placeholder = "Type here...",
            value = text,
            onChangeText = function(t) setText(t) end
        }),
        ce("Text", { style = { marginTop = 10 } }, "You typed: " .. text)
    )
end

-- 11. Switch Test
local function SwitchTest()
    local on, setOn = useState(false)
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "Switch Test"),
        ce("View", { style = { flexDirection = "row", alignItems = "center" } },
            ce(RN.Switch, {
                value = on,
                onValueChange = function(v) setOn(v) end
            }),
            ce("Text", { style = { marginLeft = 10 } }, on and "ON" or "OFF")
        )
    )
end

-- 12. Modal Test
local function ModalTest()
    local visible, setVisible = useState(false)
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "Modal Test"),
        ce(RN.Button, {
            title = "Show Modal",
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
                    backgroundColor = "#FFF",
                    borderRadius = 12,
                    padding = 20,
                    justifyContent = "center",
                    alignItems = "center"
                }
            },
                ce("Text", { style = { fontSize = 18, marginBottom = 20 } }, "This is a Modal"),
                ce(RN.Button, {
                    title = "Close",
                    onPress = function() setVisible(false) end
                })
            )
        )
    )
end

-- 13. ActivityIndicator Test
local function ActivityIndicatorTest()
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "ActivityIndicator Test"),
        ce("View", { style = { flexDirection = "row", gap = 20 } },
            ce(RN.ActivityIndicator, { size = "small", color = "#2196F3" }),
            ce(RN.ActivityIndicator, { size = "large", color = "#4CAF50" }),
            ce(RN.ActivityIndicator, { size = 60, color = "#FF5722" })
        )
    )
end

-- 14. RefreshControl Test (integrated with ScrollView)
local function RefreshControlTest()
    local refreshing, setRefreshing = useState(false)
    
    local function onRefresh()
        setRefreshing(true)
        timer.performWithDelay(2000, function()
            setRefreshing(false)
        end)
    end
    
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "RefreshControl Test"),
        ce("Text", { style = { fontSize = 12, color = "#666", marginBottom = 10 } }, "Pull down to refresh"),
        ce("ScrollView", {
            style = { flex = 1 },
            refreshing = refreshing,
            onRefresh = onRefresh
        },
            ce("View", { style = { padding = 20 } },
                ce(RN.RefreshControl, {
                    refreshing = refreshing,
                    onRefresh = onRefresh,
                    tintColor = "#2196F3",
                    title = "Loading..."
                }),
                ce("Text", {}, "Scroll content here")
            )
        )
    )
end

-- 15. KeyboardAvoidingView Test
local function KeyboardAvoidingViewTest()
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "KeyboardAvoidingView Test"),
        ce(RN.KeyboardAvoidingView, {
            style = { flex = 1 },
            behavior = "padding"
        },
            ce("Text", {}, "Tap text input below, keyboard should push view up"),
            ce("TextInput", {
                style = {
                    height = 50,
                    borderWidth = 1,
                    borderColor = "#CCC",
                    marginTop = 20
                },
                placeholder = "Tap me"
            })
        )
    )
end

-- 16. SafeAreaView Test
local function SafeAreaViewTest()
    return ce(RN.SafeAreaView, { style = { flex = 1, backgroundColor = "#E3F2FD" } },
        ce("View", { style = { padding = 20 } },
            ce("Text", { style = { fontSize = 18, fontWeight = "bold" } }, "SafeAreaView Test"),
            ce("Text", {}, "Content should be within safe area (not under notch/status bar)")
        )
    )
end

-- 17. LinearGradient Test
local function LinearGradientTest()
    return ce("View", { style = { flex = 1, padding = 20 } },
        ce("Text", { style = { fontSize = 18, fontWeight = "bold", marginBottom = 10 } }, "LinearGradient Test"),
        
        -- Test 1: Basic 2-color gradient
        ce("Text", { style = { fontSize = 14, marginBottom = 5 } }, "2-color gradient:"),
        ce(LinearGradient, {
            colors = { "#FF6B6B", "#4ECDC4" },
            style = { width = 300, height = 80, borderRadius = 8, marginBottom = 15 }
        }, ce("Text", { style = { color = "#FFF", textAlign = "center" } }, "2-Color Gradient")),
        
        -- Test 2: 3-color gradient
        ce("Text", { style = { fontSize = 14, marginBottom = 5 } }, "3-color gradient:"),
        ce(LinearGradient, {
            colors = { "#667EEA", "#764BA2", "#F093FB" },
            start = { x = 0, y = 0 },
            ["end"] = { x = 1, y = 1 },
            style = { width = 300, height = 80, borderRadius = 8, marginBottom = 15 }
        }, ce("Text", { style = { color = "#FFF", textAlign = "center" } }, "3-Color Gradient")),
        
        -- Test 3: Horizontal gradient
        ce("Text", { style = { fontSize = 14, marginBottom = 5 } }, "Horizontal gradient:"),
        ce(LinearGradient, {
            colors = { "#FA709A", "#FEE140" },
            start = { x = 0, y = 0.5 },
            ["end"] = { x = 1, y = 0.5 },
            style = { width = 300, height = 80, borderRadius = 8, marginBottom = 15 }
        }, ce("Text", { style = { color = "#FFF", textAlign = "center" } }, "Horizontal Gradient")),
        
        -- Test 4: With border
        ce("Text", { style = { fontSize = 14, marginBottom = 5 } }, "With border:"),
        ce(LinearGradient, {
            colors = { "#30CFD0", "#330867" },
            style = { 
                width = 300, 
                height = 80, 
                borderRadius = 20,
                borderWidth = 3,
                borderColor = "#FFD700"
            }
        }, ce("Text", { style = { color = "#FFF", textAlign = "center" } }, "Border + Gradient"))
    )
end

-- Main test navigator
local TESTS = {
    { name = "View", component = ViewTest },
    { name = "Text", component = TextTest },
    { name = "Image", component = ImageTest },
    { name = "Button", component = ButtonTest },
    { name = "Pressable", component = PressableTest },
    { name = "TouchableOpacity", component = TouchableOpacityTest },
    { name = "ScrollView", component = ScrollViewTest },
    { name = "FlatList", component = FlatListTest },
    { name = "SectionList", component = SectionListTest },
    { name = "TextInput", component = TextInputTest },
    { name = "Switch", component = SwitchTest },
    { name = "Modal", component = ModalTest },
    { name = "ActivityIndicator", component = ActivityIndicatorTest },
    { name = "RefreshControl", component = RefreshControlTest },
    { name = "KeyboardAvoidingView", component = KeyboardAvoidingViewTest },
    { name = "SafeAreaView", component = SafeAreaViewTest },
    { name = "LinearGradient", component = LinearGradientTest },
}

local function ComponentTestApp()
    local currentTest, setCurrentTest = useState(1)
    local CurrentComponent = TESTS[currentTest].component
    
    -- Navigation buttons
    local navButtons = {}
    for i, test in ipairs(TESTS) do
        navButtons[i] = ce(RN.Pressable, {
            key = test.name,
            style = {
                paddingHorizontal = 12,
                paddingVertical = 8,
                backgroundColor = i == currentTest and "#2196F3" or "#E0E0E0",
                borderRadius = 4,
                marginRight = 8,
                marginBottom = 8
            },
            onPress = function() setCurrentTest(i) end
        }, ce("Text", { 
            style = { 
                color = i == currentTest and "#FFF" or "#333",
                fontSize = 12
            } 
        }, test.name))
    end
    
    return ce("View", { style = { flex = 1, backgroundColor = "#F5F5F5" } },
        -- Header
        ce("View", { 
            style = { 
                backgroundColor = "#1976D2",
                paddingTop = 40,
                paddingHorizontal = 15,
                paddingBottom = 10
            } 
        },
            ce("Text", { style = { color = "#FFF", fontSize = 20, fontWeight = "bold" } }, 
                "Component Test: " .. TESTS[currentTest].name)
        ),
        
        -- Navigation bar
        ce("ScrollView", { 
            style = { maxHeight = 120 },
            horizontal = true,
            contentContainerStyle = { padding = 10, flexDirection = "row", flexWrap = "wrap" }
        }, navButtons),
        
        -- Test content
        ce("View", { style = { flex = 1 } },
            ce(CurrentComponent)
        )
    )
end

return ComponentTestApp
