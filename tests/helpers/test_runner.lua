-- tests/helpers/test_runner.lua
local M = {}
M._tests = {}
M._passed = 0
M._failed = 0

-- Optional: load mock_hooks if available
local mockHooks = nil
local function loadMockHooks()
    if mockHooks == nil then
        local ok, result = pcall(require, "tests.helpers.mock_hooks")
        if ok then
            mockHooks = result
        else
            mockHooks = false
        end
    end
    return mockHooks ~= false and mockHooks or nil
end

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

-- Run a test with hooks support
-- Usage: T.itWithHooks("test name", function(fiber) ... end)
function M.itWithHooks(name, fn)
    local mock = loadMockHooks()
    if not mock then
        M._failed = M._failed + 1
        print("  ✗ " .. name .. "\n    mock_hooks.lua not available")
        return
    end

    local fiber = mock.createMockFiber()
    mock.setupHooks(fiber)

    local ok, err = pcall(function()
        fn(fiber)
    end)

    mock.cleanupHooks()

    if ok then
        M._passed = M._passed + 1
        print("  ✓ " .. name)
    else
        M._failed = M._failed + 1
        print("  ✗ " .. name .. "\n    " .. tostring(err))
    end
end

-- Render a component with hooks support
-- Returns: element, fiber
function M.renderComponent(componentFn, props)
    local mock = loadMockHooks()
    if not mock then
        error("mock_hooks.lua not available")
    end
    return mock.renderComponent(componentFn, props)
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
        toNotBe = function(expected)
            if val == expected then error("Expected not " .. tostring(expected) .. " but got " .. tostring(val), 2) end
        end,
    }
end

function M.summary()
    print("\n--- Results: " .. M._passed .. " passed, " .. M._failed .. " failed ---")
    return M._failed == 0
end

return M
