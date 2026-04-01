--- React element creation and validation.
-- Implements createElement, isValidElement, and forwardRef.
-- @module react.ReactElement

local M = {}

--- Internal marker for React elements.
-- @field REACT_ELEMENT_TYPE string
local REACT_ELEMENT_TYPE = "$$react.element"

--- Create a React element (virtual DOM node).
-- Extracts key/ref from config, collects children from varargs.
-- Single child is stored directly; multiple children as an array.
-- Nil/false children are filtered out to avoid sparse arrays.
-- @param type string|function|table Element type — host tag, function component, or forwardRef
-- @param config table|nil Props including key, ref; key/ref are extracted, rest become props
-- @param ... any Child elements (strings, numbers, tables, or nil)
-- @return table React element with $$typeof, type, key, ref, props
function M.createElement(type, config, ...)
    local props = {}
    local key = nil
    local ref = nil

    if config then
        key = config.key
        ref = config.ref
        for k, v in pairs(config) do
            if k ~= "key" and k ~= "ref" and k ~= "__self" and k ~= "__source" then
                props[k] = v
            end
        end
    end

    local childCount = select("#", ...)
    if childCount == 1 then
        local child = select(1, ...)
        if child ~= nil then
            props.children = child
        end
    elseif childCount > 1 then
        local children = {}
        for i = 1, childCount do
            local child = select(i, ...)
            if child ~= nil and child ~= false then
                children[#children + 1] = child
            end
        end
        if #children == 1 then
            props.children = children[1]
        elseif #children > 1 then
            props.children = children
        end
    end

    return {
        ["$$typeof"] = REACT_ELEMENT_TYPE,
        type = type,
        key = key,
        ref = ref,
        props = props,
    }
end

--- Check whether an object is a valid React element.
-- @param object any Value to check
-- @return boolean True if object is a table with the React element marker
function M.isValidElement(object)
    return type(object) == "table" and object["$$typeof"] == REACT_ELEMENT_TYPE
end

--- Create a component that forwards its ref to a child.
-- The returned table is recognized by the reconciler via `_isForwardRef`.
-- @param render function(props, ref) Render function receiving props and forwarded ref
-- @return table ForwardRef component descriptor
function M.forwardRef(render)
    local forwardRefComponent = {
        _isForwardRef = true,
        render = render,
    }
    return forwardRefComponent
end

M.REACT_ELEMENT_TYPE = REACT_ELEMENT_TYPE

return M
