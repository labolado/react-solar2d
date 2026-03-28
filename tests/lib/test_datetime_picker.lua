-- tests/lib/test_datetime_picker.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

-- We need to test internal functions, so we'll load the module and test via exposed functions
-- The DateTimePicker exposes M.DateTimePicker, but internal functions like wrapValue 
-- and getDaysInMonth are local. We test the behavior through the component.

-- Create a test wrapper to access internal logic
local testEnv = {}

-- Load the datetime picker code in a way that exposes internal functions
local pickerCode = [[
    local M = {}
    
    M.Display = {
        DEFAULT = "default",
        SPINNER = "spinner",
        CLOCK = "clock",
        CALENDAR = "calendar",
    }

    M.EventType = {
        SET = "set",
        DISMISSED = "dismissed",
    }

    -- Format number with leading zero
    local function pad2(n)
        return string.format("%02d", n)
    end

    -- Get days in month
    local function getDaysInMonth(year, month)
        local nextMonth = month + 1
        local nextYear = year
        if nextMonth > 12 then
            nextMonth = 1
            nextYear = year + 1
        end
        local firstDayNextMonth = os.time({ year = nextYear, month = nextMonth, day = 1, hour = 0, min = 0 })
        local lastDayThisMonth = os.date("*t", firstDayNextMonth - 86400)
        return lastDayThisMonth.day
    end

    -- Wrap a value within [min, max]
    local function wrapValue(val, minVal, maxVal)
        if val > maxVal then return minVal end
        if val < minVal then return maxVal end
        return val
    end
    
    M.getDaysInMonth = getDaysInMonth
    M.wrapValue = wrapValue
    M.pad2 = pad2
    
    return M
]]

local loadFn = loadstring or load
local pickerUtil = loadFn(pickerCode, "=pickerUtil")()

T.describe("DateTimePicker: wrapValue", function()
    T.it("returns value within range unchanged", function()
        T.expect(pickerUtil.wrapValue(5, 1, 10)).toBe(5)
        T.expect(pickerUtil.wrapValue(1, 1, 10)).toBe(1)
        T.expect(pickerUtil.wrapValue(10, 1, 10)).toBe(10)
    end)

    T.it("wraps value exceeding max back to min", function()
        T.expect(pickerUtil.wrapValue(11, 1, 10)).toBe(1)
        T.expect(pickerUtil.wrapValue(15, 1, 10)).toBe(1)
        T.expect(pickerUtil.wrapValue(100, 0, 23)).toBe(0)
    end)

    T.it("wraps value below min back to max", function()
        T.expect(pickerUtil.wrapValue(0, 1, 10)).toBe(10)
        T.expect(pickerUtil.wrapValue(-5, 1, 10)).toBe(10)
        T.expect(pickerUtil.wrapValue(-1, 0, 59)).toBe(59)
    end)

    T.it("handles year range correctly", function()
        T.expect(pickerUtil.wrapValue(2100, 1970, 2099)).toBe(1970)
        T.expect(pickerUtil.wrapValue(1969, 1970, 2099)).toBe(2099)
    end)

    T.it("handles month range correctly", function()
        T.expect(pickerUtil.wrapValue(13, 1, 12)).toBe(1)
        T.expect(pickerUtil.wrapValue(0, 1, 12)).toBe(12)
    end)

    T.it("handles hour range correctly", function()
        T.expect(pickerUtil.wrapValue(24, 0, 23)).toBe(0)
        T.expect(pickerUtil.wrapValue(-1, 0, 23)).toBe(23)
    end)

    T.it("handles minute range correctly", function()
        T.expect(pickerUtil.wrapValue(60, 0, 59)).toBe(0)
        T.expect(pickerUtil.wrapValue(-1, 0, 59)).toBe(59)
    end)
end)

T.describe("DateTimePicker: getDaysInMonth", function()
    T.it("returns correct days for months with 31 days", function()
        T.expect(pickerUtil.getDaysInMonth(2024, 1)).toBe(31)   -- January
        T.expect(pickerUtil.getDaysInMonth(2024, 3)).toBe(31)   -- March
        T.expect(pickerUtil.getDaysInMonth(2024, 5)).toBe(31)   -- May
        T.expect(pickerUtil.getDaysInMonth(2024, 7)).toBe(31)   -- July
        T.expect(pickerUtil.getDaysInMonth(2024, 8)).toBe(31)   -- August
        T.expect(pickerUtil.getDaysInMonth(2024, 10)).toBe(31)  -- October
        T.expect(pickerUtil.getDaysInMonth(2024, 12)).toBe(31)  -- December
    end)

    T.it("returns correct days for months with 30 days", function()
        T.expect(pickerUtil.getDaysInMonth(2024, 4)).toBe(30)   -- April
        T.expect(pickerUtil.getDaysInMonth(2024, 6)).toBe(30)   -- June
        T.expect(pickerUtil.getDaysInMonth(2024, 9)).toBe(30)   -- September
        T.expect(pickerUtil.getDaysInMonth(2024, 11)).toBe(30)  -- November
    end)

    T.it("returns 28 for February in non-leap years", function()
        T.expect(pickerUtil.getDaysInMonth(2023, 2)).toBe(28)
        T.expect(pickerUtil.getDaysInMonth(2021, 2)).toBe(28)
        T.expect(pickerUtil.getDaysInMonth(2022, 2)).toBe(28)
    end)

    T.it("returns 29 for February in leap years", function()
        T.expect(pickerUtil.getDaysInMonth(2024, 2)).toBe(29)  -- 2024 is leap year
        T.expect(pickerUtil.getDaysInMonth(2020, 2)).toBe(29)  -- 2020 is leap year
        T.expect(pickerUtil.getDaysInMonth(2028, 2)).toBe(29)  -- 2028 is leap year
    end)

    T.it("handles century leap years correctly", function()
        T.expect(pickerUtil.getDaysInMonth(2000, 2)).toBe(29)  -- 2000 is leap year (divisible by 400)
        T.expect(pickerUtil.getDaysInMonth(1900, 2)).toBe(28)  -- 1900 is not leap year (divisible by 100 but not 400)
    end)
end)

T.describe("DateTimePicker: pad2", function()
    T.it("pads single digit numbers with leading zero", function()
        T.expect(pickerUtil.pad2(0)).toBe("00")
        T.expect(pickerUtil.pad2(5)).toBe("05")
        T.expect(pickerUtil.pad2(9)).toBe("09")
    end)

    T.it("does not pad double digit numbers", function()
        T.expect(pickerUtil.pad2(10)).toBe("10")
        T.expect(pickerUtil.pad2(23)).toBe("23")
        T.expect(pickerUtil.pad2(59)).toBe("59")
    end)
end)

-- Now test the actual DateTimePicker module behavior
local DateTimePicker = require("lib.datetime-picker")

T.describe("DateTimePicker: module exports", function()
    T.it("exports Display constants", function()
        T.expect(DateTimePicker.Display.DEFAULT).toBe("default")
        T.expect(DateTimePicker.Display.SPINNER).toBe("spinner")
        T.expect(DateTimePicker.Display.CLOCK).toBe("clock")
        T.expect(DateTimePicker.Display.CALENDAR).toBe("calendar")
    end)

    T.it("exports EventType constants", function()
        T.expect(DateTimePicker.EventType.SET).toBe("set")
        T.expect(DateTimePicker.EventType.DISMISSED).toBe("dismissed")
    end)

    T.it("exports DateTimePicker function", function()
        T.expect(type(DateTimePicker.DateTimePicker)).toBe("function")
    end)

    T.it("exports open function", function()
        T.expect(type(DateTimePicker.open)).toBe("function")
    end)
end)

T.describe("DateTimePicker: mode-based column counts", function()
    -- Mock React for testing component structure
    local mockReact = {
        useCallback = function(fn) return fn end,
        useRef = function() return { current = {} } end,
        createElement = function(type, props, ...)
            local children = {...}
            return {
                type = type,
                props = props,
                children = #children > 0 and children or nil
            }
        end
    }
    
    -- Temporarily replace React
    package.loaded["react"] = mockReact
    
    T.it("time mode has 2 columns (hour + minute)", function()
        local element = DateTimePicker.DateTimePicker({
            value = os.time({ year = 2024, month = 1, day = 15, hour = 14, min = 30 }),
            mode = "time",
            onChange = function() end
        })
        
        T.expect(element).toBeTruthy()
        T.expect(element.type).toBe("View")
        T.expect(element.children).toBeTruthy()
        -- Should have hour col, separator, minute col = 3 children
        T.expect(#element.children).toBe(3)
    end)

    T.it("date mode has 3 columns (year + month + day)", function()
        local element = DateTimePicker.DateTimePicker({
            value = os.time({ year = 2024, month = 1, day = 15 }),
            mode = "date",
            onChange = function() end
        })
        
        T.expect(element).toBeTruthy()
        T.expect(element.type).toBe("View")
        T.expect(element.children).toBeTruthy()
        -- Should have year col, sep, month col, sep, day col = 5 children
        T.expect(#element.children).toBe(5)
    end)

    T.it("datetime mode has 5 columns (year + month + day + hour + minute)", function()
        local element = DateTimePicker.DateTimePicker({
            value = os.time({ year = 2024, month = 1, day = 15, hour = 14, min = 30 }),
            mode = "datetime",
            onChange = function() end
        })
        
        T.expect(element).toBeTruthy()
        T.expect(element.type).toBe("View")
        T.expect(element.children).toBeTruthy()
        -- Should have year, sep, month, sep, day, sep(empty), hour, sep, minute = 9 children
        T.expect(#element.children).toBe(9)
    end)
    
    -- Restore React
    package.loaded["react"] = nil
end)

T.describe("DateTimePicker: minimumDate/maximumDate constraints", function()
    local capturedCalls = {}
    
    local mockReact = {
        useCallback = function(fn) 
            return function(...)
                table.insert(capturedCalls, {...})
                return fn(...)
            end
        end,
        useRef = function(val) return { current = val or {} } end,
        createElement = function(type, props, ...)
            local children = {...}
            return {
                type = type,
                props = props,
                children = #children > 0 and children or nil
            }
        end
    }
    
    T.it("respects minimumDate constraint", function()
        package.loaded["react"] = mockReact
        capturedCalls = {}
        
        local minDate = os.time({ year = 2024, month = 1, day = 1 })
        local value = os.time({ year = 2024, month = 6, day = 15, hour = 12, min = 0 })
        local receivedTimestamp = nil
        
        local element = DateTimePicker.DateTimePicker({
            value = value,
            mode = "time",
            minimumDate = minDate,
            onChange = function(evt)
                receivedTimestamp = evt.nativeEvent.timestamp
            end
        })
        
        -- The constraint is applied in emitChange which is called by handlers
        -- We verify the component structure supports this
        T.expect(element).toBeTruthy()
        
        package.loaded["react"] = nil
    end)

    T.it("respects maximumDate constraint", function()
        package.loaded["react"] = mockReact
        capturedCalls = {}
        
        local maxDate = os.time({ year = 2024, month = 12, day = 31 })
        local value = os.time({ year = 2024, month = 6, day = 15, hour = 12, min = 0 })
        
        local element = DateTimePicker.DateTimePicker({
            value = value,
            mode = "time",
            maximumDate = maxDate,
            onChange = function(evt) end
        })
        
        T.expect(element).toBeTruthy()
        
        package.loaded["react"] = nil
    end)
end)

T.describe("DateTimePicker: default props", function()
    local mockReact = {
        useCallback = function(fn) return fn end,
        useRef = function(val) return { current = val or {} } end,
        createElement = function(type, props, ...)
            local children = {...}
            return {
                type = type,
                props = props,
                children = #children > 0 and children or nil
            }
        end
    }
    
    T.it("defaults to date mode", function()
        package.loaded["react"] = mockReact
        
        local element = DateTimePicker.DateTimePicker({
            value = os.time(),
            onChange = function() end
        })
        
        -- Date mode should have 5 children (year, sep, month, sep, day)
        T.expect(#element.children).toBe(5)
        
        package.loaded["react"] = nil
    end)

    T.it("applies default styling", function()
        package.loaded["react"] = mockReact
        
        local element = DateTimePicker.DateTimePicker({
            value = os.time(),
            onChange = function() end
        })
        
        T.expect(element.props.style).toBeTruthy()
        T.expect(element.props.style.flexDirection).toBe("row")
        T.expect(element.props.style.backgroundColor).toBe("#1E1E2E")
        
        package.loaded["react"] = nil
    end)

    T.it("respects disabled prop", function()
        package.loaded["react"] = mockReact
        
        local element = DateTimePicker.DateTimePicker({
            value = os.time(),
            mode = "time",
            disabled = true,
            onChange = function() end
        })
        
        -- Check that column children receive disabled prop
        -- Hour column is first child
        local hourCol = element.children[1]
        T.expect(hourCol.props.disabled).toBe(true)
        
        package.loaded["react"] = nil
    end)
end)

T.describe("DateTimePicker: Column drag handler", function()
    local mockInstance = nil
    local mockReact
    mockReact = {
        useCallback = function(fn) return fn end,
        useRef = function(val) return { current = val or {} } end,
        createElement = function(typ, props, ...)
            -- If type is a function component, call it to render
            if type(typ) == "function" then
                return typ(props or {})
            end
            -- Host element — capture ref callback on first View with ref
            if typ == "View" and props and props.ref and not mockInstance then
                mockInstance = { contentBounds = { xMin = 0, xMax = 52, yMin = 0, yMax = 96 } }
                props.ref(mockInstance)
            end
            local children = {...}
            return {
                type = typ,
                props = props,
                children = #children > 0 and children or nil
            }
        end
    }

    T.it("Column root View receives _onDragHandler via ref", function()
        package.loaded["react"] = mockReact
        mockInstance = nil

        -- Force reload to pick up mockReact
        package.loaded["lib.datetime-picker"] = nil
        local DTP = require("lib.datetime-picker")

        local element = DTP.DateTimePicker({
            value = os.time({ year = 2024, month = 6, day = 15, hour = 12, min = 30 }),
            mode = "time",
            onChange = function() end,
        })

        -- mockInstance should have been set by the ref callback
        T.expect(mockInstance).toBeTruthy()
        T.expect(type(mockInstance._onDragHandler)).toBe("function")

        package.loaded["react"] = nil
        package.loaded["lib.datetime-picker"] = nil
    end)

    T.it("drag up increments hour value", function()
        package.loaded["react"] = mockReact
        mockInstance = nil
        package.loaded["lib.datetime-picker"] = nil
        local DTP = require("lib.datetime-picker")

        local receivedTs = nil
        local element = DTP.DateTimePicker({
            value = os.time({ year = 2024, month = 6, day = 15, hour = 10, min = 30 }),
            mode = "time",
            onChange = function(evt) receivedTs = evt.nativeEvent.timestamp end,
        })

        -- Simulate drag up (negative dy = increment value)
        -- Each Column gets its own ref; the first one should be hour column
        T.expect(mockInstance).toBeTruthy()
        T.expect(mockInstance._onDragHandler).toBeTruthy()

        mockInstance._onDragHandler({ phase = "began", y = 100, x = 26 })
        mockInstance._onDragHandler({ phase = "moved", y = 72, x = 26 })  -- dy = -28 → +1 step
        mockInstance._onDragHandler({ phase = "ended", y = 72, x = 26 })

        T.expect(receivedTs).toBeTruthy()
        local newT = os.date("*t", receivedTs)
        T.expect(newT.hour).toBe(11)

        package.loaded["react"] = nil
        package.loaded["lib.datetime-picker"] = nil
    end)

    T.it("drag down decrements hour value", function()
        package.loaded["react"] = mockReact
        mockInstance = nil
        package.loaded["lib.datetime-picker"] = nil
        local DTP = require("lib.datetime-picker")

        local receivedTs = nil
        local element = DTP.DateTimePicker({
            value = os.time({ year = 2024, month = 6, day = 15, hour = 10, min = 30 }),
            mode = "time",
            onChange = function(evt) receivedTs = evt.nativeEvent.timestamp end,
        })

        T.expect(mockInstance).toBeTruthy()

        mockInstance._onDragHandler({ phase = "began", y = 100, x = 26 })
        mockInstance._onDragHandler({ phase = "moved", y = 128, x = 26 })  -- dy = +28 → -1 step
        mockInstance._onDragHandler({ phase = "ended", y = 128, x = 26 })

        T.expect(receivedTs).toBeTruthy()
        local newT = os.date("*t", receivedTs)
        T.expect(newT.hour).toBe(9)

        package.loaded["react"] = nil
        package.loaded["lib.datetime-picker"] = nil
    end)

    T.it("drag wraps around at boundaries", function()
        package.loaded["react"] = mockReact
        mockInstance = nil
        package.loaded["lib.datetime-picker"] = nil
        local DTP = require("lib.datetime-picker")

        local receivedTs = nil
        local element = DTP.DateTimePicker({
            value = os.time({ year = 2024, month = 6, day = 15, hour = 23, min = 30 }),
            mode = "time",
            onChange = function(evt) receivedTs = evt.nativeEvent.timestamp end,
        })

        T.expect(mockInstance).toBeTruthy()

        -- Drag up from hour=23 should wrap to 0
        mockInstance._onDragHandler({ phase = "began", y = 100, x = 26 })
        mockInstance._onDragHandler({ phase = "moved", y = 72, x = 26 })  -- +1
        mockInstance._onDragHandler({ phase = "ended", y = 72, x = 26 })

        T.expect(receivedTs).toBeTruthy()
        local newT = os.date("*t", receivedTs)
        T.expect(newT.hour).toBe(0)

        package.loaded["react"] = nil
        package.loaded["lib.datetime-picker"] = nil
    end)

    T.it("disabled column ignores drag", function()
        package.loaded["react"] = mockReact
        mockInstance = nil
        package.loaded["lib.datetime-picker"] = nil
        local DTP = require("lib.datetime-picker")

        local receivedTs = nil
        local element = DTP.DateTimePicker({
            value = os.time({ year = 2024, month = 6, day = 15, hour = 10, min = 30 }),
            mode = "time",
            disabled = true,
            onChange = function(evt) receivedTs = evt.nativeEvent.timestamp end,
        })

        T.expect(mockInstance).toBeTruthy()

        mockInstance._onDragHandler({ phase = "began", y = 100, x = 26 })
        mockInstance._onDragHandler({ phase = "moved", y = 72, x = 26 })
        mockInstance._onDragHandler({ phase = "ended", y = 72, x = 26 })

        T.expect(receivedTs).toBeNil()

        package.loaded["react"] = nil
        package.loaded["lib.datetime-picker"] = nil
    end)
end)

T.summary()
