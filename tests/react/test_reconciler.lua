-- tests/react/test_reconciler.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local React = require("react")
local Reconciler = require("react.Reconciler")
local mockDisplay = require("tests.helpers.mock_display")

-- Minimal host config for testing
local testHostConfig = {
    createInstance = function(type, props)
        local obj = mockDisplay.newGroup()
        obj._type = type
        obj._props = props
        return obj
    end,
    createTextInstance = function(text)
        local obj = mockDisplay.newGroup()
        obj._type = "TEXT"
        obj._text = text
        return obj
    end,
    appendChild = function(parent, child)
        parent:insert(child)
    end,
    removeChild = function(parent, child)
        child:removeSelf()
    end,
    updateInstance = function(instance, oldProps, newProps)
        instance._props = newProps
    end,
    updateTextInstance = function(instance, oldText, newText)
        instance._text = newText
    end,
}

T.describe("Reconciler", function()
    T.it("renders a single host element", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(testHostConfig)

        reconciler.render(
            React.createElement("View", { testProp = "hello" }),
            container
        )

        T.expect(container.numChildren).toBe(1)
        T.expect(container[1]._type).toBe("View")
        T.expect(container[1]._props.testProp).toBe("hello")
    end)

    T.it("renders nested elements", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(testHostConfig)

        reconciler.render(
            React.createElement("View", nil,
                React.createElement("Text", { value = "hi" })
            ),
            container
        )

        T.expect(container.numChildren).toBe(1)
        T.expect(container[1].numChildren).toBe(1)
        T.expect(container[1][1]._type).toBe("Text")
    end)

    T.it("renders function components", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(testHostConfig)

        local function MyComponent(props)
            return React.createElement("View", { id = props.name })
        end

        reconciler.render(
            React.createElement(MyComponent, { name = "test" }),
            container
        )

        T.expect(container.numChildren).toBe(1)
        T.expect(container[1]._props.id).toBe("test")
    end)

    T.it("updates props on re-render", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(testHostConfig)

        reconciler.render(
            React.createElement("View", { color = "red" }),
            container
        )
        T.expect(container[1]._props.color).toBe("red")

        reconciler.render(
            React.createElement("View", { color = "blue" }),
            container
        )
        T.expect(container.numChildren).toBe(1)
        T.expect(container[1]._props.color).toBe("blue")
    end)

    T.it("removes children on re-render", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(testHostConfig)

        reconciler.render(
            React.createElement("View", nil,
                React.createElement("Text"),
                React.createElement("Text")
            ),
            container
        )
        T.expect(container[1].numChildren).toBe(2)

        reconciler.render(
            React.createElement("View", nil,
                React.createElement("Text")
            ),
            container
        )
        T.expect(container[1].numChildren).toBe(1)
    end)

    T.it("handles useState triggering re-render", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(testHostConfig)
        local setCount

        local function Counter()
            local count, set = React.useState(0)
            setCount = set
            return React.createElement("Text", { value = count })
        end

        reconciler.render(React.createElement(Counter), container)
        T.expect(container[1]._props.value).toBe(0)

        setCount(5)
        reconciler.flushUpdates()
        T.expect(container[1]._props.value).toBe(5)
    end)
end)

T.summary()
