-- renderer/HostConfig.lua
local M = {}

local function parseColor(color)
    if type(color) == "table" then return color end
    if type(color) ~= "string" then return {1, 1, 1, 1} end

    if color:sub(1, 1) == "#" then
        local hex = color:sub(2)
        local r = tonumber(hex:sub(1, 2), 16) / 255
        local g = tonumber(hex:sub(3, 4), 16) / 255
        local b = tonumber(hex:sub(5, 6), 16) / 255
        local a = #hex >= 8 and (tonumber(hex:sub(7, 8), 16) / 255) or 1
        return {r, g, b, a}
    end

    local named = {
        red = {1, 0, 0, 1}, green = {0, 0.5, 0, 1}, blue = {0, 0, 1, 1},
        white = {1, 1, 1, 1}, black = {0, 0, 0, 1}, transparent = {0, 0, 0, 0},
        gray = {0.5, 0.5, 0.5, 1}, yellow = {1, 1, 0, 1}, orange = {1, 0.65, 0, 1},
    }
    return named[color:lower()] or {1, 1, 1, 1}
end

local function wireEvents(instance, props)
    if props.onPress then
        instance._onPress = props.onPress
        instance:addEventListener("tap", function(event)
            props.onPress(event)
            return true
        end)
    end
    if props.onLongPress then
        instance._onLongPress = props.onLongPress
        local longPressTimer = nil
        instance:addEventListener("touch", function(event)
            if event.phase == "began" then
                display.currentStage:setFocus(instance)
                longPressTimer = timer.performWithDelay(500, function()
                    props.onLongPress(event)
                end)
            elseif event.phase == "ended" or event.phase == "cancelled" then
                display.currentStage:setFocus(nil)
                if longPressTimer then timer.cancel(longPressTimer); longPressTimer = nil end
            end
            return true
        end)
    end

    if props._touchFeedback == "opacity" then
        local activeOpacity = props._activeOpacity or 0.2
        instance:addEventListener("touch", function(event)
            if event.phase == "began" then
                instance._origAlpha = instance.alpha
                instance.alpha = activeOpacity
            elseif event.phase == "ended" or event.phase == "cancelled" then
                instance.alpha = instance._origAlpha or 1
            end
            return true
        end)
    end
end

function M.createInstance(elementType, props)
    local style = props.style or {}

    if elementType == "View" then
        local group = display.newGroup()
        group.anchorX, group.anchorY = 0, 0
        group.anchorChildren = true

        if style.backgroundColor or style.borderWidth or style.borderColor then
            local bg
            if style.borderRadius and style.borderRadius > 0 then
                bg = display.newRoundedRect(group, 0, 0, style.width or 0, style.height or 0, style.borderRadius)
            else
                bg = display.newRect(group, 0, 0, style.width or 0, style.height or 0)
            end
            bg.anchorX, bg.anchorY = 0, 0

            if style.backgroundColor then
                local c = parseColor(style.backgroundColor)
                bg:setFillColor(c[1], c[2], c[3], c[4])
            else
                bg:setFillColor(0, 0, 0, 0)
            end

            if style.borderWidth then
                bg.strokeWidth = style.borderWidth
                if style.borderColor then
                    local c = parseColor(style.borderColor)
                    bg:setStrokeColor(c[1], c[2], c[3], c[4])
                end
            end

            group._bg = bg
        end

        if style.opacity then group.alpha = style.opacity end
        if style.display == "none" then group.isVisible = false end

        wireEvents(group, props)
        return group

    elseif elementType == "Text" then
        local group = display.newGroup()
        group.anchorX, group.anchorY = 0, 0

        local text = tostring(props.children or "")
        local textObj = display.newText({
            parent = group,
            text = text,
            x = 0, y = 0,
            fontSize = style.fontSize or 14,
            width = style.width,
        })
        textObj.anchorX, textObj.anchorY = 0, 0

        if style.color then
            local c = parseColor(style.color)
            textObj:setFillColor(c[1], c[2], c[3], c[4])
        end

        group._textObj = textObj
        wireEvents(group, props)
        return group

    elseif elementType == "Image" then
        local group = display.newGroup()
        group.anchorX, group.anchorY = 0, 0

        local source = props.source
        local filename = (type(source) == "table") and source.uri or source or ""
        local w = style.width or 100
        local h = style.height or 100

        local img = display.newImageRect(group, filename, w, h)
        if img then
            img.anchorX, img.anchorY = 0, 0
        end

        group._imageObj = img
        wireEvents(group, props)
        return group
    end

    local group = display.newGroup()
    group.anchorX, group.anchorY = 0, 0
    wireEvents(group, props)
    return group
end

function M.createTextInstance(text)
    local group = display.newGroup()
    local textObj = display.newText({
        parent = group,
        text = tostring(text),
        x = 0, y = 0,
        fontSize = 14,
    })
    textObj.anchorX, textObj.anchorY = 0, 0
    group._textObj = textObj
    return group
end

function M.appendChild(parent, child)
    parent:insert(child)
end

function M.removeChild(parent, child)
    child:removeSelf()
end

function M.insertBefore(parent, child, beforeChild)
    for i = 1, parent.numChildren do
        if parent[i] == beforeChild then
            parent:insert(i, child)
            return
        end
    end
    parent:insert(child)
end

function M.updateInstance(instance, oldProps, newProps)
    local oldStyle = oldProps.style or {}
    local newStyle = newProps.style or {}

    if instance._bg then
        if newStyle.backgroundColor then
            local c = parseColor(newStyle.backgroundColor)
            instance._bg:setFillColor(c[1], c[2], c[3], c[4])
        end
        if newStyle.width then instance._bg.path.width = newStyle.width end
        if newStyle.height then instance._bg.path.height = newStyle.height end
    end

    if instance._textObj then
        local newText = newProps.children
        local textType = type(newText)
        if textType == "string" or textType == "number" then
            instance._textObj.text = tostring(newText)
        end
        if newStyle.color then
            local c = parseColor(newStyle.color)
            instance._textObj:setFillColor(c[1], c[2], c[3], c[4])
        end
        if newStyle.fontSize then
            instance._textObj.size = newStyle.fontSize
        end
    end

    if newStyle.opacity then instance.alpha = newStyle.opacity end
    if newStyle.display == "none" then
        instance.isVisible = false
    elseif oldStyle.display == "none" and newStyle.display ~= "none" then
        instance.isVisible = true
    end
end

function M.updateTextInstance(instance, oldText, newText)
    if instance._textObj then
        instance._textObj.text = tostring(newText)
    end
end

return M
