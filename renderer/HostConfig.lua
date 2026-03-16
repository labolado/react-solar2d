-- renderer/HostConfig.lua
local M = {}

local function parseColor(color)
    if type(color) == "table" then return color end
    if type(color) ~= "string" then return {1, 1, 1, 1} end

    if color:sub(1, 1) == "#" then
        local hex = color:sub(2)
        -- Expand 3/4-char shorthand (#RGB / #RGBA → #RRGGBB / #RRGGBBAA)
        if #hex == 3 or #hex == 4 then
            local expanded = ""
            for i = 1, #hex do
                local c = hex:sub(i, i)
                expanded = expanded .. c .. c
            end
            hex = expanded
        end
        local r = (tonumber(hex:sub(1, 2), 16) or 0) / 255
        local g = (tonumber(hex:sub(3, 4), 16) or 0) / 255
        local b = (tonumber(hex:sub(5, 6), 16) or 0) / 255
        local a = #hex >= 8 and ((tonumber(hex:sub(7, 8), 16) or 255) / 255) or 1
        return {r, g, b, a}
    end

    -- rgba(r, g, b, a) format
    local r, g, b, a = color:match("rgba?%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,?%s*([%d%.]*)")
    if r then
        return {tonumber(r)/255, tonumber(g)/255, tonumber(b)/255, tonumber(a ~= "" and a or "1")}
    end

    local named = {
        red = {1, 0, 0, 1}, green = {0, 0.5, 0, 1}, blue = {0, 0, 1, 1},
        white = {1, 1, 1, 1}, black = {0, 0, 0, 1}, transparent = {0, 0, 0, 0},
        gray = {0.5, 0.5, 0.5, 1}, yellow = {1, 1, 0, 1}, orange = {1, 0.65, 0, 1},
    }
    return named[color:lower()] or {1, 1, 1, 1}
end

-- Resolve font from style properties
local function resolveFont(style)
    if style.fontFamily then
        if style.fontWeight == "bold" then
            return style.fontFamily .. "-Bold"
        end
        return style.fontFamily
    end
    if style.fontWeight == "bold" then
        return native and native.systemFontBold or "systemFontBold"
    end
    return native and native.systemFont or "systemFont"
end

-- Apply RN transform array to Solar2D display object
local function applyTransform(instance, transforms)
    if not transforms then
        instance.rotation = 0
        instance.xScale = 1
        instance.yScale = 1
        return
    end
    for _, t in ipairs(transforms) do
        for key, value in pairs(t) do
            if key == "rotate" then
                local deg = tostring(value):match("^(.-)deg$")
                if deg then
                    instance.rotation = tonumber(deg) or 0
                else
                    local rad = tostring(value):match("^(.-)rad$")
                    if rad then
                        instance.rotation = (tonumber(rad) or 0) * 180 / math.pi
                    end
                end
            elseif key == "scale" then
                instance.xScale = value
                instance.yScale = value
            elseif key == "scaleX" then
                instance.xScale = value
            elseif key == "scaleY" then
                instance.yScale = value
            elseif key == "translateX" then
                instance._translateX = value
            elseif key == "translateY" then
                instance._translateY = value
            end
        end
    end
end

-- Create per-side border line
local function addBorderSide(group, side, width, color, viewW, viewH)
    if not width or width <= 0 then return nil end
    local c = parseColor(color or "#000000")
    local line
    if side == "bottom" then
        line = display.newRect(group, 0, viewH - width, viewW, width)
    elseif side == "top" then
        line = display.newRect(group, 0, 0, viewW, width)
    elseif side == "left" then
        line = display.newRect(group, 0, 0, width, viewH)
    elseif side == "right" then
        line = display.newRect(group, viewW - width, 0, width, viewH)
    end
    if line then
        line.anchorX, line.anchorY = 0, 0
        line:setFillColor(c[1], c[2], c[3], c[4])
    end
    return line
end

local function wireEvents(instance, props)
    if props.onPress then
        instance._onPress = props.onPress
        -- Use 'tap' event on the actual display object (_bg rect or _textObj).
        -- 'tap' is independent of 'touch' events, so it doesn't interfere with
        -- ScrollView scrolling (which uses touch+setFocus). Solar2D automatically
        -- suppresses tap when the finger moves significantly (scroll gesture).
        local target = instance._bg or instance._textObj or instance
        if target == instance then
            instance.isHitTestable = true
        end
        target:addEventListener("tap", function(event)
            props.onPress(event)
            return true
        end)
    end
    if props.onLongPress then
        instance._onLongPress = props.onLongPress
        local target = instance._bg or instance._textObj or instance
        if target == instance then instance.isHitTestable = true end
        local longPressTimer = nil
        target:addEventListener("touch", function(event)
            if event.phase == "began" then
                longPressTimer = timer.performWithDelay(500, function()
                    props.onLongPress(event)
                end)
            elseif event.phase == "ended" or event.phase == "cancelled" then
                if longPressTimer then timer.cancel(longPressTimer); longPressTimer = nil end
            end
            return true
        end)
    end

    if props._touchFeedback == "opacity" then
        local activeOpacity = props._activeOpacity or 0.2
        local target = instance._bg or instance._textObj or instance
        target:addEventListener("touch", function(event)
            if event.phase == "began" then
                instance._origAlpha = instance.alpha
                instance.alpha = activeOpacity
            elseif event.phase == "ended" or event.phase == "cancelled" then
                instance.alpha = instance._origAlpha or 1
            end
            return false -- don't consume; let tap (onPress) fire
        end)
    end
end

-- Apply common style properties to any instance
local function applyCommonStyle(instance, style)
    if style.opacity then instance.alpha = style.opacity end
    if style.display == "none" then instance.isVisible = false end
    if style.zIndex then instance._zIndex = style.zIndex end
    if style.transform then applyTransform(instance, style.transform) end
end

function M.createInstance(elementType, props)
    local style = props.style or {}

    if elementType == "View" then
        local group = display.newGroup()
        group.anchorX, group.anchorY = 0, 0
        group.anchorChildren = true

        -- Background rect (full border or backgroundColor)
        if style.backgroundColor or style.borderWidth or style.borderColor then
            local bg
            local vw = style.width or 0
            local vh = style.height or 0
            local br = style.borderRadius or 0
            -- Perfect circle: use roundedRect (same as before, reliable positioning)
            local isCircle = br > 0 and vw > 0 and vh > 0 and vw == vh and br >= vw / 2
            if isCircle then
                bg = display.newRoundedRect(group, 0, 0, vw, vh, br)
                bg.anchorX, bg.anchorY = 0, 0
            elseif br > 0 then
                bg = display.newRoundedRect(group, 0, 0, vw, vh, br)
                bg.anchorX, bg.anchorY = 0, 0
            else
                bg = display.newRect(group, 0, 0, vw, vh)
                bg.anchorX, bg.anchorY = 0, 0
            end

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

        -- Per-side borders
        local viewW = style.width or 0
        local viewH = style.height or 0
        if style.borderBottomWidth then
            group._borderBottom = addBorderSide(group, "bottom", style.borderBottomWidth, style.borderBottomColor, viewW, viewH)
        end
        if style.borderTopWidth then
            group._borderTop = addBorderSide(group, "top", style.borderTopWidth, style.borderTopColor, viewW, viewH)
        end
        if style.borderLeftWidth then
            group._borderLeft = addBorderSide(group, "left", style.borderLeftWidth, style.borderLeftColor, viewW, viewH)
        end
        if style.borderRightWidth then
            group._borderRight = addBorderSide(group, "right", style.borderRightWidth, style.borderRightColor, viewW, viewH)
        end

        -- Store layout info for manual centering (without Yoga layout engine)
        if style.justifyContent or style.alignItems then
            group._centerChildren = true
            group._viewW = style.width or 0
            group._viewH = style.height or 0
            group._alignItems = style.alignItems
            group._justifyContent = style.justifyContent
        end

        applyCommonStyle(group, style)
        wireEvents(group, props)
        return group

    elseif elementType == "Text" then
        local group = display.newGroup()
        group.anchorX, group.anchorY = 0, 0

        local text = tostring(props.children or "")
        local font = resolveFont(style)
        local textObj = display.newText({
            parent = group,
            text = text,
            x = 0, y = 0,
            font = font,
            fontSize = style.fontSize or 14,
            width = style.width,
            height = 0,
            align = style.textAlign or "left",
        })
        textObj.anchorX, textObj.anchorY = 0, 0

        -- Default text color to black (RN default), unlike Solar2D's white default
        local c = parseColor(style.color or "#000000")
        textObj:setFillColor(c[1], c[2], c[3], c[4])

        group._textObj = textObj
        group._font = font
        group._fontSize = style.fontSize or 14
        group._lineHeight = style.lineHeight
        applyCommonStyle(group, style)
        wireEvents(group, props)
        return group

    elseif elementType == "ScrollView" then
        local createScrollView = require("renderer.ScrollViewFactory")
        return createScrollView(props, style, applyCommonStyle)

    elseif elementType == "TextInput" then
        local group = display.newGroup()
        group.anchorX, group.anchorY = 0, 0

        local w = style.width or 200
        local h = style.height or 40

        -- Background box
        local bg
        if style.borderRadius and style.borderRadius > 0 then
            bg = display.newRoundedRect(group, 0, 0, w, h, style.borderRadius)
        else
            bg = display.newRect(group, 0, 0, w, h)
        end
        bg.anchorX, bg.anchorY = 0, 0
        local bgColor = parseColor(style.backgroundColor or "#FFFFFF")
        bg:setFillColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
        if style.borderWidth then
            bg.strokeWidth = style.borderWidth
            local bc = parseColor(style.borderColor or "#CCCCCC")
            bg:setStrokeColor(bc[1], bc[2], bc[3], bc[4])
        end

        -- Native text field (if available in Solar2D)
        local field
        if native and native.newTextField then
            local multiline = props.multiline or false
            if multiline then
                field = native.newTextBox(w / 2, h / 2, w - 8, h - 8)
            else
                field = native.newTextField(w / 2, h / 2, w - 8, h - 8)
            end
            if field then
                field.font = native.systemFont
                field.size = style.fontSize or 14
                if props.placeholder then field.placeholder = props.placeholder end
                if props.value then field.text = props.value end
                if style.color then
                    local c = parseColor(style.color)
                    if field.setTextColor then
                        field:setTextColor(c[1], c[2], c[3], c[4])
                    end
                end
                field:addEventListener("userInput", function(event)
                    if event.phase == "editing" or event.phase == "ended" then
                        if props.onChangeText then
                            props.onChangeText(field.text)
                        end
                    end
                    if event.phase == "submitted" then
                        if props.onSubmitEditing then
                            props.onSubmitEditing({ nativeEvent = { text = field.text } })
                        end
                        if native.setKeyboardFocus then
                            native.setKeyboardFocus(nil)
                        end
                    end
                end)
                group:insert(field)
            end
        else
            -- Fallback: placeholder text for mock/non-native environments
            local placeholder = display.newText({
                parent = group,
                text = props.placeholder or "",
                x = 8, y = h / 2,
                fontSize = style.fontSize or 14,
            })
            placeholder.anchorX, placeholder.anchorY = 0, 0.5
            local c = parseColor("#999999")
            placeholder:setFillColor(c[1], c[2], c[3], c[4])
            group._placeholder = placeholder
        end

        group._bg = bg
        group._inputField = field
        group._isTextInput = true
        applyCommonStyle(group, style)
        wireEvents(group, props)
        return group

    elseif elementType == "Image" then
        local group = display.newGroup()
        group.anchorX, group.anchorY = 0, 0

        local source = props.source
        local uri = (type(source) == "table") and source.uri or source or ""
        local w = style.width or 100
        local h = style.height or 100
        local resizeMode = props.resizeMode or style.resizeMode or "cover"

        if uri:match("^https?://") then
            -- Remote image: placeholder + async download
            local bg = display.newRect(group, 0, 0, w, h)
            bg.anchorX, bg.anchorY = 0, 0
            bg:setFillColor(0.93, 0.93, 0.95)
            if style.borderRadius and style.borderRadius > 0 then
                -- Use rounded rect instead
                bg:removeSelf()
                bg = display.newRoundedRect(group, 0, 0, w, h, style.borderRadius)
                bg.anchorX, bg.anchorY = 0, 0
                bg:setFillColor(0.93, 0.93, 0.95)
            end
            group._bg = bg

            local fname = "rimg_" .. tostring(math.random(100000, 999999)) .. ".jpg"
            network.download(uri, "GET", function(event)
                if event.isError then return end
                if event.phase == "ended" then
                    if not group or group.removeSelf == nil then return end
                    -- Load at natural size, then scale to fit (contain mode)
                    local img = display.newImage(group, fname, system.TemporaryDirectory)
                    if img then
                        local natW, natH = img.width, img.height
                        if natW > 0 and natH > 0 then
                            local sc = math.min(w / natW, h / natH)
                            img.width = natW * sc
                            img.height = natH * sc
                        else
                            img.width = w
                            img.height = h
                        end
                        img.anchorX, img.anchorY = 0, 0
                        img.x, img.y = 0, 0
                        if bg and bg.removeSelf then bg:removeSelf() end
                        group._imageObj = img
                    end
                end
            end, {}, fname, system.TemporaryDirectory)
        else
            -- Local file
            local img = display.newImageRect(group, uri, w, h)
            if img then
                img.anchorX, img.anchorY = 0, 0
            end
            group._imageObj = img
        end

        group._resizeMode = resizeMode
        applyCommonStyle(group, style)
        wireEvents(group, props)
        return group
    end

    -- Unknown element type — create as generic group
    local group = display.newGroup()
    group.anchorX, group.anchorY = 0, 0
    applyCommonStyle(group, style)
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
    textObj:setFillColor(0, 0, 0) -- Default to black
    group._textObj = textObj
    return group
end

function M.appendChild(parent, child)
    if parent._contentGroup then
        -- ScrollView: insert into content group
        parent._contentGroup:insert(child)
        if parent._invalidateContentSize then parent._invalidateContentSize() end
    else
        parent:insert(child)
    end

    -- Manual centering: without Yoga, justifyContent/alignItems don't work.
    -- If the parent View has centering styles and known dimensions, center the child.
    if parent._centerChildren and child.contentWidth then
        local pw = parent._viewW or 0
        local ph = parent._viewH or 0
        local cw = child.contentWidth or child.width or 0
        local ch = child.contentHeight or child.height or 0
        if parent._alignItems == "center" and pw > 0 and cw > 0 then
            child.x = (pw - cw) / 2
        end
        if parent._justifyContent == "center" and ph > 0 and ch > 0 then
            child.y = (ph - ch) / 2
        end
    end
end

function M.removeChild(parent, child)
    if parent._invalidateContentSize then parent._invalidateContentSize() end
    child:removeSelf()
end

function M.insertBefore(parent, child, beforeChild)
    local target = parent._contentGroup or parent
    for i = 1, target.numChildren do
        if target[i] == beforeChild then
            target:insert(i, child)
            if parent._invalidateContentSize then parent._invalidateContentSize() end
            return
        end
    end
    target:insert(child)
    if parent._invalidateContentSize then parent._invalidateContentSize() end
end

function M.updateInstance(instance, oldProps, newProps)
    local oldStyle = oldProps.style or {}
    local newStyle = newProps.style or {}

    -- Background rect updates (check removeSelf hasn't been called)
    if instance._bg and instance._bg.removeSelf and instance._bg.path then
        if newStyle.backgroundColor then
            local c = parseColor(newStyle.backgroundColor)
            instance._bg:setFillColor(c[1], c[2], c[3], c[4])
        end
        if newStyle.borderColor then
            local c = parseColor(newStyle.borderColor)
            instance._bg:setStrokeColor(c[1], c[2], c[3], c[4])
        end
        if newStyle.borderWidth then
            instance._bg.strokeWidth = newStyle.borderWidth
        end
        if newStyle.width then instance._bg.path.width = newStyle.width end
        if newStyle.height then instance._bg.path.height = newStyle.height end
    end

    -- Text updates
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

        -- Font, alignment, or width change requires recreating text object
        local oldFont = resolveFont(oldStyle)
        local newFont = resolveFont(newStyle)
        if oldFont ~= newFont or (oldStyle.textAlign ~= newStyle.textAlign) or (oldStyle.width ~= newStyle.width) then
            local oldTextObj = instance._textObj
            local newTextObj = display.newText({
                parent = instance,
                text = oldTextObj.text,
                x = oldTextObj.x, y = oldTextObj.y,
                font = newFont,
                fontSize = newStyle.fontSize or oldTextObj.size,
                width = newStyle.width or oldTextObj.width,
                height = 0,
                align = newStyle.textAlign or "left",
            })
            newTextObj.anchorX, newTextObj.anchorY = 0, 0
            if newStyle.color then
                local c = parseColor(newStyle.color)
                newTextObj:setFillColor(c[1], c[2], c[3], c[4])
            end
            oldTextObj:removeSelf()
            instance._textObj = newTextObj
        end

        instance._lineHeight = newStyle.lineHeight
    end

    -- ScrollView: handle refreshing prop change
    if instance._contentGroup and instance._refreshing ~= nil then
        local wasRefreshing = oldProps.refreshing
        local nowRefreshing = newProps.refreshing
        if wasRefreshing and not nowRefreshing then
            -- Refreshing ended: snap back to top
            instance._refreshing = false
            instance._scrollY = 0
            instance._contentGroup.y = 0
        elseif nowRefreshing then
            instance._refreshing = true
        end
    end

    -- Common style updates
    if newStyle.opacity then instance.alpha = newStyle.opacity end
    if newStyle.display == "none" then
        instance.isVisible = false
    elseif oldStyle.display == "none" and newStyle.display ~= "none" then
        instance.isVisible = true
    end
    if newStyle.zIndex then instance._zIndex = newStyle.zIndex end

    -- Transform updates
    if newStyle.transform then
        applyTransform(instance, newStyle.transform)
    elseif oldStyle.transform and not newStyle.transform then
        applyTransform(instance, nil) -- reset
    end
end

function M.updateTextInstance(instance, oldText, newText)
    if instance._textObj then
        instance._textObj.text = tostring(newText)
    end
end

M._parseColor = parseColor

return M
