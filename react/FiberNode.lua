-- react/FiberNode.lua
local M = {}

--[[
FiberNode represents a unit of work in the reconciler tree.
Simplified from React's full Fiber — no lanes, no double-buffering.

Fields:
  tag          : "host" | "function" | "class" | "root" | "text"
  type         : string (host) or function (component)
  key          : string or nil
  ref          : table or nil
  props        : table
  stateNode    : Solar2D display object (for host nodes) or nil
  child        : first child FiberNode
  sibling      : next sibling FiberNode
  parent       : parent FiberNode (called "return" in React)
  alternate    : previous fiber for diffing
  memoizedState: first hook in linked list (for function components)
  stateQueue   : pending state updates
  effectTag    : "PLACEMENT" | "UPDATE" | "DELETION" | nil
  effects      : list of effect callbacks to run
]]

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

function M.createHostRootFiber()
    return M.createFiber("root", nil, nil, {})
end

return M
