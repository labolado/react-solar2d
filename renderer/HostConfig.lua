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

local function normalizePoint(value, defaultX, defaultY)
    if type(value) == "table" then
        if value.x or value.y then
            local x = value.x
            local y = value.y
            if x == nil and value[1] ~= nil then x = value[1] end
            if y == nil and value[2] ~= nil then y = value[2] end
            return x or defaultX, y or defaultY
        elseif value[1] or value[2] then
            return value[1] or defaultX, value[2] or defaultY
        end
    end
    return defaultX, defaultY
end

local function buildGradientPaint(props)
    local colors = {}
    if props and type(props.colors) == "table" then
        colors = props.colors
    elseif props and props.colors then
        colors = { props.colors }
    else
        colors = { "#FFFFFF", "#000000" }
    end

    if #colors == 1 then
        colors[2] = colors[1]
    elseif #colors == 0 then
        colors = { "#FFFFFF", "#000000" }
    end

    -- Solar2D only supports 2-color gradients
    -- Parse colors - Solar2D gradient colors are {r, g, b} (no alpha channel in paint)
    local c1 = parseColor(colors[1])
    local c2 = parseColor(colors[2] or colors[1])
    
    -- Solar2D gradient colors should be {r, g, b} in 0-1 range
    local function makeGradientColor(c)
        return { c[1] or 1, c[2] or 1, c[3] or 1 }
    end
    
    local paint = {
        type = "gradient",
        color1 = makeGradientColor(c1),
        color2 = makeGradientColor(c2),
    }

    -- Calculate rotation from start/end points
    -- Solar2D gradient uses `rotation` (degrees), NOT `direction` strings
    -- 0° = left-to-right, 90° = top-to-bottom, etc.
    local startX, startY = normalizePoint(props and props.start, 0.5, 0)
    local endX, endY = normalizePoint(props and props["end"], 0.5, 1)
    local dx = (endX or 0.5) - (startX or 0.5)
    local dy = (endY or 1) - (startY or 0)
    if dx == 0 and dy == 0 then
        dy = 1
    end
    paint.rotation = math.deg(math.atan2(dy, dx))

    return paint
end

local function applyLinearGradientFill(instance, props)
    if not instance or not instance._bg then return end
    instance._bg.fill = buildGradientPaint(props or instance._gradientProps or {})
    instance._gradientProps = {
        colors = props and props.colors,
        start = props and props.start,
        ["end"] = props and props["end"],
    }
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

-- Resolve AnimatedValue to plain number (or pass through plain values)
local function resolveValue(v)
    if type(v) == "table" and v.getValue then
        return v:getValue()
    end
    return v
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
        for key, rawValue in pairs(t) do
            local value = resolveValue(rawValue)
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
    -- Note: ref callbacks are handled by the reconciler (commitWork), not here
    -- Determine feedback style
    local feedbackType = props._touchFeedback -- "opacity" or nil
    local activeOpacity = props._activeOpacity or 0.4

    -- Press feedback via transition.to (reliable — runs after tap fires)
    local function flashFeedback()
        if not feedbackType then return end
        if not instance or not instance.removeSelf then return end
        -- Cancel any in-flight feedback transition
        if instance._feedbackTransition then
            transition.cancel(instance._feedbackTransition)
        end
        local origAlpha = instance.alpha or 1
        -- Animate: dim + shrink, then restore
        instance.alpha = activeOpacity
        instance.xScale = 0.95
        instance.yScale = 0.95
        instance._feedbackTransition = transition.to(instance, {
            time = 120,
            alpha = origAlpha,
            xScale = 1, yScale = 1,
            onComplete = function()
                instance._feedbackTransition = nil
            end,
        })
    end

    if props.onPress then
        instance._onPress = props.onPress
        -- Use 'tap' event — independent of 'touch', doesn't interfere with ScrollView
        -- Reference instance._onPress (not props.onPress) so updateInstance can refresh it
        instance.isHitTestable = true
        instance:addEventListener("tap", function(event)
            flashFeedback()
            if instance._onPress then instance._onPress(event) end
            return true
        end)
    end
    if props.onLongPress then
        instance._onLongPress = props.onLongPress
        instance.isHitTestable = true
        local longPressTimer = nil
        instance:addEventListener("touch", function(event)
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

    -- Touch event handlers for drag functionality (Slider, etc.)
    if props.onTouchStart or props.onTouchMove or props.onTouchEnd then
        instance.isHitTestable = true
        instance:addEventListener("touch", function(event)
            local phase = event.phase
            if phase == "began" and props.onTouchStart then
                props.onTouchStart(event)
                if instance._parentScrollView then
                    instance._parentScrollView:takeFocus(event)
                end
            elseif phase == "moved" and props.onTouchMove then
                props.onTouchMove(event)
            elseif (phase == "ended" or phase == "cancelled") and props.onTouchEnd then
                props.onTouchEnd(event)
            end
            return true
        end)
    end

    -- Drag gesture support (higher-level API for components like Slider)
    -- Callbacks stored on instance so updateInstance can refresh them
    if props.onDragStart or props.onDrag or props.onDragEnd then
        instance.isHitTestable = true
        instance._onDragStart = props.onDragStart
        instance._onDrag = props.onDrag
        instance._onDragEnd = props.onDragEnd
        local isDragging = false
        local dragStartX, dragStartY = 0, 0

        instance:addEventListener("touch", function(event)
            local phase = event.phase
            local globalX, globalY = event.x, event.y

            if phase == "began" then
                isDragging = true
                dragStartX = globalX
                dragStartY = globalY
                display.getCurrentStage():setFocus(event.target)
                if instance._onDragStart then
                    instance._onDragStart({
                        x = globalX, y = globalY,
                        target = event.target,
                        startX = dragStartX, startY = dragStartY
                    })
                end
                if instance._parentScrollView then
                    instance._parentScrollView:takeFocus(event)
                end
            elseif phase == "moved" and isDragging then
                if instance._onDrag then
                    instance._onDrag({
                        x = globalX, y = globalY,
                        target = event.target,
                        startX = dragStartX, startY = dragStartY,
                        deltaX = globalX - dragStartX,
                        deltaY = globalY - dragStartY
                    })
                end
            elseif (phase == "ended" or phase == "cancelled") and isDragging then
                isDragging = false
                display.getCurrentStage():setFocus(nil)
                if instance._onDragEnd then
                    instance._onDragEnd({
                        x = globalX, y = globalY,
                        target = event.target,
                        startX = dragStartX, startY = dragStartY
                    })
                end
            end
            return true
        end)
    end
end

-- Apply common style properties to any instance (resolves AnimatedValue objects)
local function applyCommonStyle(instance, style)
    if style.opacity ~= nil then instance.alpha = resolveValue(style.opacity) end
    if style.translateX ~= nil then
        instance._translateX = resolveValue(style.translateX)
    end
    if style.translateY ~= nil then
        instance._translateY = resolveValue(style.translateY)
    end
    if style.scaleX ~= nil then instance.xScale = resolveValue(style.scaleX) end
    if style.scaleY ~= nil then instance.yScale = resolveValue(style.scaleY) end
    if style.rotation ~= nil then instance.rotation = resolveValue(style.rotation) end
    if style.display == "none" then instance.isVisible = false end
    if style.zIndex then
        instance._zIndex = style.zIndex
        -- Bring to front based on zIndex - higher values appear on top
        if instance._zIndex > 0 and instance.toFront then
            instance:toFront()
        end
    end
    if style.transform then applyTransform(instance, style.transform) end
end

-- Subscribe AnimatedValue listeners that directly update display object properties
local function subscribeAnimatedValues(instance, style)
    local subs = {}
    local function sub(animVal, updater)
        local id = animVal:addListener(function(event)
            updater(event.value)
        end)
        subs[#subs + 1] = { value = animVal, id = id }
    end

    if type(style.opacity) == "table" and style.opacity.getValue then
        sub(style.opacity, function(v) instance.alpha = v end)
    end
    if type(style.translateX) == "table" and style.translateX.getValue then
        sub(style.translateX, function(v)
            instance._translateX = v
            instance.x = (instance._layoutX or 0) + v
        end)
    end
    if type(style.translateY) == "table" and style.translateY.getValue then
        sub(style.translateY, function(v)
            instance._translateY = v
            instance.y = (instance._layoutY or 0) + v
        end)
    end
    if type(style.scaleX) == "table" and style.scaleX.getValue then
        sub(style.scaleX, function(v) instance.xScale = v end)
    end
    if type(style.scaleY) == "table" and style.scaleY.getValue then
        sub(style.scaleY, function(v) instance.yScale = v end)
    end
    if type(style.rotation) == "table" and style.rotation.getValue then
        sub(style.rotation, function(v) instance.rotation = v end)
    end

    if #subs > 0 then
        instance._animSubscriptions = subs
    end
end

-- Unsubscribe all animated value listeners from an instance
local function unsubscribeAnimatedValues(instance)
    if instance._animSubscriptions then
        for _, s in ipairs(instance._animSubscriptions) do
            s.value:removeListener(s.id)
        end
        instance._animSubscriptions = nil
    end
end

function M.createInstance(elementType, props)
    local style = props.style or {}

    -- Normalize Animated.* types to their base type
    local isAnimated = false
    if elementType == "Animated.View" then
        elementType = "View"; isAnimated = true
    elseif elementType == "Animated.Text" then
        elementType = "Text"; isAnimated = true
    elseif elementType == "Animated.Image" then
        elementType = "Image"; isAnimated = true
    end

    if elementType == "View" then
        local group = display.newGroup()
        group.anchorX, group.anchorY = 0, 0
        group.anchorChildren = true

        local vw = type(style.width) == "number" and style.width or 0
        local vh = type(style.height) == "number" and style.height or 0

        -- Background rect: create if has background/border, OR if has explicit size (for hit testing)
        if style.backgroundColor or style.borderWidth or style.borderColor or (vw > 0 and vh > 0) then
            local bg
            local br = tonumber(style.borderRadius) or 0
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
            group._borderRadius = tonumber(style.borderRadius) or 0
            -- Set group dimensions for hit testing (Solar2D groups don't have intrinsic size)
            group.width = vw
            group.height = vh
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
        if isAnimated then subscribeAnimatedValues(group, style) end
        return group

    elseif elementType == "LinearGradient" then
        local group = display.newGroup()
        group.anchorX, group.anchorY = 0, 0
        group.anchorChildren = true
        group._isLinearGradient = true

        local vw = style.width or 1
        local vh = style.height or 1
        local br = tonumber(style.borderRadius) or 0
        local bg
        if br > 0 then
            bg = display.newRoundedRect(group, 0, 0, vw, vh, br)
        else
            bg = display.newRect(group, 0, 0, vw, vh)
        end
        bg.anchorX, bg.anchorY = 0, 0
        group._bg = bg

        if style.borderWidth then
            bg.strokeWidth = style.borderWidth
            if style.borderColor then
                local borderColor = parseColor(style.borderColor)
                bg:setStrokeColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            end
        end

        applyLinearGradientFill(group, props)
        applyCommonStyle(group, style)
        wireEvents(group, props)
        if isAnimated then subscribeAnimatedValues(group, style) end
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
        if isAnimated then subscribeAnimatedValues(group, style) end
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
        local br = tonumber(style.borderRadius) or 0
        if br > 0 then
            bg = display.newRoundedRect(group, 0, 0, w, h, br)
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
            -- Use pcall to catch native text field creation errors
            -- Note: native.newTextField requires screen coordinates, not local
            local ok, result = pcall(function()
                -- Position at center of screen initially, will be moved by layout
                local screenX = display.contentCenterX - (w - 8) / 2
                local screenY = display.contentCenterY - (h - 8) / 2
                if multiline then
                    return native.newTextBox(screenX, screenY, w - 8, h - 8)
                else
                    return native.newTextField(screenX, screenY, w - 8, h - 8)
                end
            end)
            if ok then
                field = result
            else
                print("[HostConfig] TextInput creation failed: " .. tostring(result))
            end
            if field then
                -- Set size first
                field.size = style.fontSize or 14

                -- TextBox (multiline) specific settings
                if multiline then
                    -- Enable editing for text box
                    field.isEditable = true
                    -- Hide default background to show our custom background
                    field.hasBackground = false
                    -- Set to true to allow multiple lines
                    field.isFontSizeScaled = false
                end

                -- Set placeholder if provided (not supported on textBox, but try anyway)
                if props.placeholder then
                    local ok = pcall(function()
                        field.placeholder = props.placeholder
                    end)
                    if not ok then
                        -- TextBox doesn't support placeholder, ignore error
                    end
                end

                -- Set value if provided (may be empty string)
                if props.value ~= nil then
                    local ok = pcall(function()
                        field.text = tostring(props.value)
                    end)
                    if not ok then
                        print("[HostConfig] Warning: failed to set text")
                    end
                end

                -- Set text color
                if style.color then
                    local c = parseColor(style.color)
                    if field.setTextColor and c then
                        pcall(function()
                            field:setTextColor(c[1], c[2], c[3], c[4])
                        end)
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
                -- Do NOT insert native field into group — native objects don't
                -- respect group transforms reliably. Position managed by applyLayout
                -- and ScrollView syncNativeFields via localToContent.
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
            local br = tonumber(style.borderRadius) or 0
            if br > 0 then
                -- Use rounded rect instead
                bg:removeSelf()
                bg = display.newRoundedRect(group, 0, 0, w, h, br)
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
        if isAnimated then subscribeAnimatedValues(group, style) end
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
        -- Mark child with parent ScrollView reference for takeFocus support
        child._parentScrollView = parent
        if parent._invalidateContentSize then parent._invalidateContentSize() end
    else
        parent:insert(child)
        -- Propagate _parentScrollView reference to nested children
        if parent._parentScrollView then
            child._parentScrollView = parent._parentScrollView
        end
    end

    -- Handle zIndex: bring to front if zIndex > 0
    if child._zIndex and child._zIndex > 0 and child.toFront then
        child:toFront()
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

-- Recursively clean up native fields in a display group tree
-- native.* objects are NOT in the GL group hierarchy, so removeSelf() on a
-- parent group won't remove them. We must walk the tree and removeSelf each one.
local function cleanupNativeFields(node)
    if node._inputField and node._inputField.removeSelf then
        node._inputField:removeSelf()
        node._inputField = nil
    end
    if node._webView and node._webView.removeSelf then
        node._webView:removeSelf()
        node._webView = nil
    end
    -- Walk children (display groups have integer-indexed children)
    if node.numChildren then
        for i = 1, node.numChildren do
            local child = node[i]
            if child then cleanupNativeFields(child) end
        end
    end
end

function M.removeChild(parent, child)
    if parent._invalidateContentSize then parent._invalidateContentSize() end
    unsubscribeAnimatedValues(child)
    cleanupNativeFields(child)
    child:removeSelf()
end

function M.insertBefore(parent, child, beforeChild)
    local target = parent._contentGroup or parent
    for i = 1, target.numChildren do
        if target[i] == beforeChild then
            target:insert(i, child)
            -- Propagate _parentScrollView reference
            if parent._contentGroup then
                child._parentScrollView = parent
            elseif parent._parentScrollView then
                child._parentScrollView = parent._parentScrollView
            end
            if parent._invalidateContentSize then parent._invalidateContentSize() end
            return
        end
    end
    target:insert(child)
    -- Propagate _parentScrollView reference
    if parent._contentGroup then
        child._parentScrollView = parent
    elseif parent._parentScrollView then
        child._parentScrollView = parent._parentScrollView
    end
    if parent._invalidateContentSize then parent._invalidateContentSize() end
end

function M.updateInstance(instance, oldProps, newProps)
    local oldStyle = oldProps.style or {}
    local newStyle = newProps.style or {}

    -- Background rect: handle create/update/recreate
    local needsBg = newStyle.backgroundColor or newStyle.borderWidth or newStyle.borderColor
    local oldBr = tonumber(oldStyle.borderRadius) or 0
    local newBr = tonumber(newStyle.borderRadius) or 0
    local brChanged = oldBr ~= newBr

    if needsBg and not instance._bg then
        -- Create _bg dynamically (was absent at createInstance time)
        local vw = newStyle.width or instance._layoutW or 0
        local vh = newStyle.height or instance._layoutH or 0
        if vw > 0 and vh > 0 then
            local bg
            if newBr > 0 then
                bg = display.newRoundedRect(instance, 0, 0, vw, vh, newBr)
            else
                bg = display.newRect(instance, 0, 0, vw, vh)
            end
            bg.anchorX, bg.anchorY = 0, 0
            bg:setFillColor(0, 0, 0, 0)
            bg:toBack()
            instance._bg = bg
            instance._borderRadius = newBr
        end
    elseif instance._bg and brChanged then
        -- borderRadius changed: recreate _bg (rect vs roundedRect)
        local vw = instance._bg.path and instance._bg.path.width or (newStyle.width or 0)
        local vh = instance._bg.path and instance._bg.path.height or (newStyle.height or 0)
        if vw > 0 and vh > 0 then
            local oldBg = instance._bg
            local bg
            if newBr > 0 then
                bg = display.newRoundedRect(instance, 0, 0, vw, vh, newBr)
            else
                bg = display.newRect(instance, 0, 0, vw, vh)
            end
            bg.anchorX, bg.anchorY = 0, 0
            bg:setFillColor(0, 0, 0, 0)
            bg:toBack()
            oldBg:removeSelf()
            instance._bg = bg
            instance._borderRadius = newBr
        end
    end

    -- Update existing _bg properties
    if instance._bg and instance._bg.removeSelf and instance._bg.path then
        if newStyle.backgroundColor then
            local c = parseColor(newStyle.backgroundColor)
            instance._bg:setFillColor(c[1], c[2], c[3], c[4])
        elseif oldStyle.backgroundColor and not newStyle.backgroundColor then
            instance._bg:setFillColor(0, 0, 0, 0)  -- transparent
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

    -- Common style updates (resolve AnimatedValues)
    if newStyle.opacity ~= nil then instance.alpha = resolveValue(newStyle.opacity) end
    if newStyle.translateX ~= nil then
        instance._translateX = resolveValue(newStyle.translateX)
        instance.x = (instance._layoutX or 0) + instance._translateX
    end
    if newStyle.translateY ~= nil then
        instance._translateY = resolveValue(newStyle.translateY)
        instance.y = (instance._layoutY or 0) + instance._translateY
    end
    if newStyle.scaleX ~= nil then instance.xScale = resolveValue(newStyle.scaleX) end
    if newStyle.scaleY ~= nil then instance.yScale = resolveValue(newStyle.scaleY) end
    if newStyle.rotation ~= nil then instance.rotation = resolveValue(newStyle.rotation) end
    if newStyle.display == "none" then
        instance.isVisible = false
    elseif oldStyle.display == "none" and newStyle.display ~= "none" then
        instance.isVisible = true
    end
    if newStyle.zIndex then
        instance._zIndex = newStyle.zIndex
        if instance._zIndex > 0 and instance.toFront then
            instance:toFront()
        end
    end

    -- Transform updates
    if newStyle.transform then
        applyTransform(instance, newStyle.transform)
    elseif oldStyle.transform and not newStyle.transform then
        applyTransform(instance, nil) -- reset
    end

    -- Refresh event callbacks so touch listeners use latest closures
    if newProps.onDragStart then instance._onDragStart = newProps.onDragStart end
    if newProps.onDrag then instance._onDrag = newProps.onDrag end
    if newProps.onDragEnd then instance._onDragEnd = newProps.onDragEnd end
    if newProps.onPress then instance._onPress = newProps.onPress end

    -- LinearGradient: update fill when props change
    if instance._isLinearGradient then
        local gradientChanged = (oldProps.colors ~= newProps.colors)
            or (oldProps.start ~= newProps.start)
            or (oldProps["end"] ~= newProps["end"])
        if gradientChanged then
            applyLinearGradientFill(instance, newProps)
        end
    end

    -- Re-subscribe animated values if they changed
    if instance._animSubscriptions then
        unsubscribeAnimatedValues(instance)
        subscribeAnimatedValues(instance, newStyle)
    end
end

function M.updateTextInstance(instance, oldText, newText)
    if instance._textObj then
        instance._textObj.text = tostring(newText)
    end
end

M._parseColor = parseColor

return M
