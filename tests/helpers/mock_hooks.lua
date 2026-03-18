-- tests/helpers/mock_hooks.lua
-- Mock hooks infrastructure for testing React components

local Hooks = require("react.Hooks")

local M = {}

-- Create a mock fiber for testing hooks
function M.createMockFiber()
    return {
        _hooks = {},
        props = {},
        stateNode = nil,
        alternate = nil,
    }
end

-- Set up hooks context for a test
function M.setupHooks(fiber)
    fiber = fiber or M.createMockFiber()
    Hooks._setCurrentFiber(fiber)
    Hooks._resetHookIndex()
    return fiber
end

-- Clean up hooks context
function M.cleanupHooks()
    Hooks._finishHooks()
end

-- Run a component function with hooks support
-- Returns: element, fiber, error (if any)
function M.renderComponent(componentFn, props)
    local fiber = M.createMockFiber()
    fiber.props = props or {}

    M.setupHooks(fiber)

    local ok, result = pcall(function()
        return componentFn(props)
    end)

    M.cleanupHooks()

    if not ok then
        return nil, fiber, result
    end

    return result, fiber, nil
end

-- Run a test with hooks context
function M.testWithHooks(testFn)
    local fiber = M.createMockFiber()
    M.setupHooks(fiber)

    local ok, err = pcall(testFn)

    M.cleanupHooks()

    if not ok then
        error(err, 2)
    end
end

-- Get pending effects from hooks
function M.getPendingEffects()
    return Hooks._getPendingEffects()
end

return M
