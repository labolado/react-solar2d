-- style/StyleSheet.lua
local M = {}

local nextId = 0

function M.create(styles)
    local result = {}
    for name, style in pairs(styles) do
        nextId = nextId + 1
        style._id = nextId
        result[name] = style
    end
    return result
end

function M.flatten(style)
    if style == nil or style == false then return {} end
    if type(style) ~= "table" then return {} end

    if style[1] ~= nil or #style > 0 then
        if type(style[1]) == "table" then
            local result = {}
            for i = 1, #style do
                local s = style[i]
                if s then
                    local flat = M.flatten(s)
                    for k, v in pairs(flat) do
                        result[k] = v
                    end
                end
            end
            return result
        end
    end

    local result = {}
    for k, v in pairs(style) do
        result[k] = v
    end
    return result
end

function M.compose(style1, style2)
    if style1 and style2 then
        return {style1, style2}
    end
    return style1 or style2 or {}
end

M.hairlineWidth = 1
M.absoluteFill = { position = "absolute", left = 0, right = 0, top = 0, bottom = 0 }
M.absoluteFillObject = M.absoluteFill

return M
