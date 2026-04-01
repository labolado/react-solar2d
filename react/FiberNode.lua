--- Fiber node creation for the reconciler tree.
-- Simplified from React's full Fiber — no lanes, no double-buffering.
-- Each FiberNode represents a unit of work with links to child, sibling, parent.
-- @module react.FiberNode
--
-- @field tag string "host"|"function"|"class"|"root"|"text"
-- @field type string|function Host tag name or component function
-- @field key string|nil Reconciliation key
-- @field ref table|nil Ref object for accessing instance
-- @field props table Component props
-- @field stateNode table|nil Solar2D display object (host nodes) or nil
-- @field child table|nil First child FiberNode
-- @field sibling table|nil Next sibling FiberNode
-- @field parent table|nil Parent FiberNode ("return" in upstream React)
-- @field alternate table|nil Previous fiber for diffing
-- @field memoizedState table|nil First hook in linked list (function components)
-- @field stateQueue table Pending state updates
-- @field effectTag string|nil "PLACEMENT"|"UPDATE"|"DELETION"
-- @field effects table List of effect callbacks to run

local M = {}

--- Create a new FiberNode.
-- @param tag string Fiber tag: "host", "function", "class", "root", or "text"
-- @param type string|function|nil Element type
-- @param key string|nil Reconciliation key
-- @param props table|nil Component props (defaults to empty table)
-- @return table FiberNode
function M.createFiber(tag, type, key, props)
    return {
        tag = tag,
        type = type,
        key = key,
        ref = nil,
        props = props or {},
        stateNode = nil,
        child = nil,
        sibling = nil,
        parent = nil,
        alternate = nil,
        memoizedState = nil,
        stateQueue = {},
        effectTag = nil,
        effects = {},
    }
end

--- Create the root fiber for a render tree.
-- @return table FiberNode with tag="root"
function M.createHostRootFiber()
    return M.createFiber("root", nil, nil, {})
end

return M
