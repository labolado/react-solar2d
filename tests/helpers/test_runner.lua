-- tests/helpers/test_runner.lua
local M = {}
M._tests = {}
M._passed = 0
M._failed = 0

function M.describe(name, fn)
    print("\n=== " .. name .. " ===")
    fn()
end

function M.it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        M._passed = M._passed + 1
        print("  ✓ " .. name)
    else
        M._failed = M._failed + 1
        print("  ✗ " .. name .. "\n    " .. tostring(err))
    end
end

function M.expect(val)
    return {
        toBe = function(expected)
            if val ~= expected then
                error("Expected " .. tostring(expected) .. " but got " .. tostring(val), 2)
            end
        end,
        toEqual = function(expected)
            -- deep equality for tables
            local function deepEq(a, b)
                if type(a) ~= type(b) then return false end
                if type(a) ~= "table" then return a == b end
                for k, v in pairs(a) do
                    if not deepEq(v, b[k]) then return false end
                end
                for k in pairs(b) do
                    if a[k] == nil then return false end
                end
                return true
            end
            if not deepEq(val, expected) then
                error("Deep equality failed", 2)
            end
        end,
        toBeTruthy = function()
            if not val then error("Expected truthy but got " .. tostring(val), 2) end
        end,
        toBeFalsy = function()
            if val then error("Expected falsy but got " .. tostring(val), 2) end
        end,
        toBeNil = function()
            if val ~= nil then error("Expected nil but got " .. tostring(val), 2) end
        end,
        toBeType = function(t)
            if type(val) ~= t then error("Expected type " .. t .. " but got " .. type(val), 2) end
        end,
    }
end

function M.summary()
    print("\n--- Results: " .. M._passed .. " passed, " .. M._failed .. " failed ---")
    return M._failed == 0
end

return M
