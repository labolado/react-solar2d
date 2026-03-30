--- Header module.
-- Default stack navigator header: [Back] [Title] [Right].
-- @module navigation.Header

local React = require("react")
local ce = React.createElement

--- Header component.
-- @param props table {options, navigation, route, canGoBack}
-- @return table React element
local function Header(props)
    local options = props.options or {}
    local navigation = props.navigation
    local route = props.route
    local canGoBack = props.canGoBack or false

    if options.headerShown == false then
        return ce("View", { style = { height = 0 } })
    end

    if options.header then
        return options.header({
            navigation = navigation,
            route = route,
            options = options,
        })
    end

    local headerStyle = options.headerStyle or {}
    local bgColor = headerStyle.backgroundColor or "#FFFFFF"
    local headerHeight = headerStyle.height or 56
    local tintColor = options.headerTintColor or "#000000"
    local titleAlign = options.headerTitleAlign or "center"
    local title = options.title or route.name
    local titleStyle = options.headerTitleStyle or {}

    local headerChildren = {}

    -- Left: back button or custom
    if options.headerLeft then
        headerChildren[#headerChildren + 1] = ce("View", { key = "left" },
            options.headerLeft({ onPress = function() navigation.goBack() end }))
    elseif canGoBack then
        headerChildren[#headerChildren + 1] = ce("View", {
            key = "left",
            onPress = function() navigation.goBack() end,
            style = { width = 60, height = headerHeight, justifyContent = "center" },
        },
            ce("Text", { style = { color = tintColor, fontSize = 16 } }, "< Back"))
    end

    -- Title
    headerChildren[#headerChildren + 1] = ce("View", {
        key = "title",
        style = {
            flex = 1,
            justifyContent = "center",
            alignItems = titleAlign == "center" and "center" or "flex-start",
            height = headerHeight,
        },
    },
        ce("Text", {
            style = {
                color = tintColor,
                fontSize = titleStyle.fontSize or 18,
                fontWeight = titleStyle.fontWeight or "bold",
            },
        }, title))

    -- Right
    if options.headerRight then
        headerChildren[#headerChildren + 1] = ce("View", { key = "right" },
            options.headerRight({ navigation = navigation }))
    end

    return ce("View", {
        key = "__header",
        style = {
            height = headerHeight,
            backgroundColor = bgColor,
            flexDirection = "row",
            alignItems = "center",
            width = display and display.contentWidth or 320,
        },
    }, headerChildren)
end

return Header
