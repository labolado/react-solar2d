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
    if fiber.type == "Text" and fiber.stateNode and fiber.stateNode._textObj then
        local textObj = fiber.stateNode._textObj
        if not style.width then
            node:setWidth(textObj.width)
        end
        if not style.height then
            node:setHeight(textObj.height)
        end
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
        fiber.stateNode.x = l
        fiber.stateNode.y = t
        -- Update size for bg rect if present (guard against removed objects)
        if fiber.stateNode._bg and fiber.stateNode._bg.removeSelf and fiber.stateNode._bg.path then
            fiber.stateNode._bg.path.width = w
            fiber.stateNode._bg.path.height = h
        end
        -- Text wrapping: disabled temporarily for debugging
        -- TODO: re-enable after fixing text disappearing issue
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
    if fiber.stateNode and fiber.stateNode._contentGroup then
        fiber.stateNode._contentH = maxBottom
        fiber.stateNode._contentW = maxRight
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

    -- Pass 2 disabled: text wrapping temporarily off
    -- TODO: re-enable two-pass layout when text wrapping is fixed
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

return ReactSolar2D
