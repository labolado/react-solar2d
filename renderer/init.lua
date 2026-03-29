-- renderer/init.lua
local Reconciler = require("react.Reconciler")
local HostConfig = require("renderer.HostConfig")

-- Try loading Yoga C layout engine (optional — layout pass skipped if unavailable)
local layoutOk, Layout = pcall(require, "layout")

local ReactSolar2D = {}
local reconcilerInstance = nil

-- Safe area insets for notch/island devices
function ReactSolar2D.getSafeAreaInsets()
    local safeX = display.safeScreenOriginX or display.screenOriginX or 0
    local safeY = display.safeScreenOriginY or display.screenOriginY or 0
    local safeW = display.safeActualContentWidth or display.actualContentWidth or display.contentWidth
    local safeH = display.safeActualContentHeight or display.actualContentHeight or display.contentHeight
    local screenW = display.actualContentWidth or display.contentWidth
    local screenH = display.actualContentHeight or display.contentHeight

    return {
        top = math.abs(safeY - (display.screenOriginY or 0)),
        bottom = math.max(0, (screenH + (display.screenOriginY or 0)) - (safeH + safeY)),
        left = math.abs(safeX - (display.screenOriginX or 0)),
        right = math.max(0, (screenW + (display.screenOriginX or 0)) - (safeW + safeX)),
    }
end

-- Build a Yoga node tree mirroring the fiber tree
local function buildLayoutTree(fiber)
    if not fiber then return nil end
    if fiber.tag ~= "host" and fiber.tag ~= "root" then
        -- Function components: pass through to child
        return buildLayoutTree(fiber.child)
    end

    local style = (fiber.props and fiber.props.style) or {}
    local node = Layout.newNode(style)

    -- Text elements: measure display object and feed intrinsic dimensions to Yoga
    -- Short text: set width so Yoga gives it its natural size (labels, buttons)
    -- Long text (wider than screen): don't set width, let stretch + reflow wrap it
    if fiber.type == "Text" and fiber.stateNode and fiber.stateNode._textObj then
        local textObj = fiber.stateNode._textObj
        local screenW = display.contentWidth
        if not style.width then
            if textObj.width <= screenW * 0.9 then
                -- Short text: use natural width
                node:setWidth(textObj.width)
            else
                -- Long text: don't set width, reflow will wrap it
                fiber.stateNode._naturalTextWidth = textObj.width
            end
        end
        if not style.height then
            node:setHeight(textObj.height)
        end
    end

    -- TextInput: set minimum height so Yoga doesn't collapse it
    if fiber.type == "TextInput" and not style.height then
        node:setHeight(40)
    end

    -- ScrollView: override overflow so Yoga doesn't constrain content to bounds
    -- Without this, children are clipped to ScrollView's width/height in Yoga,
    -- preventing horizontal ScrollView from having wider content
    if fiber.type == "ScrollView" and not style.overflow then
        -- Rebuild node with overflow = "scroll" so applyStyle handles it
        local scrollStyle = {}
        for k, v in pairs(style) do scrollStyle[k] = v end
        scrollStyle.overflow = "scroll"
        node = Layout.newNode(scrollStyle)
    end

    local child = fiber.child
    local childIndex = 0
    while child do
        local childNode = buildLayoutTree(child)
        if childNode then
            node:insertChild(childNode, childIndex)
            childIndex = childIndex + 1
        end
        child = child.sibling
    end

    return node
end

-- Apply computed layout positions to Solar2D display objects
local function applyLayout(yogaNode, fiber)
    if not yogaNode or not fiber then return end

    if fiber.stateNode then
        local l, t, w, h = yogaNode:getLayout()
        -- Check for absolute positioning with explicit coordinates
        local style = (fiber.props and fiber.props.style) or {}
        if style.position == "absolute" then
            -- For absolute positioning, use specified top/left/right/bottom directly
            -- This allows Modal to position itself at screen origin
            if style.left ~= nil then l = style.left end
            if style.top ~= nil then t = style.top end
            -- Use explicit pixel dimensions from style (Yoga may compute differently)
            if type(style.width) == "number" then w = style.width end
            if type(style.height) == "number" then h = style.height end
            -- If right is specified but not left, calculate left from right
            if style.right ~= nil and style.left == nil then
                if style.width then
                    l = display.contentWidth - style.width - style.right
                else
                    -- Stretch to right edge (not supported in this simple fix)
                    l = 0
                end
            end
            -- If bottom is specified but not top, calculate top from bottom
            if style.bottom ~= nil and style.top == nil then
                if style.height then
                    t = display.contentHeight - style.height - style.bottom
                else
                    -- Stretch to bottom edge (not supported in this simple fix)
                    t = 0
                end
            end
        end
        -- Store layout dimensions for child text wrapping and position offsets
        fiber.stateNode._layoutX = l
        fiber.stateNode._layoutY = t
        fiber.stateNode._layoutW = w
        fiber.stateNode._layoutH = h
        -- For the root fiber (tag == "root"), preserve the container's original
        -- position set by the caller (e.g. screenOriginY offset). Yoga computes
        -- (0,0) for the root, which would overwrite the caller's positioning.
        if fiber.tag ~= "root" then
            fiber.stateNode.x = l + (fiber.stateNode._translateX or 0)
            fiber.stateNode.y = t + (fiber.stateNode._translateY or 0)
        end
        -- Update size for bg rect if present (guard against removed objects)
        -- When style has explicit width/height, skip Yoga's value — updateInstance
        -- already set the correct size and fiber.props.style may be stale during
        -- the same commit cycle (e.g. ProgressBar fill width changes per frame).
        if fiber.stateNode._bg and fiber.stateNode._bg.removeSelf and fiber.stateNode._bg.path then
            if w > 0 and not style.width then
                fiber.stateNode._bg.path.width = w
            end
            if h > 0 and not style.height then
                fiber.stateNode._bg.path.height = h
            end
        end
        -- TextInput: position native field using screen coordinates
        -- native.* objects don't respect group hierarchy, so we must use
        -- localToContent to convert group-local position to screen coordinates
        if fiber.type == "TextInput" and fiber.stateNode._inputField then
            local field = fiber.stateNode._inputField
            local pad = 4
            -- Convert group-local (pad, pad) to screen coordinates
            local sx, sy = fiber.stateNode:localToContent(pad, pad)
            field.x = sx
            field.y = sy
            -- Update size if changed
            if w > pad * 2 then field.width = w - pad * 2 end
            if h > pad * 2 then field.height = h - pad * 2 end
            -- Store pad for scroll sync
            fiber.stateNode._fieldPad = pad
        end
        -- WebView: position native webview using screen coordinates
        if fiber.stateNode._webView then
            local wv = fiber.stateNode._webView
            local sx, sy = fiber.stateNode:localToContent(0, 0)
            wv.x = sx + w / 2
            wv.y = sy + h / 2
            wv.width = w
            wv.height = h
        end
        -- ScrollView: update scroll dimensions and touch overlay size
        if fiber.type == "ScrollView" and fiber.stateNode._contentGroup then
            fiber.stateNode._scrollW = w
            fiber.stateNode._scrollH = h
            -- Update touch overlay rect to match new size
            local overlay = fiber.stateNode._touchOverlay
            if overlay and overlay.path then
                overlay.path.width = w
                overlay.path.height = h
            end
        end
        -- Text wrapping: rebuild text if it overflows its parent's width
        -- Only for long text that was flagged in buildLayoutTree (has _naturalTextWidth)
        if fiber.type == "Text" and fiber.stateNode._textObj and fiber.stateNode._naturalTextWidth then
            local textObj = fiber.stateNode._textObj
            local textStyle = (fiber.props and fiber.props.style) or {}
            local naturalW = fiber.stateNode._naturalTextWidth
            -- Compute wrap width: walk up the fiber tree accumulating padding/margin
            -- from all host parents to find the actual available content width
            local wrapW = w
            if naturalW > wrapW + 1 then
                -- Yoga didn't constrain — compute from screen width minus paddings
                local totalPad = 0
                local p = fiber
                while p do
                    if p.tag == "host" and p.props then
                        local ps = p.props.style or {}
                        local pad = (ps.paddingLeft or ps.paddingHorizontal or ps.padding or 0)
                                  + (ps.paddingRight or ps.paddingHorizontal or ps.padding or 0)
                        local mar = (ps.marginLeft or ps.marginHorizontal or ps.margin or 0)
                                  + (ps.marginRight or ps.marginHorizontal or ps.margin or 0)
                        totalPad = totalPad + pad + mar
                    end
                    p = p.parent
                end
                local screenW = display.contentWidth
                local computed = screenW - totalPad
                if computed > 0 and computed < naturalW then
                    wrapW = computed
                end
            end
            if not textStyle.width and wrapW > 0 and naturalW > wrapW + 1 then
                local parent = fiber.stateNode
                local newTextObj = display.newText({
                    parent = parent,
                    text = textObj.text,
                    x = 0, y = 0,
                    font = fiber.stateNode._font or native.systemFont,
                    fontSize = fiber.stateNode._fontSize or 14,
                    width = wrapW,
                    height = 0,
                    align = textStyle.textAlign or "left",
                })
                newTextObj.anchorX, newTextObj.anchorY = 0, 0
                local tc = HostConfig._parseColor and HostConfig._parseColor(textStyle.color or "#000000")
                    or {0, 0, 0, 1}
                newTextObj:setFillColor(tc[1], tc[2], tc[3], tc[4])
                textObj:removeSelf()
                fiber.stateNode._textObj = newTextObj
                fiber.stateNode._textWrapped = true
            end
        end
    end

    -- Walk children: match Yoga children with fiber children (skip function component fibers)
    local childIndex = 0
    local maxBottom = 0
    local maxRight = 0
    local child = fiber.child
    while child do
        if child.tag == "host" or child.tag == "text" then
            local yogaChild = yogaNode:getChild(childIndex)
            if yogaChild then
                applyLayout(yogaChild, child)
                -- Track content extent for ScrollView
                local cl, ct, cw, ch = yogaChild:getLayout()
                if ct + ch > maxBottom then maxBottom = ct + ch end
                if cl + cw > maxRight then maxRight = cl + cw end
            end
            childIndex = childIndex + 1
        elseif child.tag == "function" then
            -- Function component: its host child was added to Yoga tree directly
            local hostChild = child.child
            while hostChild and hostChild.tag == "function" do
                hostChild = hostChild.child
            end
            if hostChild then
                local yogaChild = yogaNode:getChild(childIndex)
                if yogaChild then
                    applyLayout(yogaChild, hostChild)
                    local cl, ct, cw, ch = yogaChild:getLayout()
                    if ct + ch > maxBottom then maxBottom = ct + ch end
                    if cl + cw > maxRight then maxRight = cl + cw end
                end
                childIndex = childIndex + 1
            end
        end
        child = child.sibling
    end

    -- Update ScrollView content dimensions after laying out children
    -- Use the larger of Yoga's computed extent and the existing content size
    -- (recalcContentSize measures actual display objects which may exceed Yoga's
    -- constrained layout, e.g. when content is taller than the ScrollView)
    if fiber.stateNode and fiber.stateNode._contentGroup then
        if maxBottom > (fiber.stateNode._contentH or 0) then
            fiber.stateNode._contentH = maxBottom
        end
        if maxRight > (fiber.stateNode._contentW or 0) then
            fiber.stateNode._contentW = maxRight
        end
        -- Force recalc on next touch to get accurate display bounds
        if fiber.stateNode._invalidateContentSize then
            fiber.stateNode._invalidateContentSize()
        end
    end

    -- Re-apply zIndex after all children are laid out
    -- (toFront at createInstance time is too early — siblings don't exist yet)
    if fiber.stateNode and fiber.stateNode._zIndex and fiber.stateNode._zIndex > 0 then
        if fiber.stateNode.toFront then
            fiber.stateNode:toFront()
        end
    end
end

local function runLayoutPass(rootFiber, width, height)
    if not layoutOk or not rootFiber then return end

    -- Pass 1: compute layout with single-line text measurements
    local layoutRoot = buildLayoutTree(rootFiber)
    if layoutRoot then
        layoutRoot:setWidth(width)
        layoutRoot:setHeight(height)
        layoutRoot:calculateLayout()
        applyLayout(layoutRoot, rootFiber)
        layoutRoot:freeRecursive()
    end

    -- Pass 2: re-layout with wrapped text heights (only if any text was wrapped)
    local needsPass2 = false
    local function checkWrapped(f)
        if not f then return end
        if f.stateNode and f.stateNode._textWrapped then
            needsPass2 = true
            f.stateNode._textWrapped = nil
        end
        checkWrapped(f.child)
        checkWrapped(f.sibling)
    end
    checkWrapped(rootFiber)

    if needsPass2 then
        local layoutRoot2 = buildLayoutTree(rootFiber)
        if layoutRoot2 then
            layoutRoot2:setWidth(width)
            layoutRoot2:setHeight(height)
            layoutRoot2:calculateLayout()
            applyLayout(layoutRoot2, rootFiber)
            layoutRoot2:freeRecursive()
        end
    end
end

function ReactSolar2D.render(element, container, options)
    if not reconcilerInstance then
        reconcilerInstance = Reconciler.create(HostConfig)
    end
    reconcilerInstance.render(element, container)

    -- Run layout pass
    if layoutOk then
        local width = (options and options.width) or display.contentWidth
        local height = (options and options.height) or display.contentHeight
        local rootFiber = reconcilerInstance._getRootFiber()
        runLayoutPass(rootFiber, width, height)
    end

    return reconcilerInstance
end

function ReactSolar2D.unmount(container)
    if reconcilerInstance then
        reconcilerInstance.unmount(container)
        reconcilerInstance = nil
    end
end

function ReactSolar2D.flushUpdates()
    if reconcilerInstance then
        local didUpdate = reconcilerInstance.flushUpdates()
        -- Re-run layout only when state actually changed
        if didUpdate and layoutOk then
            local rootFiber = reconcilerInstance._getRootFiber()
            if rootFiber and rootFiber.stateNode then
                local width = display.contentWidth
                local height = display.contentHeight
                runLayoutPass(rootFiber, width, height)
            end
        end
    end
end

function ReactSolar2D.startAutoFlush()
    Runtime:addEventListener("enterFrame", function()
        ReactSolar2D.flushUpdates()
    end)
end

-- Re-run layout with current screen dimensions (call on window resize)
function ReactSolar2D.handleResize(container)
    if not reconcilerInstance or not layoutOk then return end
    local rootFiber = reconcilerInstance._getRootFiber()
    if not rootFiber then return end

    -- Update root container position (screenOriginY may have changed)
    container.x = display.screenOriginX or 0
    container.y = display.screenOriginY or 0

    -- Re-run layout with new dimensions
    local width = display.actualContentWidth or display.contentWidth
    local height = display.actualContentHeight or display.contentHeight
    runLayoutPass(rootFiber, width, height)
end

-- Convenience: listen for Runtime "resize" events and re-layout automatically
function ReactSolar2D.startResizeListener(container)
    Runtime:addEventListener("resize", function()
        ReactSolar2D.handleResize(container)
    end)
end

return ReactSolar2D
