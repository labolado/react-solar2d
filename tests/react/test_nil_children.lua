-- tests/react/test_nil_children.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

local ReactElement = require("react.ReactElement")

T.describe("ReactElement.createElement: nil children filtering", function()
    T.it("filters nil children from multiple arguments", function()
        local child1 = ReactElement.createElement("View", { id = "child1" })
        local child2 = ReactElement.createElement("View", { id = "child2" })
        
        local element = ReactElement.createElement("View", { id = "parent" }, nil, child1, child2)
        
        -- Should only have child1 and child2, nil should be filtered
        T.expect(element.props.children).toBeTruthy()
        -- When multiple children remain, they should be in a table
        T.expect(type(element.props.children)).toBe("table")
        T.expect(#element.props.children).toBe(2)
        T.expect(element.props.children[1].props.id).toBe("child1")
        T.expect(element.props.children[2].props.id).toBe("child2")
    end)

    T.it("filters false children", function()
        local child1 = ReactElement.createElement("View", { id = "child1" })
        
        local element = ReactElement.createElement("View", { id = "parent" }, false, child1)
        
        -- Should only have child1, false should be filtered
        T.expect(element.props.children).toBeTruthy()
        -- Single child should be unwrapped
        T.expect(type(element.props.children)).toBe("table")
        T.expect(element.props.children.props.id).toBe("child1")
    end)

    T.it("returns single child directly (not in array) when only one child", function()
        local child1 = ReactElement.createElement("View", { id = "child1" })
        
        local element = ReactElement.createElement("View", { id = "parent" }, child1)
        
        -- Single child should be stored directly, not in an array
        T.expect(element.props.children).toBeTruthy()
        T.expect(element.props.children.props.id).toBe("child1")
    end)

    T.it("returns nil children when all children are nil", function()
        local element = ReactElement.createElement("View", { id = "parent" }, nil, nil, nil)
        
        -- When all children are nil, props.children should not exist
        T.expect(element.props.children).toBeNil()
    end)

    T.it("returns nil children when only one nil child", function()
        local element = ReactElement.createElement("View", { id = "parent" }, nil)
        
        -- Single nil child should result in no children prop
        T.expect(element.props.children).toBeNil()
    end)

    T.it("handles mixed nil and valid children correctly", function()
        local child1 = ReactElement.createElement("View", { id = "child1" })
        local child2 = ReactElement.createElement("View", { id = "child2" })
        local child3 = ReactElement.createElement("View", { id = "child3" })
        
        local element = ReactElement.createElement("View", { id = "parent" }, nil, child1, nil, child2, nil, child3, nil)
        
        -- Should have child1, child2, child3
        T.expect(element.props.children).toBeTruthy()
        T.expect(type(element.props.children)).toBe("table")
        T.expect(#element.props.children).toBe(3)
        T.expect(element.props.children[1].props.id).toBe("child1")
        T.expect(element.props.children[2].props.id).toBe("child2")
        T.expect(element.props.children[3].props.id).toBe("child3")
    end)

    T.it("handles leading nil children", function()
        local child1 = ReactElement.createElement("View", { id = "child1" })
        local child2 = ReactElement.createElement("View", { id = "child2" })
        
        local element = ReactElement.createElement("View", { id = "parent" }, nil, nil, child1, child2)
        
        T.expect(element.props.children).toBeTruthy()
        T.expect(type(element.props.children)).toBe("table")
        T.expect(#element.props.children).toBe(2)
    end)

    T.it("handles trailing nil children", function()
        local child1 = ReactElement.createElement("View", { id = "child1" })
        local child2 = ReactElement.createElement("View", { id = "child2" })
        
        local element = ReactElement.createElement("View", { id = "parent" }, child1, child2, nil, nil)
        
        T.expect(element.props.children).toBeTruthy()
        T.expect(type(element.props.children)).toBe("table")
        T.expect(#element.props.children).toBe(2)
    end)

    T.it("preserves string/number children", function()
        local element = ReactElement.createElement("Text", { id = "text" }, "Hello", " ", "World")
        
        T.expect(element.props.children).toBeTruthy()
        T.expect(type(element.props.children)).toBe("table")
        T.expect(#element.props.children).toBe(3)
        T.expect(element.props.children[1]).toBe("Hello")
        T.expect(element.props.children[2]).toBe(" ")
        T.expect(element.props.children[3]).toBe("World")
    end)

    T.it("filters nil in mixed string/nil children", function()
        local element = ReactElement.createElement("Text", { id = "text" }, "Hello", nil, "World")
        
        T.expect(element.props.children).toBeTruthy()
        T.expect(type(element.props.children)).toBe("table")
        T.expect(#element.props.children).toBe(2)
        T.expect(element.props.children[1]).toBe("Hello")
        T.expect(element.props.children[2]).toBe("World")
    end)

    T.it("handles empty children call", function()
        local element = ReactElement.createElement("View", { id = "parent" })
        
        T.expect(element.props.children).toBeNil()
    end)
end)

T.describe("ReactElement.createElement: element structure", function()
    T.it("creates valid React element structure", function()
        local element = ReactElement.createElement("View", { id = "test" })
        
        T.expect(element["$$typeof"]).toBe("$$react.element")
        T.expect(element.type).toBe("View")
        T.expect(element.props).toBeTruthy()
        T.expect(element.props.id).toBe("test")
    end)

    T.it("extracts key and ref from config", function()
        local element = ReactElement.createElement("View", { 
            id = "test", 
            key = "unique-key",
            ref = function() end
        })
        
        T.expect(element.key).toBe("unique-key")
        T.expect(type(element.ref)).toBe("function")
        -- key and ref should not be in props
        T.expect(element.props.key).toBeNil()
        T.expect(element.props.ref).toBeNil()
    end)

    T.it("filters __self and __source from props", function()
        local element = ReactElement.createElement("View", { 
            id = "test",
            __self = "self",
            __source = "source"
        })
        
        T.expect(element.props.id).toBe("test")
        T.expect(element.props.__self).toBeNil()
        T.expect(element.props.__source).toBeNil()
    end)
end)

T.describe("ReactElement.isValidElement", function()
    T.it("returns true for valid React elements", function()
        local element = ReactElement.createElement("View", {})
        
        T.expect(ReactElement.isValidElement(element)).toBe(true)
    end)

    T.it("returns false for non-table values", function()
        T.expect(ReactElement.isValidElement(nil)).toBe(false)
        T.expect(ReactElement.isValidElement("string")).toBe(false)
        T.expect(ReactElement.isValidElement(42)).toBe(false)
        T.expect(ReactElement.isValidElement(true)).toBe(false)
    end)

    T.it("returns false for regular tables", function()
        T.expect(ReactElement.isValidElement({})).toBe(false)
        T.expect(ReactElement.isValidElement({ type = "View" })).toBe(false)
    end)

    T.it("returns false for elements with wrong $$typeof", function()
        T.expect(ReactElement.isValidElement({ ["$$typeof"] = "wrong" })).toBe(false)
    end)
end)

T.describe("ReactElement.forwardRef", function()
    T.it("creates forwardRef component", function()
        local renderFn = function(props, ref) return {} end
        local forwardRef = ReactElement.forwardRef(renderFn)
        
        T.expect(type(forwardRef)).toBe("table")
        T.expect(forwardRef._isForwardRef).toBe(true)
        T.expect(forwardRef.render).toBe(renderFn)
    end)
end)

T.summary()
