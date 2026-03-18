-- test_server.lua — HTTP test server for Solar2D
-- Uses coroutines for concurrent client handling

local M = {}

local socket = require("socket")
local server = nil
local callbacks = {}

-- Pending screenshot requests
local pendingScreenshots = {}

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
                -- Use display.capture on the stage (main display group)
                -- Note: Files are saved to Documents directory by default in Solar2D
                local stage = display.getCurrentStage()
                display.capture(stage, {
                    filename = pending.filename,
                    saveToPhotoLibrary = false,
                    captureOffscreenAreas = false,
                })
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
            elseif (system.getTimer() - pending.startTime) > 5000 then
                -- Timeout after 5 seconds
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
    elseif method == "GET" and path == "/screenshot" then
        -- Async screenshot capture - stores client for deferred response
        local filename = "screenshot_" .. os.time() .. ".png"
        -- Note: display.capture saves to Documents directory by default
        local screenshotPath = system.pathForFile(filename, system.DocumentsDirectory)

        -- Store pending request first
        table.insert(pendingScreenshots, {
            client = client,
            path = screenshotPath,
            filename = filename,
            startTime = system.getTimer(),
            captureRequested = false
        })

        -- Return immediately - response will be sent when screenshot is ready
        return
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
