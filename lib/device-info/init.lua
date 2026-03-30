--- DeviceInfo module.
-- react-native-device-info implementation for Solar2D.
-- @module lib.device-info

local M = {}

-- Helper to safely get system info
local function getInfo(key)
    local ok, result = pcall(function()
        return system.getInfo(key)
    end)
    if ok then
        return result
    end
    return nil
end

--- Get unique device ID.
-- @return string Device ID
function M.getUniqueId()
    return getInfo("deviceID") or "unknown"
end

--- Get device manufacturer.
-- @return string Manufacturer
function M.getManufacturer()
    return getInfo("manufacturer") or "Solar2D"
end

--- Get device brand.
-- @return string Brand
function M.getBrand()
    local platform = getInfo("platform")
    if platform == "ios" then
        return "Apple"
    elseif platform == "android" then
        return getInfo("manufacturer") or "Android"
    end
    return "Solar2D"
end

--- Get device model.
-- @return string Model
function M.getModel()
    return getInfo("model") or getInfo("architecture") or "Simulator"
end

--- Get device ID (same as uniqueId for Solar2D).
-- @return string Device ID
function M.getDeviceId()
    return M.getUniqueId()
end

--- Get system name.
-- @return string System name
function M.getSystemName()
    local platform = getInfo("platform")
    if platform == "ios" then
        return "iOS"
    elseif platform == "android" then
        return "Android"
    end
    return platform or "Unknown"
end

--- Get system version.
-- @return string System version
function M.getSystemVersion()
    return getInfo("platformVersion") or "1.0"
end

--- Get bundle ID (app name).
-- @return string Bundle ID
function M.getBundleId()
    return getInfo("appName") or "com.solar2d.app"
end

--- Get app name.
-- @return string App name
function M.getApplicationName()
    return getInfo("appName") or "Solar2D App"
end

--- Get app version.
-- @return string App version
function M.getVersion()
    return getInfo("appVersionString") or "1.0.0"
end

--- Get build number.
-- @return string Build number
function M.getBuildNumber()
    return getInfo("appVersion") or "1"
end

--- Get user agent (simplified).
-- @return string User agent string
function M.getUserAgent()
    local platform = getInfo("platform")
    local version = getInfo("platformVersion") or "1.0"
    local model = M.getModel()
    return string.format("Solar2D/%s (%s; %s)", version, platform or "unknown", model)
end

--- Get device locale.
-- @return string Locale identifier
function M.getDeviceLocale()
    return getInfo("localeIdentifier") or "en-US"
end

--- Get device country.
-- @return string Country code
function M.getDeviceCountry()
    local locale = M.getDeviceLocale()
    local country = locale:match("%-(%w+)$")
    return country or "US"
end

--- Get timezone.
-- @return string Timezone abbreviation
function M.getTimezone()
    local ok, result = pcall(function()
        return os.date("%Z")
    end)
    if ok then
        return result
    end
    return "UTC"
end

--- Get screen width.
-- @return number Screen width in pixels
function M.getScreenWidth()
    if display then
        return display.contentWidth
    end
    return 320 -- fallback for test environment
end

--- Get screen height.
-- @return number Screen height in pixels
function M.getScreenHeight()
    if display then
        return display.contentHeight
    end
    return 480 -- fallback for test environment
end

--- Get screen scale (pixels per point).
-- @return number Font scale
function M.getFontScale()
    if display and display.pixelHeight then
        return display.pixelHeight / display.contentHeight
    end
    return 1.0 -- fallback
end

--- Check if tablet.
-- @return boolean
function M.isTablet()
    if not display then
        return false
    end
    local aspect = display.contentWidth / display.contentHeight
    -- Tablets typically have aspect ratio closer to 4:3 or 3:4
    return aspect > 0.6 and aspect < 1.5
end

--- Check if emulator/simulator.
-- @return boolean
function M.isEmulator()
    local env = getInfo("environment")
    return env == "simulator" or env == "browser"
end

--- Get battery level (not available in Solar2D by default).
-- @return number Battery level (1.0 fallback)
function M.getBatteryLevel()
    -- Would require native plugin
    return 1.0
end

--- Check if battery charging (not available).
-- @return boolean
function M.isBatteryCharging()
    -- Would require native plugin
    return false
end

--- Get total memory (not available in Solar2D).
-- @return number Total memory (-1 fallback)
function M.getTotalMemory()
    return -1
end

--- Get used memory.
-- @return number Used memory in bytes
function M.getUsedMemory()
    return collectgarbage("count") * 1024
end

--- Get free disk storage (not available).
-- @return number Free disk storage (-1 fallback)
function M.getFreeDiskStorage()
    return -1
end

--- Get total disk capacity (not available).
-- @return number Total disk capacity (-1 fallback)
function M.getTotalDiskCapacity()
    return -1
end

--- Get IP address (not available without native plugin).
-- @return string IP address
function M.getIpAddress()
    return "127.0.0.1"
end

--- Get MAC address (not available without native plugin).
-- @return string MAC address
function M.getMacAddress()
    return "02:00:00:00:00:00"
end

--- Get all info as a table.
-- @return table Device info dictionary
function M.getAllInfo()
    return {
        uniqueId = M.getUniqueId(),
        manufacturer = M.getManufacturer(),
        brand = M.getBrand(),
        model = M.getModel(),
        systemName = M.getSystemName(),
        systemVersion = M.getSystemVersion(),
        bundleId = M.getBundleId(),
        appName = M.getApplicationName(),
        version = M.getVersion(),
        buildNumber = M.getBuildNumber(),
        userAgent = M.getUserAgent(),
        locale = M.getDeviceLocale(),
        country = M.getDeviceCountry(),
        timezone = M.getTimezone(),
        screenWidth = M.getScreenWidth(),
        screenHeight = M.getScreenHeight(),
        fontScale = M.getFontScale(),
        isTablet = M.isTablet(),
        isEmulator = M.isEmulator(),
        batteryLevel = M.getBatteryLevel(),
        usedMemory = M.getUsedMemory(),
    }
end

return M
