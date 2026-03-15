-- init.lua (react-solar2d root)
local React = require("react")
local ReactSolar2D = require("renderer")
local StyleSheet = require("style.StyleSheet")
local processColor = require("style.processColor")
local Components = require("components")

local RN = {}

-- React core
RN.createElement = React.createElement
RN.useState = React.useState
RN.useEffect = React.useEffect
RN.useLayoutEffect = React.useLayoutEffect
RN.useRef = React.useRef
RN.useMemo = React.useMemo
RN.useCallback = React.useCallback
RN.useContext = React.useContext
RN.useReducer = React.useReducer
RN.createContext = React.createContext
RN.Fragment = React.Fragment

-- Renderer
RN.render = ReactSolar2D.render
RN.unmount = ReactSolar2D.unmount
RN.flushUpdates = ReactSolar2D.flushUpdates
RN.startAutoFlush = ReactSolar2D.startAutoFlush

-- Style
RN.StyleSheet = StyleSheet

-- Components (also available as direct exports, RN-style)
RN.View = Components.View
RN.Text = Components.Text
RN.Image = Components.Image
RN.Button = Components.Button
RN.TouchableOpacity = Components.TouchableOpacity

return RN
