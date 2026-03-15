-- react/init.lua
local ReactElement = require("react.ReactElement")
local Hooks = require("react.Hooks")

local React = {}

-- Core
React.createElement = ReactElement.createElement
React.isValidElement = ReactElement.isValidElement

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

-- Fragment (represented as special type)
React.Fragment = "$$react.fragment"

-- Internal (for reconciler)
React._Hooks = Hooks
React._ReactElement = ReactElement

return React
