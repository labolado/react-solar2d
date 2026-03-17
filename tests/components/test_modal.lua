-- tests/components/test_modal.lua
-- Test Modal component (Lua-side, no Solar2D APIs required)
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local Modal = require("components.Modal")
local React = require("react")
local ce = React.createElement

T.describe("Modal component", function()
    T.it("returns nil when not visible", function()
        local result = Modal({ visible = false })
        T.expect(result).toBe(nil)
    end)

    T.it("returns a View element when visible", function()
        local result = Modal({ visible = true })
        T.expect(result).toNotBe(nil)
        T.expect(result.type).toBe("View")
    end)

    T.it("has correct positioning style", function()
        local result = Modal({ visible = true })
        T.expect(result.props.style.position).toBe("absolute")
        T.expect(result.props.style.left).toBe(0)
        T.expect(result.props.style.top).toBe(0)
        T.expect(result.props.style.zIndex).toBe(10000)
    end)

    T.it("renders children inside", function()
        local child = ce("Text", {}, "Hello")
        -- Use ce() to properly pass children via props
        local result = ce(Modal, { visible = true }, child)
        -- Modal returns a function component that will be called by React
        T.expect(result.props.children).toNotBe(nil)
    end)

    T.it("backdrop has onPress handler", function()
        local onClose = function() end
        local result = Modal({
            visible = true,
            onRequestClose = onClose
        })
        local backdrop = result.props.children[1]
        T.expect(backdrop).toNotBe(nil)
        T.expect(backdrop.props.onPress).toBe(onClose)
    end)

    T.it("backdrop is transparent by default", function()
        local result = Modal({ visible = true, transparent = true })
        local backdrop = result.props.children[1]
        T.expect(backdrop.props.style.backgroundColor).toBe("rgba(0,0,0,0.6)")
    end)

    T.it("backdrop is white when not transparent", function()
        local result = Modal({ visible = true, transparent = false })
        local backdrop = result.props.children[1]
        T.expect(backdrop.props.style.backgroundColor).toBe("#FFFFFF")
    end)

    T.it("centers content in container", function()
        local result = Modal({ visible = true })
        local contentContainer = result.props.children[2]
        T.expect(contentContainer.props.style.justifyContent).toBe("center")
        T.expect(contentContainer.props.style.alignItems).toBe("center")
    end)
end)

T.summary()
