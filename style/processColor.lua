--- processColor module.
-- Converts color strings and tables into normalized {r,g,b,a} tables.
-- @module style.processColor

local namedColors = {
    transparent = {0, 0, 0, 0},
    black = {0, 0, 0, 1}, white = {1, 1, 1, 1},
    red = {1, 0, 0, 1}, green = {0, 0.502, 0, 1}, blue = {0, 0, 1, 1},
    yellow = {1, 1, 0, 1}, cyan = {0, 1, 1, 1}, magenta = {1, 0, 1, 1},
    orange = {1, 0.647, 0, 1}, purple = {0.502, 0, 0.502, 1},
    pink = {1, 0.753, 0.796, 1}, brown = {0.647, 0.165, 0.165, 1},
    gray = {0.502, 0.502, 0.502, 1}, grey = {0.502, 0.502, 0.502, 1},
    lightgray = {0.827, 0.827, 0.827, 1}, darkgray = {0.663, 0.663, 0.663, 1},
    tomato = {1, 0.388, 0.278, 1}, coral = {1, 0.498, 0.314, 1},
    salmon = {0.980, 0.502, 0.447, 1}, gold = {1, 0.843, 0, 1},
    skyblue = {0.529, 0.808, 0.922, 1}, steelblue = {0.275, 0.510, 0.706, 1},
    dodgerblue = {0.118, 0.565, 1, 1}, navy = {0, 0, 0.502, 1},
    teal = {0, 0.502, 0.502, 1}, indigo = {0.294, 0, 0.510, 1},
}

--- Process a color value into a normalized {r,g,b,a} table.
-- @param color string|table|number|nil Color value
-- @return table|nil Normalized color table
local function processColor(color)
    if color == nil then return nil end
    if type(color) == "table" then return color end
    if type(color) == "number" then return {color, color, color, 1} end
    if type(color) ~= "string" then return {1, 1, 1, 1} end

    -- Named color
    local named = namedColors[color:lower()]
    if named then return {named[1], named[2], named[3], named[4]} end

    -- #RGB
    if color:match("^#%x%x%x$") then
        local r = tonumber(color:sub(2, 2), 16) / 15
        local g = tonumber(color:sub(3, 3), 16) / 15
        local b = tonumber(color:sub(4, 4), 16) / 15
        return {r, g, b, 1}
    end

    -- #RRGGBB
    if color:match("^#%x%x%x%x%x%x$") then
        local r = tonumber(color:sub(2, 3), 16) / 255
        local g = tonumber(color:sub(4, 5), 16) / 255
        local b = tonumber(color:sub(6, 7), 16) / 255
        return {r, g, b, 1}
    end

    -- #RRGGBBAA
    if color:match("^#%x%x%x%x%x%x%x%x$") then
        local r = tonumber(color:sub(2, 3), 16) / 255
        local g = tonumber(color:sub(4, 5), 16) / 255
        local b = tonumber(color:sub(6, 7), 16) / 255
        local a = tonumber(color:sub(8, 9), 16) / 255
        return {r, g, b, a}
    end

    -- rgba(r, g, b, a)
    local r, g, b, a = color:match("rgba%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*([%d%.]+)%s*%)")
    if r then
        return {tonumber(r) / 255, tonumber(g) / 255, tonumber(b) / 255, tonumber(a)}
    end

    -- rgb(r, g, b)
    r, g, b = color:match("rgb%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)")
    if r then
        return {tonumber(r) / 255, tonumber(g) / 255, tonumber(b) / 255, 1}
    end

    return {1, 1, 1, 1}
end

return processColor
