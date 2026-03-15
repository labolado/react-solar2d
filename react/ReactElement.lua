-- react/ReactElement.lua
local M = {}

local REACT_ELEMENT_TYPE = "$$react.element"

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
        props.children = select(1, ...)
    elseif childCount > 1 then
        local children = {}
        for i = 1, childCount do
            children[i] = select(i, ...)
        end
        props.children = children
    end

    return {
        ["$$typeof"] = REACT_ELEMENT_TYPE,
        type = type,
        key = key,
        ref = ref,
        props = props,
    }
end

function M.isValidElement(object)
    return type(object) == "table" and object["$$typeof"] == REACT_ELEMENT_TYPE
end

M.REACT_ELEMENT_TYPE = REACT_ELEMENT_TYPE

return M
