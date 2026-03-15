-- react_solar2d.lua (root module)
local React = require("react")
local ReactSolar2D = require("renderer")
local StyleSheet = require("style.StyleSheet")
local processColor = require("style.processColor")
local Components = require("components")
local Animated = require("animated")

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
RN.getSafeAreaInsets = ReactSolar2D.getSafeAreaInsets

-- Style
RN.StyleSheet = StyleSheet
RN.processColor = processColor

-- Animated
RN.Animated = Animated

-- Components
RN.View = Components.View
RN.Text = Components.Text
RN.Image = Components.Image
RN.Button = Components.Button
RN.TouchableOpacity = Components.TouchableOpacity
RN.ScrollView = Components.ScrollView
RN.FlatList = Components.FlatList
RN.TextInput = Components.TextInput
RN.Modal = Components.Modal
RN.Switch = Components.Switch
RN.Pressable = Components.Pressable
RN.ActivityIndicator = Components.ActivityIndicator

return RN
