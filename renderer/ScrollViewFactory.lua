-- renderer/ScrollViewFactory.lua
-- ScrollView creation logic extracted from HostConfig

local function createScrollView(props, style, applyCommonStyle)
    local w = style.width or (display.contentWidth or 320)
    local h = style.height or (display.contentHeight or 480)
    local horizontal = props.horizontal or false

    local clipContainer = display.newGroup()
    clipContainer.anchorX, clipContainer.anchorY = 0, 0

    local contentGroup = display.newGroup()
    clipContainer:insert(contentGroup)

    -- Touch overlay ON TOP of content. Uses touch listener directly (no setFocus).
    local touchOverlay = display.newRect(clipContainer, 0, 0, w, h)
    touchOverlay.anchorX, touchOverlay.anchorY = 0, 0
    touchOverlay:setFillColor(0, 0, 0, 0.001)
    touchOverlay.isHitTestable = true
    touchOverlay._isTouchOverlay = true

    clipContainer._contentGroup = contentGroup
    clipContainer._scrollW = w
    clipContainer._scrollH = h
    clipContainer._horizontal = horizontal
    clipContainer._scrollY = 0
    clipContainer._scrollX = 0
    clipContainer._contentH = 0
    clipContainer._contentW = 0

    local function fireOnScroll()
        if props.onScroll then
            if horizontal then
                props.onScroll({
                    contentOffset = { x = clipContainer._scrollX, y = 0 },
                })
            else
                props.onScroll({
                    contentOffset = { x = 0, y = clipContainer._scrollY },
                })
            end
        end
    end

    local refreshThreshold = 80
    local refreshOffset = 50
    clipContainer._refreshing = props.refreshing or false
    clipContainer._pullingToRefresh = false

    local contentSizeDirty = true

    local function recalcContentSize()
        if not contentSizeDirty then return end
        contentSizeDirty = false
        local maxH, maxW = 0, 0
        for i = 1, contentGroup.numChildren do
            local c = contentGroup[i]
            if c then
                local bot = (c.y or 0) + (c.contentHeight or c.height or 0)
                local rt  = (c.x or 0) + (c.contentWidth or c.width or 0)
                if bot > maxH then maxH = bot end
                if rt > maxW then maxW = rt end
            end
        end
        if maxH > 0 then clipContainer._contentH = maxH end
        if maxW > 0 then clipContainer._contentW = maxW end
    end

    -- Invalidate cache when children change (called by appendChild/removeChild)
    clipContainer._invalidateContentSize = function()
        contentSizeDirty = true
    end

    local startY, startX, startScrollY, startScrollX
    local isDragging = false
    local DRAG_THRESHOLD = 5

    -- Touch listener on the overlay rect — NO setFocus needed.
    touchOverlay:addEventListener("touch", function(event)
        if event.phase == "began" then
            recalcContentSize()
            startY = event.y
            startX = event.x
            startScrollY = clipContainer._scrollY
            startScrollX = clipContainer._scrollX
            isDragging = false
            clipContainer._pullingToRefresh = false
            return true

        elseif event.phase == "moved" then
            if not startY then return true end
            local dy = math.abs(event.y - startY)
            local dx = math.abs(event.x - startX)
            if not isDragging and ((horizontal and dx > DRAG_THRESHOLD) or (not horizontal and dy > DRAG_THRESHOLD)) then
                isDragging = true
            end
            if isDragging then
                if horizontal then
                    local ddx = event.x - startX
                    local newScrollX = startScrollX + ddx
                    local maxScroll = math.max(0, clipContainer._contentW - w)
                    if newScrollX > 0 then
                        newScrollX = newScrollX * 0.4
                    elseif newScrollX < -maxScroll then
                        newScrollX = -maxScroll + (newScrollX + maxScroll) * 0.4
                    end
                    clipContainer._scrollX = newScrollX
                    contentGroup.x = newScrollX
                else
                    local ddy = event.y - startY
                    local newScrollY = startScrollY + ddy
                    local maxScroll = math.max(0, clipContainer._contentH - h)
                    if newScrollY > 0 then
                        clipContainer._scrollY = newScrollY * 0.4
                        contentGroup.y = clipContainer._scrollY
                        if props.onRefresh then
                            clipContainer._pullingToRefresh = clipContainer._scrollY >= refreshThreshold * 0.4
                        end
                    elseif newScrollY < -maxScroll then
                        clipContainer._scrollY = -maxScroll + (newScrollY + maxScroll) * 0.4
                        contentGroup.y = clipContainer._scrollY
                        clipContainer._pullingToRefresh = false
                    else
                        clipContainer._scrollY = newScrollY
                        contentGroup.y = newScrollY
                        clipContainer._pullingToRefresh = false
                    end
                end
            end
            fireOnScroll()
            return true

        elseif event.phase == "ended" or event.phase == "cancelled" then
            if not isDragging and startX then
                -- Tap: find pressable child
                -- Touch coordinates and contentBounds are both screen coordinates
                local ex, ey = startX, startY
                local function findPressable(grp, depth)
                    depth = depth or 0
                    if not grp or not grp.numChildren then return nil end
                    for i = grp.numChildren, 1, -1 do
                        local child = grp[i]
                        if child and child.isVisible ~= false then
                            local cb = child.contentBounds
                            local hasPress = child._onPress ~= nil
                            -- Fallback: if no contentBounds, use x/y/width/height
                            local inBounds = false
                            if cb then
                                inBounds = ex >= cb.xMin and ex <= cb.xMax
                                      and ey >= cb.yMin and ey <= cb.yMax
                            elseif child.x and child.y and child.width and child.height then
                                local halfW = child.width / 2
                                local halfH = child.height / 2
                                -- Account for anchor point (default is center 0.5,0.5)
                                local anchorX = child.anchorX or 0.5
                                local anchorY = child.anchorY or 0.5
                                local xMin = child.x - child.width * anchorX
                                local xMax = xMin + child.width
                                local yMin = child.y - child.height * anchorY
                                local yMax = yMin + child.height
                                inBounds = ex >= xMin and ex <= xMax
                                      and ey >= yMin and ey <= yMax
                            end
                            if inBounds then
                                if hasPress then
                                    return child
                                end
                                local found = findPressable(child, depth + 1)
                                if found then return found end
                            end
                        end
                    end
                    return nil
                end
                local pressable = findPressable(contentGroup)
                if pressable then
                    pressable._onPress(event)
                end
            end

            -- Snap back from overscroll
            if not horizontal then
                local maxScroll = math.max(0, clipContainer._contentH - h)
                if clipContainer._pullingToRefresh and props.onRefresh then
                    clipContainer._refreshing = true
                    clipContainer._scrollY = refreshOffset
                    contentGroup.y = refreshOffset
                    props.onRefresh()
                elseif clipContainer._scrollY > 0 then
                    clipContainer._scrollY = 0
                    contentGroup.y = 0
                elseif clipContainer._scrollY < -maxScroll then
                    clipContainer._scrollY = -maxScroll
                    contentGroup.y = -maxScroll
                end
            else
                local maxScroll = math.max(0, clipContainer._contentW - w)
                if clipContainer._scrollX > 0 then
                    clipContainer._scrollX = 0
                    contentGroup.x = 0
                elseif clipContainer._scrollX < -maxScroll then
                    clipContainer._scrollX = -maxScroll
                    contentGroup.x = -maxScroll
                end
            end
            clipContainer._pullingToRefresh = false
            fireOnScroll()
            isDragging = false
            return true
        end
        return false
    end)

    -- Mouse scroll wheel support (Mac trackpad two-finger scroll)
    touchOverlay:addEventListener("mouse", function(event)
        if event.type == "scroll" then
            recalcContentSize()
            local scrollSpeed = 20
            if horizontal then
                local maxScroll = math.max(0, clipContainer._contentW - w)
                local newScrollX = clipContainer._scrollX - event.scrollX * scrollSpeed
                if newScrollX > 0 then newScrollX = 0 end
                if newScrollX < -maxScroll then newScrollX = -maxScroll end
                clipContainer._scrollX = newScrollX
                contentGroup.x = newScrollX
            else
                local maxScroll = math.max(0, clipContainer._contentH - h)
                local newScrollY = clipContainer._scrollY + event.scrollY * scrollSpeed
                if newScrollY > 0 then newScrollY = 0 end
                if newScrollY < -maxScroll then newScrollY = -maxScroll end
                clipContainer._scrollY = newScrollY
                contentGroup.y = newScrollY
            end
            fireOnScroll()
        end
        return true
    end)

    applyCommonStyle(clipContainer, style)
    return clipContainer
end

return createScrollView
