-- test_server.lua — HTTP test server for Solar2D
-- Uses coroutines for concurrent client handling

local M = {}

local socket = require("socket")
local server = nil
local callbacks = {}

-- Pending screenshot requests
local pendingScreenshots = {}

-- Auto-sweep state
local sweep = nil

-- JSON encode
local function jsonEncode(obj)
    if type(obj) == "table" then
        local isArray = #obj > 0
        if isArray then
            local items = {}
            for _, v in ipairs(obj) do
                table.insert(items, jsonEncode(v))
            end
            return "[" .. table.concat(items, ",") .. "]"
        else
            local items = {}
            for k, v in pairs(obj) do
                table.insert(items, string.format('"%s":%s', k, jsonEncode(v)))
            end
            return "{" .. table.concat(items, ",") .. "}"
        end
    elseif type(obj) == "string" then
        return string.format('"%s"', obj:gsub('"', '\\"'):gsub("\n", "\\n"))
    elseif type(obj) == "number" then
        return tostring(obj)
    elseif type(obj) == "boolean" then
        return obj and "true" or "false"
    elseif obj == nil then
        return "null"
    end
    return "null"
end

-- HTTP response
local function httpResponse(body, status, contentType)
    status = status or "200 OK"
    contentType = contentType or "application/json"
    return string.format("HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n%s",
        status, contentType, #body, body)
end

-- Read HTTP request from client
local function readRequest(client)
    client:settimeout(5)

    local buffer = ""
    while true do
        local line, err = client:receive("*l")
        if not line then
            return nil, err
        end
        if line == "" then
            -- End of headers
            break
        end
        buffer = buffer .. line .. "\r\n"
    end

    -- Parse content length
    local contentLength = tonumber(buffer:match("Content%-Length:%s*(%d+)")) or 0

    -- Read body if any
    local body = ""
    if contentLength > 0 then
        body, err = client:receive(contentLength)
        if not body then
            return nil, err
        end
    end

    return buffer, body
end

-- Handle screenshot completion
local function processPendingScreenshots()
    for i = #pendingScreenshots, 1, -1 do
        local pending = pendingScreenshots[i]

        -- Trigger capture if not yet requested
        if not pending.captureRequested then
            pending.captureRequested = true
            timer.performWithDelay(50, function()
                -- display.save works reliably; captureScreen does not
                local ok, err = pcall(function()
                    display.save(display.currentStage, {
                        filename = pending.filename,
                        baseDir = system.TemporaryDirectory,
                    })
                end)
                print("[TEST_SERVER] display.save: " .. tostring(ok) .. (err and " err=" .. tostring(err) or ""))
            end)
            -- Wait for next poll to check file (skip rest of loop)
        else
            local f = io.open(pending.path, "rb")
            if f then
                local fileData = f:read("*all")
                f:close()

                local b64 = require("tests.infra.base64")
                local encoded = b64.encode(fileData)
                local response = httpResponse(jsonEncode({
                    success = true,
                    filename = pending.filename,
                    base64 = encoded,
                    size = #fileData
                }))

                pcall(function() pending.client:send(response) end)
                pcall(function() pending.client:close() end)
                os.remove(pending.path)

                table.remove(pendingScreenshots, i)
            elseif (system.getTimer() - pending.startTime) > 10000 then
                -- Timeout after 10 seconds
                print("[TEST_SERVER] Screenshot timeout, checking file: " .. tostring(pending.path))
                -- List directory contents for debugging
                local dir = system.pathForFile("", system.TemporaryDirectory)
                if dir then
                    local handle = io.popen("ls -la '" .. dir .. "' 2>/dev/null | tail -5")
                    if handle then
                        local result = handle:read("*a")
                        handle:close()
                        print("[TEST_SERVER] Dir contents: " .. tostring(result))
                    end
                end
                local response = httpResponse(jsonEncode({
                    success = false,
                    error = "Screenshot capture timeout"
                }), "500 Error")

                pcall(function() pending.client:send(response) end)
                pcall(function() pending.client:close() end)

                table.remove(pendingScreenshots, i)
            end
        end
    end
end

-- Handle a client connection
local function handleClient(client)
    local req, body = readRequest(client)
    if not req then
        client:close()
        return
    end

    -- Parse request line
    local requestLine = req:match("^([^\r\n]+)")
    local method, path = requestLine:match("^([^%s]+)%s+([^%s]+)")
    if not method or not path then
        print("[TEST_SERVER] Invalid request: " .. tostring(requestLine))
        client:send(httpResponse('{"error":"Invalid request"}', "400 Bad Request"))
        client:close()
        return
    end

    -- Route request
    local response
    if method == "GET" and path == "/status" then
        response = httpResponse(jsonEncode({
            running = true,
            time = os.time(),
            platform = system and system.getInfo and system.getInfo("platformName") or "unknown",
        }))
    elseif method == "POST" and path == "/run" then
        local pattern = body:match("pattern=([^&]+)") or "all"
        pattern = pattern:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        local ok, testRunner = pcall(require, "test_runner_solar2d")
        if ok then
            local results = testRunner.run(pattern)
            response = httpResponse(jsonEncode({
                success = results.failed == 0,
                passed = results.passed,
                failed = results.failed,
                files = results.files,
            }))
        else
            response = httpResponse(jsonEncode({ error = "Test runner not available" }), "500 Error")
        end
    elseif method == "POST" and path == "/exec" then
        local code = body:match("code=([^&]+)")
        if code then
            code = code:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
            -- Defer execution to main thread to avoid native object creation in socket callback
            timer.performWithDelay(0, function()
                local loadfn = loadstring or load
                local fn, err = loadfn(code, "=remote")
                if fn then
                    local ok, result = pcall(fn)
                    print("[EXEC] " .. (ok and "OK: " .. tostring(result) or "ERROR: " .. tostring(result)))
                else
                    print("[EXEC] COMPILE ERROR: " .. tostring(err))
                end
            end)
            response = httpResponse(jsonEncode({ success = true, message = "Code scheduled for execution" }))
        else
            response = httpResponse(jsonEncode({ error = "Missing code" }), "400 Bad Request")
        end
    elseif method == "POST" and path == "/tap-button" then
        -- Find a button by its text label and tap it
        -- Usage: POST /tap-button  title=Start
        local title = body:match("title=([^&]+)")
        if title then
            title = title:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
            timer.performWithDelay(1, function()
                -- Breadth-first search through display tree
                local queue = {}
                for i = 1, display.currentStage.numChildren do
                    queue[#queue+1] = display.currentStage[i]
                end
                local idx = 1
                while idx <= #queue and idx <= 2000 do
                    local node = queue[idx]
                    idx = idx + 1
                    if node then
                        -- Check if this node's _textObj matches
                        if node._textObj and node._textObj.text == title then
                            -- Text found — tap its parent (the Button View with _onPress)
                            local target = node.parent
                            if target and target._onPress then
                                target._onPress({name="tap", target=target})
                                print("[TAP-BUTTON] Tapped parent._onPress for: " .. title)
                                return
                            elseif node._onPress then
                                node._onPress({name="tap", target=node})
                                print("[TAP-BUTTON] Tapped node._onPress for: " .. title)
                                return
                            end
                            -- No handler on this match — continue searching for another
                        end
                        -- Enqueue children
                        if node.numChildren then
                            for i = 1, node.numChildren do
                                if node[i] then queue[#queue+1] = node[i] end
                            end
                        end
                    end
                end
                print("[TAP-BUTTON] '" .. title .. "' not found (searched " .. (idx-1) .. " nodes)")
            end)
            response = httpResponse(jsonEncode({ success = true, title = title }))
        else
            response = httpResponse(jsonEncode({ error = "Missing title" }), "400 Bad Request")
        end
    elseif method == "GET" and path == "/categories" then
        local categories = {
            { key = "Basics", label = "基础" },
            { key = "Forms", label = "表单" },
            { key = "Lists", label = "列表" },
            { key = "Nav", label = "导航" },
            { key = "Animation", label = "动画" },
            { key = "Overlay", label = "弹层" },
            { key = "Layout", label = "布局" },
            { key = "Advanced", label = "高级" },
            { key = "Interop", label = "互操" },
        }
        response = httpResponse(jsonEncode({ categories = categories }))
    elseif method == "POST" and path == "/tap" then
        local category = body:match("category=([^&]+)")
        if category then
            category = category:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
            if callbacks.onCategoryTap then
                callbacks.onCategoryTap(category)
            end
            response = httpResponse(jsonEncode({ success = true, action = "category", target = category }))
        else
            response = httpResponse(jsonEncode({ error = "Missing category" }), "400 Bad Request")
        end
    elseif method == "POST" and path == "/navigate" then
        local route = body:match("route=([^&]+)")
        if route then
            route = route:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
            if callbacks.onNavigate then
                callbacks.onNavigate(route)
            end
            response = httpResponse(jsonEncode({ success = true, route = route }))
        else
            response = httpResponse(jsonEncode({ error = "Missing route" }), "400 Bad Request")
        end
    elseif method == "POST" and path == "/drag" then
        -- Simulate drag gesture on Slider at specific coordinates
        local x = tonumber(body:match("x=(%d+)")) or 0
        local y = tonumber(body:match("y=(%d+)")) or 0
        local dx = tonumber(body:match("dx=(%-?%d+)")) or 50  -- default drag right 50px
        local dy = tonumber(body:match("dy=(%-?%d+)")) or 0

        -- Dispatch touch events to simulate drag
        timer.performWithDelay(0, function()
            -- Fire custom event that Slider can listen for (via Runtime)
            local event = {
                name = "test_drag",
                x = x,
                y = y,
                dx = dx,
                dy = dy,
                phase = "began"
            }
            Runtime:dispatchEvent(event)

            -- After short delay, dispatch moved and ended
            timer.performWithDelay(50, function()
                event.phase = "moved"
                event.x = x + dx
                event.y = y + dy
                Runtime:dispatchEvent(event)
            end)

            timer.performWithDelay(100, function()
                event.phase = "ended"
                Runtime:dispatchEvent(event)
            end)
        end)

        response = httpResponse(jsonEncode({
            success = true,
            action = "drag",
            start = {x = x, y = y},
            delta = {dx = dx, dy = dy},
            end_pos = {x = x + dx, y = y + dy}
        }))
    elseif method == "GET" and path == "/screenshot" then
        -- Screenshot: saves to TemporaryDirectory, returns {path, filename}
        local label = body and body:match("label=([^&]+)") or ("shot_" .. os.time())
        label = label:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        local filename = label .. ".png"
        local screenshotPath = system.pathForFile(filename, system.TemporaryDirectory)

        table.insert(pendingScreenshots, {
            client = client,
            path = screenshotPath,
            filename = filename,
            startTime = system.getTimer(),
            captureRequested = false
        })
        return  -- response sent asynchronously by processPendingScreenshots

    elseif method == "GET" and path == "/pages" then
        -- Full page manifest: all categories and their demo screens
        local manifest = {
            { category = "Basics",    pages = { "View","Text","Image","Button","Pressable","Touchable","LinearGradient" } },
            { category = "Forms",     pages = { "TextInput","Switch","Modal","Indicator","KeyboardAV" } },
            { category = "Lists",     pages = { "ScrollView","FlatList","VirtualList","SectionList" } },
            { category = "Nav",       pages = { "StackNav","Headers","DrawerNav" } },
            { category = "Animation", pages = { "Timing","Spring","Sequence","Parallel","Loop" } },
            { category = "Overlay",   pages = { "Alert","ActionSheet","Toast","Popover" } },
            { category = "Layout",    pages = { "Flexbox","Responsive","SafeArea","SafeAreaView","Spacing" } },
            { category = "Advanced",  pages = { "Badge","Progress","Accordion","Dropdown","Card","Gesture Handler","useId","useImperativeHandle","useSyncExternalStore" } },
            { category = "Interop",   pages = { "ReactInSolar","Solar2DInReact","AsyncStorage","VectorIcons","Slider","DeviceInfo","DateTimePicker" } },
        }
        response = httpResponse(jsonEncode({ pages = manifest }))

    elseif method == "POST" and path == "/autotest/start" then
        -- Start automated full-sweep: navigate every page, screenshot each one
        if sweep and sweep.running then
            response = httpResponse(jsonEncode({ error = "Already running" }), "409 Conflict")
        else
            local delay = tonumber(body and body:match("delay=(%d+)")) or 1500
            sweep = { running = true, current = nil, completed = 0, total = 0,
                      results = {}, startTime = system.getTimer() }

            -- Build flat list of all (category, page) pairs
            local queue = {}
            local manifest = {
                { cat="Basics",    pages={"View","Text","Image","Button","Pressable","Touchable","LinearGradient"} },
                { cat="Forms",     pages={"TextInput","Switch","Modal","Indicator","KeyboardAV"} },
                { cat="Lists",     pages={"ScrollView","FlatList","VirtualList","SectionList"} },
                { cat="Nav",       pages={"StackNav","Headers","DrawerNav"} },
                { cat="Animation", pages={"Timing","Spring","Sequence","Parallel","Loop"} },
                { cat="Overlay",   pages={"Alert","ActionSheet","Toast","Popover"} },
                { cat="Layout",    pages={"Flexbox","Responsive","SafeArea","SafeAreaView","Spacing"} },
                { cat="Advanced",  pages={"Badge","Progress","Accordion","Dropdown","Card"} },
                { cat="Interop",   pages={"ReactInSolar","Solar2DInReact","AsyncStorage","VectorIcons","Slider","DeviceInfo","DateTimePicker"} },
            }
            for _, c in ipairs(manifest) do
                for _, p in ipairs(c.pages) do
                    queue[#queue+1] = { category = c.cat, page = p }
                end
            end
            sweep.total = #queue

            -- State machine: navigate → wait → screenshot → next
            local step = 1
            local function runNext()
                if not sweep or not sweep.running then return end
                if step > #queue then
                    sweep.running = false
                    sweep.completedAt = system.getTimer()
                    print("[AUTOTEST] Complete: " .. sweep.completed .. "/" .. sweep.total)
                    return
                end
                local item = queue[step]
                step = step + 1
                sweep.current = item.category .. "/" .. item.page

                -- Navigate
                if callbacks.onNavigate then
                    callbacks.onNavigate(item.page)
                end

                -- Wait for render, then screenshot
                timer.performWithDelay(delay, function()
                    local filename = "autotest_" .. item.category .. "_" .. item.page:gsub("%s+","_") .. ".png"
                    local fpath = system.pathForFile(filename, system.TemporaryDirectory)
                    local ok, err = pcall(function()
                        display.save(display.currentStage, {
                            filename = filename,
                            baseDir = system.TemporaryDirectory,
                        })
                    end)
                    sweep.results[#sweep.results+1] = {
                        category = item.category,
                        page = item.page,
                        file = fpath,
                        ok = ok,
                        err = err and tostring(err) or nil,
                    }
                    sweep.completed = sweep.completed + 1
                    print("[AUTOTEST] " .. sweep.completed .. "/" .. sweep.total .. " " .. sweep.current)

                    -- Next page
                    timer.performWithDelay(50, runNext)
                end)
            end

            timer.performWithDelay(500, runNext)
            response = httpResponse(jsonEncode({ started = true, total = sweep.total, delay = delay }))
        end

    elseif method == "GET" and path == "/autotest/status" then
        if not sweep then
            response = httpResponse(jsonEncode({ running = false, completed = 0, total = 0 }))
        else
            local elapsed = sweep.completedAt and (sweep.completedAt - sweep.startTime) or (system.getTimer() - sweep.startTime)
            response = httpResponse(jsonEncode({
                running = sweep.running,
                current = sweep.current,
                completed = sweep.completed,
                total = sweep.total,
                elapsed_ms = math.floor(elapsed),
            }))
        end

    elseif method == "GET" and path == "/autotest/results" then
        if not sweep then
            response = httpResponse(jsonEncode({ results = {}, completed = 0 }))
        else
            response = httpResponse(jsonEncode({
                completed = sweep.completed,
                total = sweep.total,
                running = sweep.running,
                results = sweep.results,
            }))
        end

    elseif method == "POST" and path == "/autotest/stop" then
        if sweep then sweep.running = false end
        response = httpResponse(jsonEncode({ stopped = true }))

    else
        response = httpResponse(jsonEncode({ error = "Not found" }), "404 Not Found")
    end

    client:send(response)
    client:close()
end

-- Start server
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

    -- Accept loop - runs in timer
    timer.performWithDelay(50, function()
        if not M._running then return end

        local client = server:accept()
        if client then
            print("[TEST_SERVER] Client connected")
            -- Handle client in a coroutine-based timer
            timer.performWithDelay(10, function()
                local ok, err = pcall(handleClient, client)
                if not ok then
                    print("[TEST_SERVER] Error handling client: " .. tostring(err))
                    client:close()
                end
            end)
        end
    end, 0)

    -- Screenshot polling loop
    timer.performWithDelay(100, function()
        if not M._running then return end
        processPendingScreenshots()
    end, 0)

    return true
end

function M.stop()
    M._running = false
    if server then
        server:close()
        server = nil
    end
end

-- Callbacks
function M.onCategoryTap(fn) callbacks.onCategoryTap = fn end
function M.onTap(fn) callbacks.onTap = fn end
function M.onNavigate(fn) callbacks.onNavigate = fn end

return M
