-- tests/components/test_text.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local React = require("react")
local Text = require("components.Text")

T.describe("Text component", function()
    T.it("is a host element type", function()
        local el = React.createElement(Text, { style = { fontSize = 16 } }, "Hello")
        T.expect(el.type).toBe("Text")
        T.expect(el.props.children).toBe("Hello")
    end)
end)

T.summary()
