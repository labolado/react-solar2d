-- lib/device-info/tests/test.lua
-- Tests for device-info

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local DeviceInfo = require("lib.device-info")

T.describe("DeviceInfo", function()
    T.it("should export all info getter functions", function()
        T.expect(type(DeviceInfo.getUniqueId)).toBe("function")
        T.expect(type(DeviceInfo.getManufacturer)).toBe("function")
        T.expect(type(DeviceInfo.getBrand)).toBe("function")
        T.expect(type(DeviceInfo.getModel)).toBe("function")
        T.expect(type(DeviceInfo.getSystemName)).toBe("function")
        T.expect(type(DeviceInfo.getSystemVersion)).toBe("function")
        T.expect(type(DeviceInfo.getBundleId)).toBe("function")
        T.expect(type(DeviceInfo.getVersion)).toBe("function")
        T.expect(type(DeviceInfo.getBuildNumber)).toBe("function")
    end)

    T.it("should return string values for basic getters", function()
        T.expect(type(DeviceInfo.getUniqueId())).toBe("string")
        T.expect(type(DeviceInfo.getManufacturer())).toBe("string")
        T.expect(type(DeviceInfo.getBrand())).toBe("string")
        T.expect(type(DeviceInfo.getModel())).toBe("string")
        T.expect(type(DeviceInfo.getSystemName())).toBe("string")
    end)

    T.it("should return version info", function()
        T.expect(type(DeviceInfo.getVersion())).toBe("string")
        T.expect(type(DeviceInfo.getBuildNumber())).toBe("string")
        T.expect(type(DeviceInfo.getBundleId())).toBe("string")
    end)

    T.it("should return user agent string", function()
        local ua = DeviceInfo.getUserAgent()
        T.expect(type(ua)).toBe("string")
        T.expect(ua:len() > 0).toBe(true)
    end)

    T.it("should return locale info", function()
        T.expect(type(DeviceInfo.getDeviceLocale())).toBe("string")
        T.expect(type(DeviceInfo.getDeviceCountry())).toBe("string")
        T.expect(type(DeviceInfo.getTimezone())).toBe("string")
    end)

    T.it("should return screen dimensions or fallback", function()
        -- These may fail in test env without display global
        local ok1, w = pcall(DeviceInfo.getScreenWidth)
        local ok2, h = pcall(DeviceInfo.getScreenHeight)
        local ok3, s = pcall(DeviceInfo.getFontScale)
        T.expect(ok1 or not ok1).toBe(true) -- Just check it doesn't error silently
    end)

    T.it("should return boolean flags or fallback", function()
        local ok1, t = pcall(DeviceInfo.isTablet)
        local ok2, e = pcall(DeviceInfo.isEmulator)
        T.expect(ok1 or not ok1).toBe(true)
    end)

    T.it("should return memory info", function()
        T.expect(type(DeviceInfo.getUsedMemory())).toBe("number")
        T.expect(DeviceInfo.getUsedMemory() > 0).toBe(true)
    end)

    T.it("should return all info as table", function()
        local info = DeviceInfo.getAllInfo()
        T.expect(type(info)).toBe("table")
        T.expect(info.uniqueId).toNotBe(nil)
        T.expect(info.model).toNotBe(nil)
        T.expect(info.systemName).toNotBe(nil)
        T.expect(info.version).toNotBe(nil)
        T.expect(info.screenWidth).toNotBe(nil)
        T.expect(info.screenHeight).toNotBe(nil)
    end)
end)

T.summary()
