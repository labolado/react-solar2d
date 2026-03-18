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
    local storageValue, setStorageValue = useState("")
    local retrievedValue, setRetrievedValue = useState("")

    local function handleSetItem()
        if storageKey ~= "" then
            AsyncStorage.setItem(storageKey, storageValue, function()
                print("Saved: " .. storageKey .. " = " .. storageValue)
            end)
        end
    end

    local function handleGetItem()
        if storageKey ~= "" then
            AsyncStorage.getItem(storageKey, function(err, value)
                setRetrievedValue(value or "(nil)")
            end)
        end
    end

    return ce("ScrollView", {
        style = { flex = 1, backgroundColor = T.bg },
        contentContainerStyle = { padding = T.pad },
    },
        ce("Text", { style = { fontSize = 14, color = T.accent, marginBottom = 8 } },
            "@react-native-async-storage/async-storage"),
        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } }, "Key:"),
        ce(RN.TextInput, {
            style = { backgroundColor = T.surface, padding = 8, marginBottom = 8 },
            value = storageKey,
            onChangeText = setStorageKey,
            placeholder = "Enter key...",
        }),
        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } }, "Value:"),
        ce(RN.TextInput, {
            style = { backgroundColor = T.surface, padding = 8, marginBottom = 8 },
            value = storageValue,
            onChangeText = setStorageValue,
            placeholder = "Enter value...",
        }),
        ce("View", { style = { flexDirection = "row", gap = 8, marginBottom = 16 } },
            ce(RN.Button, { title = "Set Item", color = T.accent, onPress = handleSetItem }),
            ce(RN.Button, { title = "Get Item", color = T.accent, onPress = handleGetItem })
        ),
        ce("Text", { style = { fontSize = 12, color = T.textSecondary } }, "Retrieved:"),
        ce("Text", { style = { fontSize = 14, color = T.text } }, retrievedValue)
    )
end

-- Vector Icons Demo
local VectorIcons = require("lib.vector-icons")

local function VectorIconsDemo()
    local IconSize = 32
    local IconColor = T.accent

    return ce("ScrollView", {
        style = { flex = 1, backgroundColor = T.bg },
        contentContainerStyle = { padding = T.pad },
    },
        ce("Text", { style = { fontSize = 14, color = T.accent, marginBottom = 8 } },
            "react-native-vector-icons"),
        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 12 } },
            "MaterialIcons, FontAwesome, Ionicons"),

        -- MaterialIcons
        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 8 } }, "MaterialIcons:"),
        ce("View", { style = { flexDirection = "row", flexWrap = "wrap", gap = 16, marginBottom = 16 } },
            ce(VectorIcons.MaterialIcons, { name = "home", size = IconSize, color = IconColor }),
            ce(VectorIcons.MaterialIcons, { name = "settings", size = IconSize, color = IconColor }),
            ce(VectorIcons.MaterialIcons, { name = "person", size = IconSize, color = IconColor }),
            ce(VectorIcons.MaterialIcons, { name = "search", size = IconSize, color = IconColor }),
            ce(VectorIcons.MaterialIcons, { name = "favorite", size = IconSize, color = "#FF0000" }),
            ce(VectorIcons.MaterialIcons, { name = "star", size = IconSize, color = "#FFD700" }),
            ce(VectorIcons.MaterialIcons, { name = "check", size = IconSize, color = "#00AA00" }),
            ce(VectorIcons.MaterialIcons, { name = "close", size = IconSize, color = "#AA0000" })
        ),

        -- FontAwesome
        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 8 } }, "FontAwesome:"),
        ce("View", { style = { flexDirection = "row", flexWrap = "wrap", gap = 16, marginBottom = 16 } },
            ce(VectorIcons.FontAwesome, { name = "home", size = IconSize, color = IconColor }),
            ce(VectorIcons.FontAwesome, { name = "heart", size = IconSize, color = "#FF0000" }),
            ce(VectorIcons.FontAwesome, { name = "star2", size = IconSize, color = "#FFD700" }),
            ce(VectorIcons.FontAwesome, { name = "github", size = IconSize, color = IconColor }),
            ce(VectorIcons.FontAwesome, { name = "twitter", size = IconSize, color = "#1DA1F2" }),
            ce(VectorIcons.FontAwesome, { name = "envelope", size = IconSize, color = IconColor })
        ),

        -- Ionicons
        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 8 } }, "Ionicons:"),
        ce("View", { style = { flexDirection = "row", flexWrap = "wrap", gap = 16 } },
            ce(VectorIcons.Ionicons, { name = "home", size = IconSize, color = IconColor }),
            ce(VectorIcons.Ionicons, { name = "heart", size = IconSize, color = "#FF0000" }),
            ce(VectorIcons.Ionicons, { name = "star", size = IconSize, color = "#FFD700" }),
            ce(VectorIcons.Ionicons, { name = "notifications", size = IconSize, color = IconColor }),
            ce(VectorIcons.Ionicons, { name = "mail", size = IconSize, color = IconColor }),
            ce(VectorIcons.Ionicons, { name = "camera", size = IconSize, color = IconColor })
        )
    )
end

-- Slider Demo
local Slider = require("lib.slider")

local function SliderDemo()
    local value1, setValue1 = useState(0.5)
    local value2, setValue2 = useState(50)
    local value3, setValue3 = useState(10)

    return ce("ScrollView", {
        style = { flex = 1, backgroundColor = T.bg },
        contentContainerStyle = { padding = T.pad },
    },
        ce("Text", { style = { fontSize = 14, color = T.accent, marginBottom = 8 } },
            "@react-native-community/slider"),

        -- Basic slider
        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } },
            "Basic (0-1): " .. string.format("%.2f", value1)),
        ce(Slider.Slider, {
            value = value1,
            onValueChange = setValue1,
            style = { width = 280, marginBottom = 16 },
        }),

        -- Slider with range 0-100
        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } },
            "Range 0-100: " .. math.floor(value2)),
        ce(Slider.Slider, {
            value = value2,
            minimumValue = 0,
            maximumValue = 100,
            step = 1,
            onValueChange = setValue2,
            minimumTrackTintColor = T.accent,
            style = { width = 280, marginBottom = 16 },
        }),

        -- Slider with step
        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } },
            "With step (0-20, step=2): " .. math.floor(value3)),
        ce(Slider.Slider, {
            value = value3,
            minimumValue = 0,
            maximumValue = 20,
            step = 2,
            onValueChange = setValue3,
            minimumTrackTintColor = "#00AA00",
            thumbTintColor = "#FFFFFF",
            style = { width = 280 },
        })
    )
end

-- Device Info Demo
local DeviceInfo = require("lib.device-info")

local function DeviceInfoDemo()
    local info = DeviceInfo.getAllInfo()

    local function InfoRow(label, value)
        return ce("View", { style = { flexDirection = "row", marginBottom = 6 } },
            ce("Text", { style = { fontSize = 11, color = T.textSecondary, width = 100 } }, label),
            ce("Text", { style = { fontSize = 11, color = T.text, flex = 1 } }, tostring(value))
        )
    end

    return ce("ScrollView", {
        style = { flex = 1, backgroundColor = T.bg },
        contentContainerStyle = { padding = T.pad },
    },
        ce("Text", { style = { fontSize = 14, color = T.accent, marginBottom = 12 } },
            "react-native-device-info"),

        InfoRow("Brand:", info.brand),
        InfoRow("Model:", info.model),
        InfoRow("System:", info.systemName .. " " .. info.systemVersion),
        InfoRow("Version:", info.version .. " (" .. info.buildNumber .. ")"),
        InfoRow("Bundle ID:", info.bundleId),
        InfoRow("Locale:", info.locale),
        InfoRow("Timezone:", info.timezone),
        InfoRow("Screen:", info.screenWidth .. " x " .. info.screenHeight),
        InfoRow("Tablet:", info.isTablet and "Yes" or "No"),
        InfoRow("Emulator:", info.isEmulator and "Yes" or "No"),
        InfoRow("Memory:", string.format("%.0f KB", info.usedMemory / 1024))
    )
end

-- DateTime Picker Demo
local DateTimePicker = require("lib.datetime-picker")

local function DateTimePickerDemo()
    local date, setDate = useState(os.time())
    local time, setTime = useState(os.time())

    local function handleDateChange(event)
        if event.type == DateTimePicker.EventType.SET then
            setDate(event.nativeEvent.timestamp)
        end
    end

    local function handleTimeChange(event)
        if event.type == DateTimePicker.EventType.SET then
            setTime(event.nativeEvent.timestamp)
        end
    end

    return ce("ScrollView", {
        style = { flex = 1, backgroundColor = T.bg },
        contentContainerStyle = { padding = T.pad },
    },
        ce("Text", { style = { fontSize = 14, color = T.accent, marginBottom = 12 } },
            "@react-native-community/datetimepicker"),

        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 8 } }, "Date:"),
        ce(DateTimePicker.DateTimePicker, {
            value = date,
            mode = "date",
            onChange = handleDateChange,
            style = { marginBottom = 16 },
        }),

        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 8 } }, "Time:"),
        ce(DateTimePicker.DateTimePicker, {
            value = time,
            mode = "time",
            onChange = handleTimeChange,
        })
    )
end

return {
    { name = "ReactInSolar", component = ReactInSolar2DDemo, description = "Native code hosts React subtree", icon = "R" },
    { name = "Solar2DInReact", component = Solar2DInReactDemo, description = "React layout with native canvas", icon = "S" },
    { name = "AsyncStorage", component = AsyncStorageDemo, description = "Local storage", icon = "A" },
    { name = "VectorIcons", component = VectorIconsDemo, description = "Material/FontAwesome/Ionicons icons", icon = "V" },
    { name = "Slider", component = SliderDemo, description = "Slider component", icon = "S" },
    { name = "DeviceInfo", component = DeviceInfoDemo, description = "Device information", icon = "D" },
    { name = "DateTimePicker", component = DateTimePickerDemo, description = "Date/time picker", icon = "T" },
}
