-- renderer/init.lua
local Reconciler = require("react.Reconciler")
local HostConfig = require("renderer.HostConfig")

-- Try loading Yoga C layout engine (optional — layout pass skipped if unavailable)
local layoutOk, Layout = pcall(require, "layout")

local ReactSolar2D = {}
local reconcilerInstance = nil

-- Build a Yoga node tree mirroring the fiber tree
local function buildLayoutTree(fiber)
    if not fiber then return nil end
    if fiber.tag ~= "host" and fiber.tag ~= "root" then
        -- Function components: pass through to child
        return buildLayoutTree(fiber.child)
    end

    local style = (fiber.props and fiber.props.style) or {}
    local node = Layout.newNode(style)

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
        -- Update size for bg rect if present
        if fiber.stateNode._bg then
            fiber.stateNode._bg.path.width = w
            fiber.stateNode._bg.path.height = h
        end
    end

    -- Walk children: match Yoga children with fiber children (skip function component fibers)
    local childIndex = 0
    local child = fiber.child
    while child do
        if child.tag == "host" or child.tag == "text" then
            local yogaChild = yogaNode:getChild(childIndex)
            if yogaChild then
                applyLayout(yogaChild, child)
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
                end
                childIndex = childIndex + 1
            end
        end
        child = child.sibling
    end
end

local function runLayoutPass(rootFiber, width, height)
    if not layoutOk or not rootFiber then return end

    local layoutRoot = buildLayoutTree(rootFiber)
    if layoutRoot then
        -- Set root dimensions
        layoutRoot:setWidth(width)
        layoutRoot:setHeight(height)
        layoutRoot:calculateLayout()
        applyLayout(layoutRoot, rootFiber)
        layoutRoot:freeRecursive()
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
        reconcilerInstance.flushUpdates()
        -- Re-run layout after state updates
        if layoutOk then
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
