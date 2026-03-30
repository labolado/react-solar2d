--- React core module.
-- Provides createElement, hooks (useState, useEffect, etc.), context, memo, Fragment, and reconciler access.
-- @module react

local ReactElement = require("react.ReactElement")
local Hooks = require("react.Hooks")

local React = {}

-- Core
React.createElement = ReactElement.createElement
React.isValidElement = ReactElement.isValidElement
React.forwardRef = ReactElement.forwardRef

-- Hooks
React.useState = Hooks.useState
React.useReducer = Hooks.useReducer
React.useEffect = Hooks.useEffect
React.useLayoutEffect = Hooks.useLayoutEffect
React.useRef = Hooks.useRef
React.useMemo = Hooks.useMemo
React.useCallback = Hooks.useCallback
React.useContext = Hooks.useContext
React.createContext = Hooks.createContext
React.useId = Hooks.useId
React.useImperativeHandle = Hooks.useImperativeHandle
React.useDebugValue = Hooks.useDebugValue
React.useSyncExternalStore = Hooks.useSyncExternalStore

-- Fragment (represented as special type)
React.Fragment = "$$react.fragment"

--- memo: skip re-render if props haven't changed.
-- @param component function Component to wrap
-- @param[opt] areEqual function Optional custom equality comparison
-- @return table Memoized component descriptor
-- @usage
-- local MemoizedButton = React.memo(Button)
function React.memo(component, areEqual)
    return {
        _isMemo = true,
        component = component,
        areEqual = areEqual,  -- optional custom comparison
    }
end

-- Internal (for reconciler)
React._Hooks = Hooks
React._ReactElement = ReactElement

return React
