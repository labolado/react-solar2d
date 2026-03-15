-- tests/react/test_hooks.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local Hooks = require("react.Hooks")
local FiberNode = require("react.FiberNode")

-- Helper: simulate rendering a function component with hooks
local function renderWithHooks(fn, props, existingFiber)
    local fiber = existingFiber or FiberNode.createFiber("function", fn, nil, props or {})
    Hooks._setCurrentFiber(fiber)
    Hooks._resetHookIndex()
    local result = fn(props or {})
    Hooks._finishHooks()
    return result, fiber
end

T.describe("useState", function()
    T.it("returns initial value", function()
        local function Comp()
            local val, _ = Hooks.useState(42)
            return val
        end
        local result = renderWithHooks(Comp)
        T.expect(result).toBe(42)
    end)

    T.it("setter updates state on next render", function()
        local setSt
        local function Comp()
            local val, set = Hooks.useState(0)
            setSt = set
            return val
        end
        local _, fiber = renderWithHooks(Comp)
        T.expect(_).toBe(0)

        setSt(10)
        local result = renderWithHooks(Comp, nil, fiber)
        T.expect(result).toBe(10)
    end)

    T.it("functional updater works", function()
        local setSt
        local function Comp()
            local val, set = Hooks.useState(5)
            setSt = set
            return val
        end
        local _, fiber = renderWithHooks(Comp)

        setSt(function(prev) return prev + 1 end)
        local result = renderWithHooks(Comp, nil, fiber)
        T.expect(result).toBe(6)
    end)

    T.it("multiple useState hooks work independently", function()
        local function Comp()
            local a, _ = Hooks.useState("hello")
            local b, _ = Hooks.useState(99)
            return a .. tostring(b)
        end
        local result = renderWithHooks(Comp)
        T.expect(result).toBe("hello99")
    end)
end)

T.describe("useRef", function()
    T.it("returns ref object with .current", function()
        local function Comp()
            local ref = Hooks.useRef(nil)
            return ref
        end
        local result = renderWithHooks(Comp)
        T.expect(result.current).toBeNil()
    end)

    T.it("persists across renders", function()
        local myRef
        local function Comp()
            myRef = Hooks.useRef(0)
            return myRef
        end
        local _, fiber = renderWithHooks(Comp)
        myRef.current = 42
        renderWithHooks(Comp, nil, fiber)
        T.expect(myRef.current).toBe(42)
    end)
end)

T.describe("useMemo", function()
    T.it("computes value", function()
        local function Comp()
            local val = Hooks.useMemo(function() return 2 + 3 end, {})
            return val
        end
        local result = renderWithHooks(Comp)
        T.expect(result).toBe(5)
    end)

    T.it("recomputes when deps change", function()
        local computeCount = 0
        local function Comp(props)
            local val = Hooks.useMemo(function()
                computeCount = computeCount + 1
                return props.x * 2
            end, { props.x })
            return val
        end
        local _, fiber = renderWithHooks(Comp, { x = 5 })
        T.expect(computeCount).toBe(1)

        -- Same deps, no recompute
        fiber.props = { x = 5 }
        renderWithHooks(Comp, { x = 5 }, fiber)
        T.expect(computeCount).toBe(1)

        -- Different deps, recompute
        fiber.props = { x = 10 }
        local result = renderWithHooks(Comp, { x = 10 }, fiber)
        T.expect(computeCount).toBe(2)
        T.expect(result).toBe(20)
    end)
end)

T.describe("useReducer", function()
    T.it("dispatches actions through reducer", function()
        local function reducer(state, action)
            if action.type == "increment" then return state + 1
            elseif action.type == "decrement" then return state - 1
            else return state end
        end
        local dispatchFn
        local function Comp()
            local count, dispatch = Hooks.useReducer(reducer, 0)
            dispatchFn = dispatch
            return count
        end
        local _, fiber = renderWithHooks(Comp)
        T.expect(_).toBe(0)

        dispatchFn({ type = "increment" })
        dispatchFn({ type = "increment" })
        local result = renderWithHooks(Comp, nil, fiber)
        T.expect(result).toBe(2)
    end)
end)

T.summary()
