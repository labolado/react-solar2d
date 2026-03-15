-- tests/components/test_view.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local React = require("react")
local View = require("components.View")

T.describe("View component", function()
    T.it("returns a host element of type View", function()
        local el = React.createElement(View, { style = { flex = 1 } })
        T.expect(el.type).toBe("View")
    end)

    T.it("passes through style and children", function()
        local child = React.createElement("Text", nil, "hi")
        local el = React.createElement(View, {
            style = { backgroundColor = "red" },
        }, child)
        T.expect(el.props.style.backgroundColor).toBe("red")
        T.expect(el.props.children).toBe(child)
    end)
end)

T.summary()
