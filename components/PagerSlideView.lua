--- PagerSlideView component.
-- Paginated horizontal swipe view with dot indicators.
-- Supports two modes:
--   1. Children mode: pass children directly (for small page counts)
--   2. Data mode: pass data + renderPage (virtualized, only mounts current ± 1)
-- Uses TrackDot pattern for reliable swipe on real devices.
-- @module components.PagerSlideView

local React = require("react")
local ce = React.createElement
local useState = React.useState
local useRef = React.useRef
local useCallback = React.useCallback
local useEffect = React.useEffect
local TouchRegistry = require("lib.TouchRegistry")

-- Minimum swipe distance to trigger page change
local SWIPE_THRESHOLD = 40

--- PagerSlideView component.
-- @param props table
--   data table                Array of items (for virtualized mode)
--   renderPage function       Called with (item, index) → React element (for data mode)
--   pageWidth number          Width of each page (default: container width, must be set if not in flex)
--   initialPage number        Starting page index, 1-based (default 1)
--   onPageChange function     Called with (pageIndex) when page changes (1-based)
--   showDots boolean          Show dot indicators (default true)
--   dotColor string           Inactive dot color (default "rgba(255,255,255,0.3)")
--   activeDotColor string     Active dot color (default "#FFF")
--   dotSize number            Dot diameter (default 8)
--   dotSpacing number         Space between dots (default 8)
--   dotsPosition string       "bottom" (default) or "top"
--   style table               Container style
--   pageStyle table           Style applied to each page wrapper
--   loop boolean              Enable infinite loop (default false) — NOT YET IMPLEMENTED
--   children any              Direct children (simple mode, mutually exclusive with data)
--   disabled boolean          Disable swipe
-- @return table React element
local function PagerSlideView(props)
    local containerRef = useRef(nil)
    local contentRef = useRef(nil)
    local propsRef = useRef({})
    propsRef.current = props

    -- Page state
    local currentPage, setCurrentPage = useState(props.initialPage or 1)
    local pageCount = 0
    if props.data then
        pageCount = #props.data
    elseif props.children then
        if type(props.children) == "table" and props.children[1] ~= nil then
            pageCount = #props.children
        elseif props.children ~= nil then
            pageCount = 1
        end
    end

    local pageWidth = props.pageWidth or 0
    local showDots = props.showDots ~= false
    local dotColor = props.dotColor or "rgba(255,255,255,0.3)"
    local activeDotColor = props.activeDotColor or "#FFF"
    local dotSize = props.dotSize or 8
    local dotSpacing = props.dotSpacing or 8

    local onContainerRef = useCallback(function(instance)
        containerRef.current = instance
    end, {})

    local onContentRef = useCallback(function(instance)
        contentRef.current = instance
    end, {})

    -- Refs for touch handler closures (avoids stale values + unnecessary re-runs)
    local currentPageRef = useRef(currentPage)
    currentPageRef.current = currentPage
    local pageCountRef = useRef(pageCount)
    pageCountRef.current = pageCount

    -- Touch handling for swipe — runs once (deps={})
    useEffect(function()
        local container = containerRef.current
        local content = contentRef.current
        if not container or not content then return end

        local touchId = nil
        local startTouchX = nil
        local startContentX = nil
        local dot = nil

        -- Content x is always under our control (page offset), not Yoga.
        content._directManipulation = true

        -- Get container width from Yoga layout (_layoutW), not Solar2D contentWidth.
        -- Solar2D Group.contentWidth is based on child bounding box and may be 0
        -- for flex-only containers.
        local function getPageWidth()
            local p = propsRef.current
            if p.pageWidth and p.pageWidth > 0 then return p.pageWidth end
            local lw = container.layoutWidth or 0
            if lw > 0 then return lw end
            if container._bg and container._bg.path then
                return container._bg.path.width or display.contentWidth
            end
            return display.contentWidth
        end

        local function getContainerSize()
            local w = container.layoutWidth or 0
            local h = container.layoutHeight or 0
            if w <= 0 and container._bg and container._bg.path then
                w = container._bg.path.width or 0
                h = container._bg.path.height or 0
            end
            return w, h
        end

        local function cleanupDot()
            if dot then
                dot:removeEventListener("touch", dot._listener)
                dot:removeSelf()
                dot = nil
            end
        end

        local function snapToPage(targetPage, animated)
            local pw = getPageWidth()
            local targetX = -((targetPage - 1) * pw)
            if animated then
                transition.cancel(content)
                transition.to(content, {
                    time = 250,
                    x = targetX,
                    transition = easing.outQuad,
                })
            else
                content.x = targetX
            end
        end

        local function handleEnd(event)
            if touchId ~= event.id then return end
            TouchRegistry.release(event.id, container)
            display.getCurrentStage():setFocus(nil, event.id)
            cleanupDot()

            local pw = getPageWidth()
            local dx = event.x - startTouchX
            local curPage = currentPageRef.current
            local total = pageCountRef.current

            -- Determine target page based on swipe distance
            local targetPage = curPage
            if dx < -SWIPE_THRESHOLD and curPage < total then
                targetPage = curPage + 1
            elseif dx > SWIPE_THRESHOLD and curPage > 1 then
                targetPage = curPage - 1
            end

            snapToPage(targetPage, true)
            if targetPage ~= curPage then
                setCurrentPage(targetPage)
                local p = propsRef.current
                if p.onPageChange then p.onPageChange(targetPage) end
            end

            touchId = nil
        end

        local function handleMove(event)
            if touchId ~= event.id then return end
            if not startTouchX or not startContentX then return end

            local dx = event.x - startTouchX
            local newX = startContentX + dx

            -- Clamp with rubber-band effect at edges
            local pw = getPageWidth()
            local total = pageCountRef.current
            local minX = -((total - 1) * pw)
            local maxX = 0
            if newX > maxX then
                newX = maxX + (newX - maxX) * 0.3  -- rubber band
            elseif newX < minX then
                newX = minX + (newX - minX) * 0.3
            end

            content.x = newX
        end

        local function dotListener(e)
            if e.id ~= touchId then return true end
            if e.phase == "moved" then
                dot.x = e.x
                dot.y = e.y
                handleMove(e)
            elseif e.phase == "ended" or e.phase == "cancelled" then
                handleEnd(e)
            end
            return true
        end

        local function onTouch(event)
            if event.phase ~= "began" then return false end
            local p = propsRef.current
            if p.disabled then return false end
            if touchId ~= nil then return true end
            if pageCountRef.current <= 1 then return false end
            if not TouchRegistry.canFocus(event.id, container) then return false end

            touchId = event.id
            TouchRegistry.claim(event.id, container)
            startTouchX = event.x
            startContentX = content.x

            -- Stop any ongoing snap animation
            transition.cancel(content)

            -- TrackDot
            dot = display.newCircle(event.x, event.y, 1)
            dot.isVisible = false
            dot.isHitTestable = true
            dot._listener = dotListener
            dot:addEventListener("touch", dotListener)
            display.getCurrentStage():setFocus(dot, event.id)

            return true
        end

        -- Create touch overlay rect. Use Yoga _layoutW/_layoutH (not contentWidth
        -- which is 0 for flex-only Groups in Solar2D).
        -- Retry after first applyLayout frame if dimensions not yet available.
        local hitRect = nil
        local setupTimer = nil

        local function createHitRect()
            local w, h = getContainerSize()
            if w <= 0 or h <= 0 then return false end

            hitRect = display.newRect(container, 0, 0, w, h)
            hitRect.anchorX, hitRect.anchorY = 0, 0
            hitRect:setFillColor(0, 0, 0, 0.01) -- near-invisible but touchable
            hitRect.isHitTestable = true
            hitRect:toFront()
            hitRect:addEventListener("touch", onTouch)
            return true
        end

        if not createHitRect() then
            setupTimer = timer.performWithDelay(32, function()
                setupTimer = nil
                createHitRect()
            end)
        end

        -- Set initial position
        snapToPage(currentPageRef.current, false)

        return function()
            if setupTimer then timer.cancel(setupTimer) end
            if touchId then
                display.getCurrentStage():setFocus(nil, touchId)
                TouchRegistry.release(touchId, container)
                touchId = nil
            end
            cleanupDot()
            transition.cancel(content)
            if hitRect then
                hitRect:removeEventListener("touch", onTouch)
                hitRect:removeSelf()
                hitRect = nil
            end
        end
    end, {})

    -- Build page elements
    local pages = {}
    local pw = pageWidth

    if props.data and props.renderPage then
        -- Virtualized mode: only render current ± 1
        for i = 1, pageCount do
            if math.abs(i - currentPage) <= 1 then
                local pageElement = props.renderPage(props.data[i], i)
                pages[#pages + 1] = ce("View", {
                    key = "page_" .. i,
                    style = {
                        position = "absolute",
                        left = (i - 1) * pw,
                        top = 0,
                        width = pw,
                        height = "100%",
                    },
                }, pageElement)
            end
        end
    elseif props.children then
        -- Children mode: mount all
        local kids = props.children
        if type(kids) ~= "table" or kids[1] == nil then
            kids = { kids }
        end
        for i, child in ipairs(kids) do
            pages[#pages + 1] = ce("View", {
                key = "page_" .. i,
                style = {
                    position = "absolute",
                    left = (i - 1) * pw,
                    top = 0,
                    width = pw,
                    height = "100%",
                },
            }, child)
        end
    end

    -- Dot indicators
    local dots = nil
    if showDots and pageCount > 1 then
        local dotElements = {}
        for i = 1, pageCount do
            local active = i == currentPage
            dotElements[#dotElements + 1] = ce("View", {
                key = "dot_" .. i,
                style = {
                    width = dotSize,
                    height = dotSize,
                    borderRadius = dotSize / 2,
                    backgroundColor = active and activeDotColor or dotColor,
                    marginLeft = i > 1 and dotSpacing or 0,
                },
            })
        end
        dots = ce("View", {
            style = {
                flexDirection = "row",
                justifyContent = "center",
                alignItems = "center",
                paddingVertical = 8,
            },
        }, unpack(dotElements))
    end

    -- Content container: holds pages, translated horizontally
    local contentStyle = {
        position = "absolute",
        left = 0,
        top = 0,
        width = pw * pageCount,
        height = "100%",
    }

    local dotsTop = props.dotsPosition == "top"

    return ce("View", {
        style = props.style,
    },
        dotsTop and dots or nil,
        ce("View", {
            ref = onContainerRef,
            style = {
                flex = 1,
                overflow = "hidden",
            },
        },
            ce("View", {
                ref = onContentRef,
                style = contentStyle,
            }, unpack(pages))
        ),
        (not dotsTop) and dots or nil
    )
end

return PagerSlideView
