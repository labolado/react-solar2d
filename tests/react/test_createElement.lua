-- tests/react/test_createElement.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local createElement = require("react.ReactElement").createElement

T.describe("createElement", function()
    T.it("creates element with type and props", function()
        local el = createElement("View", { style = { flex = 1 } })
        T.expect(el.type).toBe("View")
        T.expect(el.props.style.flex).toBe(1)
        T.expect(el.props.children).toBeNil()
    end)

    T.it("handles children as third+ args", function()
        local child1 = createElement("Text", nil, "Hello")
        local parent = createElement("View", nil, child1)
        T.expect(parent.props.children).toBe(child1)
    end)

    T.it("handles multiple children as table", function()
        local c1 = createElement("Text", nil, "A")
        local c2 = createElement("Text", nil, "B")
        local parent = createElement("View", nil, c1, c2)
        T.expect(#parent.props.children).toBe(2)
    end)

    T.it("handles string children", function()
        local el = createElement("Text", nil, "Hello World")
        T.expect(el.props.children).toBe("Hello World")
    end)

    T.it("merges children from props and args", function()
        local el = createElement("View", { key = "a" }, "child")
        T.expect(el.props.children).toBe("child")
        T.expect(el.props.key).toBeNil() -- key extracted
        T.expect(el.key).toBe("a")
    end)

    T.it("handles nil props", function()
        local el = createElement("View")
        T.expect(el.type).toBe("View")
        T.expect(type(el.props)).toBe("table")
    end)

    T.it("handles function components", function()
        local function MyComp(props)
            return createElement("View")
        end
        local el = createElement(MyComp, { title = "test" })
        T.expect(el.type).toBe(MyComp)
        T.expect(el.props.title).toBe("test")
    end)
end)

T.summary()
