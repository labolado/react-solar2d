--- ImageBackground component.
-- Image as background with children rendered on top (like RN ImageBackground).
-- @module components.ImageBackground

local React = require("react")
local createElement = React.createElement

--- ImageBackground component.
-- @param props table {source, resizeMode, imageStyle, style, children}
-- @return table React element
local function ImageBackground(props)
    local source = props.source
    local resizeMode = props.resizeMode or props.imageStyle and props.imageStyle.resizeMode or "cover"
    local style = props.style or {}

    -- Image fills the entire container
    local imageStyle = {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        width = style.width,
        height = style.height,
        borderRadius = style.borderRadius,
        resizeMode = resizeMode,
    }
    -- Merge user imageStyle overrides
    if props.imageStyle then
        for k, v in pairs(props.imageStyle) do
            imageStyle[k] = v
        end
    end

    local children = {}
    -- Background image
    children[1] = createElement("Image", {
        key = "__bg_image",
        source = source,
        resizeMode = resizeMode,
        style = imageStyle,
    })
    -- Overlay children
    if props.children then
        if type(props.children) == "table" and props.children[1] then
            for i, child in ipairs(props.children) do
                children[#children + 1] = child
            end
        else
            children[#children + 1] = props.children
        end
    end

    return createElement("View", { style = style }, children)
end

return ImageBackground
