-- lib/datetime-picker/tests/test_logic.lua
-- Unit tests for DateTimePicker logic functions

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")

-- Test the helper functions directly
T.describe("DateTimePicker Logic", function()
    -- Recreate the logic functions for testing
    local function getDateParts(timestamp)
        local t = os.date("*t", timestamp)
        return {
            year = t.year,
            month = t.month,
            day = t.day,
            hour = t.hour,
            min = t.min,
        }
    end

    local function buildTimestamp(parts)
        return os.time({
            year = parts.year,
            month = parts.month,
            day = parts.day,
            hour = parts.hour or 0,
            min = parts.min or 0,
        })
    end

    local function formatDisplay(timestamp, mode)
        if mode == "time" then
            return os.date("%H:%M", timestamp)
        elseif mode == "datetime" then
            return os.date("%Y-%m-%d %H:%M", timestamp)
        else
            return os.date("%Y-%m-%d", timestamp)
        end
    end

    -- Parse date from text
    local function parseDate(text, mode, currentValue)
        local parts = getDateParts(currentValue)
        local valid = false

        if mode == "date" then
            -- Try YYYY-MM-DD
            local y, m, d = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
            if y and m and d then
                parts.year = tonumber(y)
                parts.month = tonumber(m)
                parts.day = tonumber(d)
                valid = true
            end
        elseif mode == "time" then
            -- Try HH:MM
            local h, mi = text:match("^(%d%d):(%d%d)$")
            if h and mi then
                parts.hour = tonumber(h)
                parts.min = tonumber(mi)
                valid = true
            end
        else
            -- Try YYYY-MM-DD HH:MM
            local y, m, d, h, mi = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d)$")
            if y and m and d and h and mi then
                parts.year = tonumber(y)
                parts.month = tonumber(m)
                parts.day = tonumber(d)
                parts.hour = tonumber(h)
                parts.min = tonumber(mi)
                valid = true
            end
        end

        if valid then
            return buildTimestamp(parts)
        end
        return nil
    end

    T.it("getDateParts extracts correct date components", function()
        local ts = os.time({ year = 2024, month = 3, day = 15, hour = 14, min = 30 })
        local parts = getDateParts(ts)
        T.expect(parts.year).toBe(2024)
        T.expect(parts.month).toBe(3)
        T.expect(parts.day).toBe(15)
        T.expect(parts.hour).toBe(14)
        T.expect(parts.min).toBe(30)
    end)

    T.it("buildTimestamp creates correct timestamp", function()
        local parts = { year = 2024, month = 6, day = 20, hour = 10, min = 45 }
        local ts = buildTimestamp(parts)
        local t = os.date("*t", ts)
        T.expect(t.year).toBe(2024)
        T.expect(t.month).toBe(6)
        T.expect(t.day).toBe(20)
        T.expect(t.hour).toBe(10)
        T.expect(t.min).toBe(45)
    end)

    T.it("formatDisplay formats date mode correctly", function()
        local ts = os.time({ year = 2024, month = 12, day = 25, hour = 0, min = 0 })
        local result = formatDisplay(ts, "date")
        T.expect(result).toBe("2024-12-25")
    end)

    T.it("formatDisplay formats time mode correctly", function()
        local ts = os.time({ year = 2024, month = 1, day = 1, hour = 14, min = 30 })
        local result = formatDisplay(ts, "time")
        T.expect(result).toBe("14:30")
    end)

    T.it("formatDisplay formats datetime mode correctly", function()
        local ts = os.time({ year = 2024, month = 6, day = 15, hour = 9, min = 5 })
        local result = formatDisplay(ts, "datetime")
        T.expect(result).toBe("2024-06-15 09:05")
    end)

    T.it("parseDate parses date format correctly", function()
        local current = os.time({ year = 2024, month = 1, day = 1, hour = 0, min = 0 })
        local result = parseDate("2024-12-25", "date", current)
        T.expect(result).toNotBe(nil)
        local t = os.date("*t", result)
        T.expect(t.year).toBe(2024)
        T.expect(t.month).toBe(12)
        T.expect(t.day).toBe(25)
    end)

    T.it("parseDate parses time format correctly", function()
        local current = os.time({ year = 2024, month = 6, day = 15, hour = 0, min = 0 })
        local result = parseDate("14:30", "time", current)
        T.expect(result).toNotBe(nil)
        local t = os.date("*t", result)
        -- Date parts should be preserved from current
        T.expect(t.year).toBe(2024)
        T.expect(t.month).toBe(6)
        T.expect(t.day).toBe(15)
        -- Time parts from input
        T.expect(t.hour).toBe(14)
        T.expect(t.min).toBe(30)
    end)

    T.it("parseDate parses datetime format correctly", function()
        local current = os.time({ year = 2024, month = 1, day = 1, hour = 0, min = 0 })
        local result = parseDate("2024-12-25 14:30", "datetime", current)
        T.expect(result).toNotBe(nil)
        local t = os.date("*t", result)
        T.expect(t.year).toBe(2024)
        T.expect(t.month).toBe(12)
        T.expect(t.day).toBe(25)
        T.expect(t.hour).toBe(14)
        T.expect(t.min).toBe(30)
    end)

    T.it("parseDate returns nil for invalid format", function()
        local current = os.time()
        T.expect(parseDate("not-a-date", "date", current)).toBe(nil)
        T.expect(parseDate("25-12-2024", "date", current)).toBe(nil) -- Wrong order
        T.expect(parseDate("14:30:00", "time", current)).toBe(nil) -- Has seconds
        T.expect(parseDate("", "date", current)).toBe(nil) -- Empty
    end)

    T.it("parseDate handles edge cases", function()
        local current = os.time({ year = 2024, month = 6, day = 15, hour = 12, min = 0 })

        -- Single digit month/day should not match (requires padding)
        local r1 = parseDate("2024-6-15", "date", current)
        T.expect(r1).toBe(nil) -- Should fail - needs 06

        -- Correct padding
        local r2 = parseDate("2024-06-15", "date", current)
        T.expect(r2).toNotBe(nil)
    end)

    T.it("adjustDate increments correctly", function()
        local parts = { year = 2024, month = 3, day = 15, hour = 12, min = 30 }

        -- Increment day
        parts.day = parts.day + 1
        local ts = buildTimestamp(parts)
        local t = os.date("*t", ts)
        T.expect(t.day).toBe(16)

        -- Increment month
        parts.month = parts.month + 1
        ts = buildTimestamp(parts)
        t = os.date("*t", ts)
        T.expect(t.month).toBe(4)

        -- Increment minute
        parts.min = parts.min + 5
        ts = buildTimestamp(parts)
        t = os.date("*t", ts)
        T.expect(t.min).toBe(35)
    end)

    T.it("round-trip conversion works", function()
        local original = os.time({ year = 2024, month = 8, day = 20, hour = 16, min = 45 })

        -- Test date mode round-trip
        local dateStr = formatDisplay(original, "date")
        local parsed = parseDate(dateStr, "date", original)
        T.expect(parsed).toNotBe(nil)
        local backToStr = formatDisplay(parsed, "date")
        T.expect(backToStr).toBe(dateStr)

        -- Test time mode round-trip
        local timeStr = formatDisplay(original, "time")
        parsed = parseDate(timeStr, "time", original)
        T.expect(parsed).toNotBe(nil)
        backToStr = formatDisplay(parsed, "time")
        T.expect(backToStr).toBe(timeStr)
    end)
end)

T.summary()
