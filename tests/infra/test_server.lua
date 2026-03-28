-- test_server.lua — Generic Solar2D UI automation & testing server
-- Drop into any Solar2D project: require("test_server").start(9876)
--
-- API:
--   GET  /status                     — server info
--   GET  /screenshot?label=name      — full-screen screenshot (async, returns base64 PNG)
--   POST /tap       {x,y}           — tap at screen coordinates
--   POST /tap-text  {text,index}    — find element by text and tap it (index: nth match, default 1)
--   POST /longpress {x,y,ms}        — long press at coordinates (default 500ms)
--   POST /drag      {x,y,dx,dy,ms}  — drag gesture from (x,y) by (dx,dy) over ms
--   POST /scroll    {x,y,dx,dy}     — scroll wheel event at (x,y)
--   POST /input     {text}           — send key events (type text into focused field)
--   GET  /tree?depth=N               — display hierarchy dump (default depth 8)
--   GET  /find?text=X&prop=Y        — find elements matching criteria
--   GET  /screenshot-element?text=X&label=Y  — screenshot a specific element by text
--   GET  /screenshot-element?x=&y=&w=&h=&label=Y — screenshot a region
--   POST /exec      {code}           — execute arbitrary Lua code
--   POST /wait      {text,timeout}   — wait until element with text appears (polls)
--
-- App-specific routes: use M.route(method, path, handler) to register custom endpoints.

local M = {}

local socket = require("socket")
local server = nil
local customRoutes = {}
local pendingScreenshots = {}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

local function jsonEncode(obj)
    if type(obj) == "table" then
        local isArray = #obj > 0
        if isArray then
            local items = {}
            for _, v in ipairs(obj) do items[#items+1] = jsonEncode(v) end
            return "[" .. table.concat(items, ",") .. "]"
        else
            local items = {}
            for k, v in pairs(obj) do
                items[#items+1] = string.format('"%s":%s', k, jsonEncode(v))
            end
            return "{" .. table.concat(items, ",") .. "}"
        end
    elseif type(obj) == "string" then
        return '"' .. obj:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r') .. '"'
    elseif type(obj) == "number" then return tostring(obj)
    elseif type(obj) == "boolean" then return obj and "true" or "false"
    end
    return "null"
end
M.jsonEncode = jsonEncode

local function httpResponse(body, status, contentType)
    status = status or "200 OK"
    contentType = contentType or "application/json"
    return string.format(
        "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n%s",
        status, contentType, #body, body)
end
M.httpResponse = httpResponse

local function ok(data) return httpResponse(jsonEncode(data)) end
local function err(msg, code) return httpResponse(jsonEncode({error=msg}), code or "400 Bad Request") end

local function urlDecode(s)
    return s and s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h,16)) end) or ""
end

local function parseBody(body)
    local params = {}
    if not body or body == "" then return params end
    for k, v in body:gmatch("([^&=]+)=([^&]*)") do
        params[urlDecode(k)] = urlDecode(v)
    end
    return params
end

local function parseQuery(path)
    local base, qs = path:match("^([^?]+)%??(.*)")
    return base or path, parseBody(qs)
end

----------------------------------------------------------------
-- Display tree utilities
----------------------------------------------------------------

-- BFS search: find display objects by text content
local function findByText(searchText, maxResults)
    maxResults = maxResults or 10
    local results = {}
    local queue = {}
    for i = 1, display.currentStage.numChildren do
        queue[#queue+1] = display.currentStage[i]
    end
    local idx = 1
    while idx <= #queue and idx <= 5000 do
        local node = queue[idx]; idx = idx + 1
        if node then
            -- Check text property (display.newText) or _textObj (framework Text component)
            local txt = node.text or (node._textObj and node._textObj.text)
            if txt and txt:find(searchText, 1, true) then
                local b = node.contentBounds
                results[#results+1] = {
                    text = txt,
                    x = b and math.floor((b.xMin + b.xMax)/2) or 0,
                    y = b and math.floor((b.yMin + b.yMax)/2) or 0,
                    bounds = b and {xMin=math.floor(b.xMin), yMin=math.floor(b.yMin),
                                    xMax=math.floor(b.xMax), yMax=math.floor(b.yMax)},
                    hasOnPress = node._onPress ~= nil or (node.parent and node.parent._onPress ~= nil),
                    object = node,
                }
                if #results >= maxResults then break end
            end
            if node.numChildren then
                for i = 1, node.numChildren do
                    if node[i] then queue[#queue+1] = node[i] end
                end
            end
        end
    end
    return results
end

-- Find the deepest pressable ancestor of a display object
local function findPressableAncestor(obj)
    local current = obj
    while current do
        if current._onPress then return current end
        current = current.parent
    end
    return nil
end

-- Walk up to find nearest parent View (has _bg property) for better screenshot context
local function findParentView(obj)
    local current = obj and obj.parent
    while current and current ~= display.currentStage do
        if current._bg then return current end
        current = current.parent
    end
    return nil
end

-- Dump display tree as JSON-friendly table
local function dumpTree(group, maxDepth, depth)
    depth = depth or 0
    maxDepth = maxDepth or 8
    if depth > maxDepth or not group then return nil end

    local node = {}
    local b = group.contentBounds
    if group.text then node.text = group.text end
    if group._textObj then node.text = group._textObj.text end
    if group._isScrollView then node.type = "ScrollView" end
    if group._onPress then node.pressable = true end
    if group._bg then node.type = node.type or "View" end
    if b then
        node.bounds = {math.floor(b.xMin), math.floor(b.yMin), math.floor(b.xMax), math.floor(b.yMax)}
    end
    node.visible = group.isVisible ~= false
    if group.numChildren and group.numChildren > 0 then
        node.children = {}
        for i = 1, group.numChildren do
            local child = dumpTree(group[i], maxDepth, depth + 1)
            if child then node.children[#node.children+1] = child end
        end
        if #node.children == 0 then node.children = nil end
    end
    return node
end

-- Simulate tap at screen coordinates via touch overlay / direct dispatch
local function simulateTapAt(x, y, callback)
    timer.performWithDelay(1, function()
        -- Find the topmost touchable object at (x,y) and dispatch tap
        local function findAndTap(grp)
            if not grp or not grp.numChildren then return false end
            for i = grp.numChildren, 1, -1 do
                local child = grp[i]
                if child and child.isVisible ~= false then
                    local cb = child.contentBounds
                    if cb and x >= cb.xMin and x <= cb.xMax and y >= cb.yMin and y <= cb.yMax then
                        -- Recurse first
                        if child.numChildren then
                            if findAndTap(child) then return true end
                        end
                        -- Check for press handler
                        if child._onPress then
                            child._onPress({name="tap", x=x, y=y, target=child})
                            if callback then callback(true, child) end
                            return true
                        end
                    end
                end
            end
            return false
        end
        local found = findAndTap(display.currentStage)
        if not found and callback then callback(false) end
    end)
end

-- Simulate touch drag sequence
local function simulateDrag(x, y, dx, dy, duration)
    duration = duration or 200
    local steps = math.max(3, math.floor(duration / 16))

    timer.performWithDelay(1, function()
        -- Find the touch overlay or touchable at (x,y)
        local function findTouchTarget(grp)
            if not grp or not grp.numChildren then return nil end
            for i = grp.numChildren, 1, -1 do
                local child = grp[i]
                if child and child.isVisible ~= false then
                    local cb = child.contentBounds
                    if cb and x >= cb.xMin and x <= cb.xMax and y >= cb.yMin and y <= cb.yMax then
                        -- Check children first (depth-first, front to back)
                        if child.numChildren then
                            local found = findTouchTarget(child)
                            if found then return found end
                        end
                        -- Touch overlay or any touch listener
                        if child._isTouchOverlay or (child._tableListeners and child._tableListeners.touch) then
                            return child
                        end
                    end
                end
            end
            return nil
        end

        local target = findTouchTarget(display.currentStage)
        if not target then return end

        -- Began
        target:dispatchEvent({name="touch", phase="began", x=x, y=y, target=target})

        -- Moved (spread across duration)
        for s = 1, steps do
            local frac = s / steps
            timer.performWithDelay(s * (duration / steps), function()
                target:dispatchEvent({
                    name="touch", phase="moved",
                    x = x + dx * frac, y = y + dy * frac,
                    target = target
                })
            end)
        end

        -- Ended
        timer.performWithDelay(duration + 16, function()
            target:dispatchEvent({name="touch", phase="ended", x=x+dx, y=y+dy, target=target})
        end)
    end)
end

----------------------------------------------------------------
-- Screenshot (async)
-- Uses Container-to-Group swap to ensure display.save captures
-- Container children (which display.save may skip due to stencil
-- buffer re-rendering issues in some Solar2D builds).
----------------------------------------------------------------

-- Find all Container objects (anchorChildren==true) in the display tree
local function findContainers(group, result)
    result = result or {}
    if not group or not group.numChildren then return result end
    for i = 1, group.numChildren do
        local child = group[i]
        if child then
            if child.anchorChildren == true and child.numChildren then
                result[#result+1] = child
            end
            if child.numChildren then
                findContainers(child, result)
            end
        end
    end
    return result
end

-- Temporarily replace Containers with Groups so display.save captures all content.
-- Returns a restore function that undoes the swap.
local function swapContainersForSave()
    local containers = findContainers(display.currentStage)
    if #containers == 0 then return nil end

    local swaps = {}
    for _, container in ipairs(containers) do
        local parent = container.parent
        if parent then
            -- Create a replacement Group at the same visual position.
            -- Container uses center-origin: its (x,y) is the center.
            -- Container children are in center-origin coords (0,0 = center).
            -- We create a Group at the Container's position.
            local tmpGroup = display.newGroup()
            tmpGroup.x = container.x
            tmpGroup.y = container.y
            tmpGroup.alpha = container.alpha
            tmpGroup.rotation = container.rotation
            tmpGroup.xScale = container.xScale
            tmpGroup.yScale = container.yScale

            -- Move all children from Container to the temp Group.
            -- Children keep their relative positions (center-origin coords).
            local children = {}
            while container.numChildren > 0 do
                local child = container[1]
                children[#children+1] = child
                tmpGroup:insert(child)
            end

            -- Hide the Container (it's now empty but still in the tree)
            local wasVisible = container.isVisible
            container.isVisible = false

            -- Insert the temp Group into the parent
            parent:insert(tmpGroup)

            swaps[#swaps+1] = {
                container = container,
                tmpGroup = tmpGroup,
                parent = parent,
                children = children,
                wasVisible = wasVisible,
            }
        end
    end

    if #swaps == 0 then return nil end

    -- Return restore function
    return function()
        for _, swap in ipairs(swaps) do
            -- Move children back to Container
            for _, child in ipairs(swap.children) do
                swap.container:insert(child)
            end
            -- Restore Container visibility
            swap.container.isVisible = swap.wasVisible
            -- Remove temp Group
            if swap.tmpGroup and swap.tmpGroup.removeSelf then
                swap.tmpGroup:removeSelf()
            end
        end
    end
end

local function processPendingScreenshots()
    for i = #pendingScreenshots, 1, -1 do
        local pending = pendingScreenshots[i]
        if not pending.captureRequested then
            pending.captureRequested = true
            pending.method = pending._method or "captureBounds"
            if pending._skipCapture then
                -- Capture already handled externally (e.g. captureBounds region)
            else
                timer.performWithDelay(50, function()
                    pcall(function()
                        if pending.target then
                            -- Save specific display object via display.save
                            pending.method = pending._method or "save_target"
                            display.save(pending.target, {
                                filename = pending.filename,
                                baseDir = system.TemporaryDirectory,
                            })
                        else
                            -- Swap Containers for Groups to ensure all content is captured.
                            -- display.save re-renders the tree to a bitmap, and some Solar2D
                            -- builds fail to render Container stencil children during this
                            -- off-screen render pass.
                            local restore = swapContainersForSave()
                            pending.method = pending._method or (restore and "save_stage_swapped" or "save_stage")
                            -- Store restore function so it runs after file is written
                            pending._restoreContainers = restore
                            display.save(display.currentStage, {
                                filename = pending.filename,
                                baseDir = system.TemporaryDirectory,
                                captureOffscreenArea = true,
                            })
                        end
                    end)
                end)
            end
        else
            local f = io.open(pending.path, "rb")
            if f then
                local data = f:read("*all"); f:close()
                -- Restore any swapped Containers now that the file is written
                if pending._restoreContainers then
                    pending._restoreContainers()
                    pending._restoreContainers = nil
                end
                local b64ok, b64 = pcall(require, "tests.infra.base64")
                local resp
                -- Include visible area info for proper cropping
                local visibleArea = {
                    screenOriginX = display.screenOriginX or 0,
                    screenOriginY = display.screenOriginY or 0,
                    actualContentWidth = display.actualContentWidth or display.contentWidth,
                    actualContentHeight = display.actualContentHeight or display.contentHeight,
                    contentWidth = display.contentWidth,
                    contentHeight = display.contentHeight,
                }
                local result = {success=true, filename=pending.filename,
                               size=#data, method=pending.method, visibleArea=visibleArea}
                if pending._bounds then result.bounds = pending._bounds end
                if b64ok then
                    result.base64 = b64.encode(data)
                else
                    result.path = pending.path
                end
                resp = ok(result)
                pcall(function() pending.client:send(resp) end)
                pcall(function() pending.client:close() end)
                table.remove(pendingScreenshots, i)
            else
                if (system.getTimer() - pending.startTime) > 10000 then
                    -- Restore Containers on timeout too
                    if pending._restoreContainers then
                        pending._restoreContainers()
                        pending._restoreContainers = nil
                    end
                    pcall(function() pending.client:send(err("Screenshot timeout","500 Error")) end)
                    pcall(function() pending.client:close() end)
                    table.remove(pendingScreenshots, i)
                end
            end
        end
    end
end

----------------------------------------------------------------
-- HTTP request parsing
----------------------------------------------------------------

local function readRequest(client)
    client:settimeout(5)
    local buffer = ""
    while true do
        local line, e = client:receive("*l")
        if not line then return nil, e end
        if line == "" then break end
        buffer = buffer .. line .. "\r\n"
    end
    local contentLength = tonumber(buffer:match("Content%-Length:%s*(%d+)")) or 0
    local body = ""
    if contentLength > 0 then
        body = client:receive(contentLength) or ""
    end
    return buffer, body
end

----------------------------------------------------------------
-- Route handler
----------------------------------------------------------------

local function handleClient(client)
    local req, body = readRequest(client)
    if not req then client:close(); return end

    local requestLine = req:match("^([^\r\n]+)")
    local method, rawPath = requestLine:match("^([^%s]+)%s+([^%s]+)")
    if not method then
        client:send(err("Invalid request")); client:close(); return
    end

    local path, query = parseQuery(rawPath)
    local params = parseBody(body)
    -- Merge query into params (query takes lower priority)
    for k, v in pairs(query) do if not params[k] then params[k] = v end end

    local response

    -- ============================================================
    -- Generic endpoints (work with any Solar2D app)
    -- ============================================================

    if method == "GET" and path == "/status" then
        response = ok({
            running = true, time = os.time(),
            screen = {width = display.contentWidth, height = display.contentHeight},
            platform = system and system.getInfo and system.getInfo("platformName") or "unknown",
        })

    elseif method == "GET" and path == "/screenshot" then
        local label = params.label or ("shot_" .. os.time())
        local filename = label .. ".png"
        table.insert(pendingScreenshots, {
            client = client,
            path = system.pathForFile(filename, system.TemporaryDirectory),
            filename = filename,
            startTime = system.getTimer(),
            captureRequested = false,
            target = nil, -- full screen; custom routes can override
        })
        return -- async response

    elseif method == "GET" and path == "/screenshot-element" then
        local text = params.text
        local label = params.label or "element"
        local padding = tonumber(params.padding) or 10

        if text then
            -- Text-based element capture
            timer.performWithDelay(1, function()
                local matches = findByText(text, 1)
                local match = matches[1]
                if not match or not match.object then
                    local resp = err("Element not found: " .. text)
                    pcall(function() client:send(resp) end)
                    pcall(function() client:close() end)
                    return
                end
                -- Walk up to find parent View for better context
                local target = findParentView(match.object) or match.object
                local b = target.contentBounds
                local bounds = b and {
                    xMin=math.floor(b.xMin), yMin=math.floor(b.yMin),
                    xMax=math.floor(b.xMax), yMax=math.floor(b.yMax)
                }
                local filename = label .. ".png"
                table.insert(pendingScreenshots, {
                    client = client,
                    path = system.pathForFile(filename, system.TemporaryDirectory),
                    filename = filename,
                    startTime = system.getTimer(),
                    captureRequested = false,
                    target = target,
                    _method = "element_text",
                    _bounds = bounds,
                })
            end)
            return -- async

        elseif params.x and params.y then
            -- Region-based capture
            local x = tonumber(params.x)
            local y = tonumber(params.y)
            local w = tonumber(params.w) or 100
            local h = tonumber(params.h) or 100
            local filename = label .. ".png"
            local bounds = {xMin=x, yMin=y, xMax=x+w, yMax=y+h}

            timer.performWithDelay(50, function()
                pcall(function()
                    local capture = display.captureBounds({
                        xMin = x, yMin = y,
                        xMax = x + w, yMax = y + h,
                    })
                    if capture then
                        display.save(capture, {
                            filename = filename,
                            baseDir = system.TemporaryDirectory,
                        })
                        -- Remove capture object after save
                        timer.performWithDelay(100, function()
                            if capture and capture.removeSelf then capture:removeSelf() end
                        end)
                    end
                end)
            end)

            table.insert(pendingScreenshots, {
                client = client,
                path = system.pathForFile(filename, system.TemporaryDirectory),
                filename = filename,
                startTime = system.getTimer(),
                captureRequested = false,
                target = nil, -- handled by captureBounds above
                _method = "element_region",
                _bounds = bounds,
                _skipCapture = true, -- capture handled manually above
            })
            return -- async
        else
            response = err("Missing text or x,y parameters")
        end

    elseif method == "POST" and path == "/tap" then
        local x = tonumber(params.x)
        local y = tonumber(params.y)
        if x and y then
            simulateTapAt(x, y)
            response = ok({success=true, action="tap", x=x, y=y})
        else
            response = err("Missing x,y")
        end

    elseif method == "POST" and path == "/tap-text" then
        local text = params.text or params.title
        local index = tonumber(params.index) or 1
        if text then
            timer.performWithDelay(1, function()
                local matches = findByText(text, index)
                local target = matches[index]
                if target then
                    simulateTapAt(target.x, target.y)
                end
            end)
            response = ok({success=true, text=text, index=index})
        else
            response = err("Missing text")
        end

    elseif method == "POST" and path == "/longpress" then
        local x = tonumber(params.x)
        local y = tonumber(params.y)
        local ms = tonumber(params.ms) or 500
        if x and y then
            timer.performWithDelay(1, function()
                -- Began
                local evt = {name="touch", phase="began", x=x, y=y}
                -- Find target
                local function findTouch(grp)
                    if not grp or not grp.numChildren then return nil end
                    for i = grp.numChildren, 1, -1 do
                        local c = grp[i]
                        if c and c.isVisible ~= false then
                            local cb = c.contentBounds
                            if cb and x >= cb.xMin and x <= cb.xMax and y >= cb.yMin and y <= cb.yMax then
                                if c.numChildren then
                                    local found = findTouch(c)
                                    if found then return found end
                                end
                                if c._isTouchOverlay or c._onPress or c._onLongPress then
                                    return c
                                end
                            end
                        end
                    end
                    return nil
                end
                local target = findTouch(display.currentStage)
                if target then
                    evt.target = target
                    target:dispatchEvent(evt)
                    timer.performWithDelay(ms, function()
                        evt.phase = "ended"
                        target:dispatchEvent(evt)
                    end)
                end
            end)
            response = ok({success=true, action="longpress", x=x, y=y, ms=ms})
        else
            response = err("Missing x,y")
        end

    elseif method == "POST" and path == "/drag" then
        local x  = tonumber(params.x) or 0
        local y  = tonumber(params.y) or 0
        local dx = tonumber(params.dx) or 0
        local dy = tonumber(params.dy) or 0
        local ms = tonumber(params.ms) or 200
        simulateDrag(x, y, dx, dy, ms)
        response = ok({success=true, action="drag", from={x=x,y=y}, delta={dx=dx,dy=dy}, ms=ms})

    elseif method == "POST" and path == "/scroll" then
        local x  = tonumber(params.x) or display.contentCenterX
        local y  = tonumber(params.y) or display.contentCenterY
        local dx = tonumber(params.dx) or 0
        local dy = tonumber(params.dy) or 0
        timer.performWithDelay(1, function()
            -- Find ScrollView at position and dispatch mouse scroll
            local function findScrollAt(grp)
                if not grp or not grp.numChildren then return nil end
                for i = grp.numChildren, 1, -1 do
                    local c = grp[i]
                    if c and c.isVisible ~= false then
                        local cb = c.contentBounds
                        if cb and x >= cb.xMin and x <= cb.xMax and y >= cb.yMin and y <= cb.yMax then
                            if c.numChildren then
                                local found = findScrollAt(c)
                                if found then return found end
                            end
                            if c._isTouchOverlay then return c end
                        end
                    end
                end
                return nil
            end
            local overlay = findScrollAt(display.currentStage)
            if overlay then
                overlay:dispatchEvent({name="mouse", type="scroll", x=x, y=y, scrollX=dx, scrollY=dy})
            end
        end)
        response = ok({success=true, action="scroll", x=x, y=y, dx=dx, dy=dy})

    elseif method == "GET" and path == "/tree" then
        local maxDepth = tonumber(params.depth) or 8
        timer.performWithDelay(1, function()
            local tree = dumpTree(display.currentStage, maxDepth)
            local resp = ok({tree=tree})
            pcall(function() client:send(resp) end)
            pcall(function() client:close() end)
        end)
        return -- async

    elseif method == "GET" and path == "/find" then
        local text = params.text
        local limit = tonumber(params.limit) or 20
        if text then
            local results = findByText(text, limit)
            response = ok({results=results, count=#results})
        else
            response = err("Missing text parameter")
        end

    elseif method == "POST" and path == "/exec" then
        local code = params.code
        if code then
            timer.performWithDelay(0, function()
                local loadfn = loadstring or load
                local fn, compErr = loadfn(code, "=remote")
                if fn then
                    local success, result = pcall(fn)
                    print("[EXEC] " .. (success and "OK: " .. tostring(result) or "ERROR: " .. tostring(result)))
                else
                    print("[EXEC] COMPILE ERROR: " .. tostring(compErr))
                end
            end)
            response = ok({success=true, message="Code scheduled"})
        else
            response = err("Missing code")
        end

    elseif method == "POST" and path == "/wait" then
        local text = params.text
        local timeout = tonumber(params.timeout) or 5000
        if text then
            -- Poll for element with text, respond when found or timeout
            local startTime = system.getTimer()
            local function poll()
                local results = findByText(text, 1)
                if #results > 0 then
                    local resp = ok({found=true, elapsed=math.floor(system.getTimer()-startTime), result=results[1]})
                    pcall(function() client:send(resp) end)
                    pcall(function() client:close() end)
                elseif (system.getTimer() - startTime) > timeout then
                    local resp = ok({found=false, elapsed=math.floor(system.getTimer()-startTime)})
                    pcall(function() client:send(resp) end)
                    pcall(function() client:close() end)
                else
                    timer.performWithDelay(100, poll)
                end
            end
            timer.performWithDelay(100, poll)
            return -- async
        else
            response = err("Missing text")
        end

    else
        -- Check custom routes
        local key = method .. " " .. path
        if customRoutes[key] then
            response = customRoutes[key](params, client)
            if not response then return end -- handler sent async response
        else
            response = err("Not found", "404 Not Found")
        end
    end

    client:send(response)
    client:close()
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

--- Register a custom route handler
--- handler(params, client) → response string, or nil for async
function M.route(method, path, handler)
    customRoutes[method .. " " .. path] = handler
end

--- Start the test server
function M.start(port)
    port = port or 9876
    server = socket.bind("*", port)
    if not server then
        print("[TEST_SERVER] Failed to bind to port " .. port)
        return false
    end
    server:settimeout(0)
    print("[TEST_SERVER] Started on port " .. port)
    M._running = true
    M._port = port

    timer.performWithDelay(50, function()
        if not M._running then return end
        local client = server:accept()
        if client then
            timer.performWithDelay(10, function()
                local success, e = pcall(handleClient, client)
                if not success then
                    print("[TEST_SERVER] Error: " .. tostring(e))
                    pcall(function() client:close() end)
                end
            end)
        end
    end, 0)

    timer.performWithDelay(100, function()
        if not M._running then return end
        processPendingScreenshots()
    end, 0)

    return true
end

function M.stop()
    M._running = false
    if server then server:close(); server = nil end
end

-- Expose utilities for custom route handlers
M.ok = ok
M.err = err
M.findByText = findByText
M.simulateTapAt = simulateTapAt
M.simulateDrag = simulateDrag
M.dumpTree = dumpTree

return M
