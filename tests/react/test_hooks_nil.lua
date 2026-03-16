-- tests/react/test_hooks_nil.lua — Tests for nil-safe useState and edge cases
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local Hooks = require("react.Hooks")
local FiberNode = require("react.FiberNode")

local function renderWithHooks(fn, props, existingFiber)
    local fiber = existingFiber or FiberNode.createFiber("function", fn, nil, props or {})
    Hooks._setCurrentFiber(fiber)
    Hooks._resetHookIndex()
    local result = fn(props or {})
    Hooks._finishHooks()
    return result, fiber
end

T.describe("useState: nil value support", function()
    T.it("setState(nil) sets state to nil", function()
        local setSt
        local function Comp()
            local val, set = Hooks.useState("initial")
            setSt = set
            return val
        end
        local result, fiber = renderWithHooks(Comp)
        T.expect(result).toBe("initial")

        setSt(nil)
        result = renderWithHooks(Comp, nil, fiber)
        T.expect(result).toBeNil()
    end)

    T.it("setState(nil) then setState(value) works", function()
        local setSt
        local function Comp()
            local val, set = Hooks.useState("a")
            setSt = set
            return val
        end
        local _, fiber = renderWithHooks(Comp)

        setSt(nil)
        local result = renderWithHooks(Comp, nil, fiber)
        T.expect(result).toBeNil()

        setSt("b")
        result = renderWithHooks(Comp, nil, fiber)
        T.expect(result).toBe("b")
    end)

    T.it("functional updater receives nil state", function()
        local setSt
        local function Comp()
            local val, set = Hooks.useState(nil)
            setSt = set
            return val
        end
        local _, fiber = renderWithHooks(Comp)
        T.expect(_).toBeNil()

        setSt(function(prev)
            -- prev should be nil
            if prev == nil then return "from_nil" end
            return "wrong"
        end)
        local result = renderWithHooks(Comp, nil, fiber)
        T.expect(result).toBe("from_nil")
    end)

    T.it("multiple queued updates with nil in sequence", function()
        local setSt
        local function Comp()
            local val, set = Hooks.useState(1)
            setSt = set
            return val
        end
        local _, fiber = renderWithHooks(Comp)

        setSt(2)
        setSt(nil)
        setSt(3)
        local result = renderWithHooks(Comp, nil, fiber)
        T.expect(result).toBe(3)
    end)
end)

T.describe("useReducer: nil dispatch", function()
    T.it("handles nil action via reducer", function()
        local function reducer(state, action)
            if action == nil then return 0 end
            if action.type == "inc" then return state + 1 end
            return state
        end
        local dispatchFn
        local function Comp()
            local count, dispatch = Hooks.useReducer(reducer, 10)
            dispatchFn = dispatch
            return count
        end
        local _, fiber = renderWithHooks(Comp)
        T.expect(_).toBe(10)

        dispatchFn(nil)
        local result = renderWithHooks(Comp, nil, fiber)
        T.expect(result).toBe(0)
    end)
end)

T.describe("useEffect", function()
    T.it("queues effects for later execution", function()
        local effectRan = false
        local function Comp()
            Hooks.useEffect(function()
                effectRan = true
            end, {})
            return "done"
        end
        renderWithHooks(Comp)
        -- Effect should be queued, not yet run
        local effects = Hooks._getPendingEffects()
        T.expect(#effects).toBe(1)
        T.expect(effectRan).toBe(false)

        -- Execute effect
        effects[1].callback()
        T.expect(effectRan).toBe(true)
    end)

    T.it("skips effect when deps unchanged", function()
        local callCount = 0
        local function Comp(props)
            Hooks.useEffect(function()
                callCount = callCount + 1
            end, { props.x })
            return "done"
        end
        local _, fiber = renderWithHooks(Comp, { x = 1 })
        Hooks._getPendingEffects() -- clear

        -- Re-render with same deps
        renderWithHooks(Comp, { x = 1 }, fiber)
        local effects = Hooks._getPendingEffects()
        T.expect(#effects).toBe(0)

        -- Re-render with changed deps
        renderWithHooks(Comp, { x = 2 }, fiber)
        effects = Hooks._getPendingEffects()
        T.expect(#effects).toBe(1)
    end)

    T.it("effect cleanup is tracked", function()
        local cleanupRan = false
        local function Comp(props)
            Hooks.useEffect(function()
                return function() cleanupRan = true end
            end, { props.x })
            return "done"
        end
        local _, fiber = renderWithHooks(Comp, { x = 1 })
        local effects = Hooks._getPendingEffects()
        -- Execute effect, capture cleanup
        local cleanup = effects[1].callback()
        effects[1].hookRef.cleanup = cleanup

        -- Re-render with changed deps should queue new effect with prevCleanup
        renderWithHooks(Comp, { x = 2 }, fiber)
        effects = Hooks._getPendingEffects()
        T.expect(#effects).toBe(1)
        T.expect(effects[1].prevCleanup).toBeTruthy()

        -- Run previous cleanup
        effects[1].prevCleanup()
        T.expect(cleanupRan).toBe(true)
    end)
end)

T.describe("useContext", function()
    T.it("returns default value when no provider", function()
        local ctx = Hooks.createContext("default_val")
        local function Comp()
            return Hooks.useContext(ctx)
        end
        local result = renderWithHooks(Comp)
        T.expect(result).toBe("default_val")
    end)

    T.it("reads value from parent fiber context", function()
        local ctx = Hooks.createContext("fallback")
        local function Comp()
            return Hooks.useContext(ctx)
        end
        -- Simulate a parent fiber with context
        local fiber = FiberNode.createFiber("function", Comp, nil, {})
        local parentFiber = FiberNode.createFiber("host", "View", nil, {})
        parentFiber._contextValues = { [ctx._id] = "provided_val" }
        fiber.parent = parentFiber

        Hooks._setCurrentFiber(fiber)
        Hooks._resetHookIndex()
        local result = Comp({})
        Hooks._finishHooks()

        T.expect(result).toBe("provided_val")
    end)
end)

T.summary()
