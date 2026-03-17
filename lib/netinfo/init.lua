-- lib/netinfo/init.lua
-- @react-native-community/netinfo implementation for Solar2D
-- Network state detection using network.request polling

local M = {}

local listeners = {}
local isConnected = true
local currentType = "unknown"
local lastCheckTime = 0
local checkInterval = 30000 -- Check every 30 seconds
local checkTimer = nil

-- Connection types
local CONNECTION_TYPES = {
    WIFI = "wifi",
    CELLULAR = "cellular",
    UNKNOWN = "unknown",
    NONE = "none"
}

-- Check network connectivity
local function checkConnectivity()
    -- Use a lightweight HEAD request to check connectivity
    local testUrl = "https://www.google.com/generate_204"

    network.request(testUrl, "HEAD", function(event)
        local wasConnected = isConnected
        if event.isError or event.status ~= 204 then
            isConnected = false
            currentType = CONNECTION_TYPES.NONE
        else
            isConnected = true
            -- Try to determine type (simplified)
            currentType = CONNECTION_TYPES.UNKNOWN
        end

        -- Notify listeners if state changed
        if wasConnected ~= isConnected then
            M._notifyListeners()
        end
    end, { timeout = 5 })
end

-- Notify all listeners
function M._notifyListeners()
    local state = {
        isConnected = isConnected,
        isInternetReachable = isConnected,
        type = currentType,
        details = {
            isConnectionExpensive = currentType == CONNECTION_TYPES.CELLULAR
        }
    }

    for _, listener in ipairs(listeners) do
        listener(state)
    end
end

-- Get current network state
function M.fetch()
    return {
        isConnected = isConnected,
        isInternetReachable = isConnected,
        type = currentType,
        details = {
            isConnectionExpensive = currentType == CONNECTION_TYPES.CELLULAR
        }
    }
end

-- Add event listener
function M.addEventListener(eventType, listener)
    if eventType ~= "change" then
        return false
    end

    table.insert(listeners, listener)

    -- Start polling if first listener
    if #listeners == 1 then
        checkConnectivity() -- Initial check
        checkTimer = timer.performWithDelay(checkInterval, function()
            checkConnectivity()
        end, 0)
    end

    return {
        remove = function()
            M.removeEventListener(eventType, listener)
        end
    }
end

-- Remove event listener
function M.removeEventListener(eventType, listener)
    if eventType ~= "change" then
        return false
    end

    for i, l in ipairs(listeners) do
        if l == listener then
            table.remove(listeners, i)
            break
        end
    end

    -- Stop polling if no listeners
    if #listeners == 0 and checkTimer then
        timer.cancel(checkTimer)
        checkTimer = nil
    end

    return true
end

-- Configure (optional)
function M.configure(config)
    if config and config.checkInterval then
        checkInterval = config.checkInterval
        -- Restart timer if running
        if checkTimer then
            timer.cancel(checkTimer)
            checkTimer = timer.performWithDelay(checkInterval, function()
                checkConnectivity()
            end, 0)
        end
    end
end

return M
