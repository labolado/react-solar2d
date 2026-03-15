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

        if style.color then
            local c = parseColor(style.color)
            textObj:setFillColor(c[1], c[2], c[3], c[4])
        end

        group._textObj = textObj
        group._lineHeight = style.lineHeight
        applyCommonStyle(group, style)
        wireEvents(group, props)
        return group

    elseif elementType == "ScrollView" then
        local w = style.width or (display.contentWidth or 320)
        local h = style.height or (display.contentHeight or 480)
        local horizontal = props.horizontal or false

        -- Outer: clipping container
        local clipContainer = display.newContainer(w, h)
        clipContainer.anchorX, clipContainer.anchorY = 0, 0
        clipContainer.anchorChildren = false

        -- Inner: scrollable content group
        local contentGroup = display.newGroup()
        clipContainer:insert(contentGroup)
        -- Container coordinate origin is at center, offset to top-left
        contentGroup.x = -w / 2
        contentGroup.y = -h / 2

        clipContainer._contentGroup = contentGroup
        clipContainer._scrollW = w
        clipContainer._scrollH = h
        clipContainer._horizontal = horizontal
        clipContainer._scrollY = 0
        clipContainer._scrollX = 0
        clipContainer._contentH = 0
        clipContainer._contentW = 0

        -- Pull-to-refresh settings
        local refreshThreshold = 100
        local refreshOffset = 60
        clipContainer._refreshing = props.refreshing or false
        clipContainer._pullingToRefresh = false

        -- Touch-based scrolling
        local startY, startX, startScrollY, startScrollX
        clipContainer:addEventListener("touch", function(event)
            if event.phase == "began" then
                if display.currentStage and display.currentStage.setFocus then
                    display.currentStage:setFocus(clipContainer)
                end
                startY = event.y
                startX = event.x
                startScrollY = clipContainer._scrollY
                startScrollX = clipContainer._scrollX
                clipContainer._pullingToRefresh = false
            elseif event.phase == "moved" then
                if horizontal then
                    local dx = event.x - startX
                    local newScrollX = startScrollX + dx
                    local maxScroll = math.max(0, clipContainer._contentW - w)
                    newScrollX = math.max(-maxScroll, math.min(0, newScrollX))
                    clipContainer._scrollX = newScrollX
                    contentGroup.x = -w / 2 + newScrollX
                else
                    local dy = event.y - startY
                    local newScrollY = startScrollY + dy

                    -- Pull-to-refresh: allow overscroll past top when onRefresh is set
                    if props.onRefresh and newScrollY > 0 then
                        -- Apply rubber-band resistance (overscroll is dampened)
                        local overscroll = newScrollY
                        local dampened = overscroll * 0.4
                        clipContainer._scrollY = dampened
                        contentGroup.y = -h / 2 + dampened
                        clipContainer._pullingToRefresh = dampened >= refreshThreshold * 0.4
                    else
                        local maxScroll = math.max(0, clipContainer._contentH - h)
                        newScrollY = math.max(-maxScroll, math.min(0, newScrollY))
                        clipContainer._scrollY = newScrollY
                        contentGroup.y = -h / 2 + newScrollY
                        clipContainer._pullingToRefresh = false
                    end
                end
                if props.onScroll then
                    props.onScroll({
                        contentOffset = {
                            x = -clipContainer._scrollX,
                            y = -clipContainer._scrollY,
                        }
                    })
                end
            elseif event.phase == "ended" or event.phase == "cancelled" then
                if display.currentStage and display.currentStage.setFocus then
                    display.currentStage:setFocus(nil)
                end

                -- Pull-to-refresh: trigger callback and snap back
                if not horizontal and clipContainer._pullingToRefresh and props.onRefresh then
                    clipContainer._refreshing = true
                    -- Snap to refreshing offset position
                    clipContainer._scrollY = refreshOffset
                    contentGroup.y = -h / 2 + refreshOffset
                    props.onRefresh()
                elseif not horizontal and clipContainer._scrollY > 0 then
                    -- Snap back to top (overscrolled but below threshold)
                    clipContainer._scrollY = 0
                    contentGroup.y = -h / 2
                end
                clipContainer._pullingToRefresh = false
            end
            return true
        end)

        applyCommonStyle(clipContainer, style)
        wireEvents(clipContainer, props)
        return clipContainer

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
        local filename = (type(source) == "table") and source.uri or source or ""
        local w = style.width or 100
        local h = style.height or 100
        local resizeMode = props.resizeMode or style.resizeMode or "cover"

        local img = display.newImageRect(group, filename, w, h)
        if img then
            img.anchorX, img.anchorY = 0, 0
        end

        group._imageObj = img
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
    group._textObj = textObj
    return group
end

function M.appendChild(parent, child)
    if parent._contentGroup then
        -- ScrollView: insert into content group
        parent._contentGroup:insert(child)
    else
        parent:insert(child)
    end
end

function M.removeChild(parent, child)
    child:removeSelf()
end

function M.insertBefore(parent, child, beforeChild)
    local target = parent._contentGroup or parent
    for i = 1, target.numChildren do
        if target[i] == beforeChild then
            target:insert(i, child)
            return
        end
    end
    target:insert(child)
end

function M.updateInstance(instance, oldProps, newProps)
    local oldStyle = oldProps.style or {}
    local newStyle = newProps.style or {}

    -- Background rect updates
    if instance._bg then
        if newStyle.backgroundColor then
            local c = parseColor(newStyle.backgroundColor)
            instance._bg:setFillColor(c[1], c[2], c[3], c[4])
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

        -- Font or alignment change requires recreating text object
        local oldFont = resolveFont(oldStyle)
        local newFont = resolveFont(newStyle)
        if oldFont ~= newFont or (oldStyle.textAlign ~= newStyle.textAlign) then
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
            local halfH = (instance._scrollH or 0) / 2
            instance._contentGroup.y = -halfH
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

return M
