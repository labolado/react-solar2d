-- Simple test for hooks infrastructure
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local mockHooks = require("tests.helpers.mock_hooks")

T.describe("Mock Hooks Infrastructure", function()
    T.it("should create mock fiber", function()
        local fiber = mockHooks.createMockFiber()
        T.expect(fiber).toNotBe(nil)
        T.expect(fiber._hooks).toNotBe(nil)
    end)

    T.it("should setup and cleanup hooks", function()
        local fiber = mockHooks.createMockFiber()
        mockHooks.setupHooks(fiber)

        local Hooks = require("react.Hooks")
        local state, setState = Hooks.useState("initial")
        T.expect(state).toBe("initial")

        mockHooks.cleanupHooks()
    end)

    T.it("should render component with hooks", function()
        local function TestComponent(props)
            local React = require("react")
            local useState = React.useState
            local count, setCount = useState(0)
            return React.createElement("View", {}, count)
        end

        local element, fiber, err = mockHooks.renderComponent(TestComponent, { test = true })
        T.expect(err).toBe(nil)
        T.expect(element).toNotBe(nil)
        T.expect(element.type).toBe("View")
    end)

    T.it("should support useCallback", function()
        local function TestComponent(props)
            local React = require("react")
            local useState = React.useState
            local useCallback = React.useCallback

            local count, setCount = useState(0)
            local increment = useCallback(function()
                setCount(count + 1)
            end, { count })

            return React.createElement("Button", { onPress = increment }, "Click")
        end

        local element, fiber, err = mockHooks.renderComponent(TestComponent, {})
        T.expect(err).toBe(nil)
        T.expect(element).toNotBe(nil)
    end)

    T.it("should support useEffect", function()
        local function TestComponent(props)
            local React = require("react")
            local useState = React.useState
            local useEffect = React.useEffect

            local value, setValue = useState("initial")

            useEffect(function()
                setValue("effect ran")
            end, {})

            return React.createElement("Text", {}, value)
        end

        local element, fiber, err = mockHooks.renderComponent(TestComponent, {})
        T.expect(err).toBe(nil)
        T.expect(element).toNotBe(nil)
    end)
end)

T.summary()
