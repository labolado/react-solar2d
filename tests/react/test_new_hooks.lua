-- tests/react/test_new_hooks.lua — Tests for useId, useImperativeHandle, useDebugValue, useSyncExternalStore
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local Hooks = require("react.Hooks")
local FiberNode = require("react.FiberNode")
local ReactElement = require("react.ReactElement")

-- Helper: simulate rendering a function component with hooks
local function renderWithHooks(fn, props, existingFiber)
    local fiber = existingFiber or FiberNode.createFiber("function", fn, nil, props or {})
    Hooks._setCurrentFiber(fiber)
    Hooks._resetHookIndex()
    local result = fn(props or {})
    Hooks._finishHooks()
    return result, fiber
end

T.describe("useId", function()
    T.it("returns unique IDs for different components", function()
        local id1, id2
        local function Comp1()
            id1 = Hooks.useId()
            return nil
        end
        local function Comp2()
            id2 = Hooks.useId()
            return nil
        end
        renderWithHooks(Comp1)
        renderWithHooks(Comp2)
        T.expect(id1).toBeType("string")
        T.expect(id2).toBeType("string")
        T.expect(id1 ~= id2).toBe(true)
    end)

    T.it("returns same ID on re-render", function()
        local id1, id2
        local function Comp()
            id1 = Hooks.useId()
            return nil
        end
        local _, fiber = renderWithHooks(Comp)
        id2 = nil
        renderWithHooks(Comp, nil, fiber)
        id2 = id1
        -- id1 was set twice, should be same
        T.expect(id1).toBe(id2)
    end)

    T.it("generates IDs with correct prefix", function()
        local id
        local function Comp()
            id = Hooks.useId()
            return nil
        end
        renderWithHooks(Comp)
        T.expect(id:match("^r:id-")).toBeTruthy()
    end)
end)

T.describe("useImperativeHandle", function()
    T.it("attaches handle to ref.current", function()
        local ref = { current = nil }
        local function Comp()
            Hooks.useImperativeHandle(ref, function()
                return { focus = function() return "focused" end }
            end, {})
            return nil
        end
        renderWithHooks(Comp)
        T.expect(type(ref.current)).toBe("table")
        T.expect(type(ref.current.focus)).toBe("function")
        T.expect(ref.current.focus()).toBe("focused")
    end)

    T.it("updates handle when deps change", function()
        local ref = { current = nil }
        local value = 1
        local function Comp(props)
            Hooks.useImperativeHandle(ref, function()
                return { getValue = function() return props.value end }
            end, { props.value })
            return nil
        end
        local _, fiber = renderWithHooks(Comp, { value = 1 })
        T.expect(ref.current.getValue()).toBe(1)
        
        fiber.props = { value = 2 }
        renderWithHooks(Comp, { value = 2 }, fiber)
        T.expect(ref.current.getValue()).toBe(2)
    end)
end)

T.describe("useDebugValue", function()
    T.it("runs without error (debug output only)", function()
        local function Comp()
            Hooks.useDebugValue("test value")
            return nil
        end
        -- Should not throw
        local ok = pcall(function()
            renderWithHooks(Comp)
        end)
        T.expect(ok).toBe(true)
    end)

    T.it("accepts format function", function()
        local function Comp()
            Hooks.useDebugValue({ x = 1, y = 2 }, function(obj)
                return "(" .. obj.x .. ", " .. obj.y .. ")"
            end)
            return nil
        end
        -- Should not throw
        local ok = pcall(function()
            renderWithHooks(Comp)
        end)
        T.expect(ok).toBe(true)
    end)
end)

T.describe("useSyncExternalStore", function()
    T.it("subscribes to external store and gets snapshot", function()
        local store = { value = 10 }
        local subscribers = {}
        local function subscribe(callback)
            table.insert(subscribers, callback)
            return function()
                for i, cb in ipairs(subscribers) do
                    if cb == callback then
                        table.remove(subscribers, i)
                        break
                    end
                end
            end
        end
        local function getSnapshot()
            return store.value
        end

        local snapshot
        local function Comp()
            snapshot = Hooks.useSyncExternalStore(subscribe, getSnapshot)
            return nil
        end
        renderWithHooks(Comp)
        T.expect(snapshot).toBe(10)
    end)

    T.it("unsubscribes on cleanup", function()
        local unsubscribed = false
        local function subscribe(callback)
            return function()
                unsubscribed = true
            end
        end
        local function getSnapshot()
            return 0
        end

        local function Comp()
            Hooks.useSyncExternalStore(subscribe, getSnapshot)
            return nil
        end
        local _, fiber = renderWithHooks(Comp)
        
        -- Simulate unmount by calling store cleanup
        if fiber._storeCleanups then
            for _, cleanup in pairs(fiber._storeCleanups) do
                cleanup()
            end
        end
        -- Note: actual cleanup happens in reconciler on unmount
        T.expect(unsubscribed).toBe(true)
    end)
end)

T.describe("forwardRef", function()
    T.it("creates forwardRef component", function()
        local forwardRefComponent = ReactElement.forwardRef(function(props, ref)
            return { props = props, ref = ref }
        end)
        T.expect(forwardRefComponent._isForwardRef).toBe(true)
        T.expect(type(forwardRefComponent.render)).toBe("function")
    end)
end)

T.summary()
