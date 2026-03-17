-- examples/kitchen_sink/InteropScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")

local function ReactInSolar2DDemo(props)
    return ce("View", { style = { flex = 1 } }, 
        ce("Text", {}, "ReactInSolar Demo"))
end

local function Solar2DInReactDemo()
    return ce("View", {}, ce("Text", {}, "Solar2D Demo"))
end

local AsyncStorage = require("lib.async-storage")

local function AsyncStorageDemo()
    local storageKey, setStorageKey = useState("")
    
    local function handleSetItem()
        if storageKey ~= "" then
            AsyncStorage.setItem(storageKey, "value")
        end
    end
    
    return ce("ScrollView", {
        style = { flex = 1, backgroundColor = T.bg },
        contentContainerStyle = { padding = T.pad },
    },
        ce("Text", { style = { fontSize = 14, color = T.accent } },
            "@react-native-async-storage/async-storage"),
        ce(RN.TextInput, {
            style = { backgroundColor = T.surface, padding = 8 },
            value = storageKey,
            onChangeText = setStorageKey,
            placeholder = "Enter key...",
        }),
        ce(RN.Button, { title = "Set Item", color = T.accent, onPress = handleSetItem })
    )
end

return {
    { name = "ReactInSolar", component = ReactInSolar2DDemo, description = "Native code hosts React subtree", icon = "R" },
    { name = "Solar2DInReact", component = Solar2DInReactDemo, description = "React layout with native canvas", icon = "S" },
    { name = "AsyncStorage", component = AsyncStorageDemo, description = "Local storage", icon = "A" },
}
