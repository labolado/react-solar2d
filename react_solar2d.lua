--- React-Solar2D root module.
-- Re-exports React core, renderer, components, style, animated, and navigation APIs.
-- Loaded via plugin.react-solar2d (requires plugin system) or symlinked for dev.
-- @module react_solar2d

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
RN.forwardRef = React.forwardRef
RN.useId = React.useId
RN.useImperativeHandle = React.useImperativeHandle
RN.useDebugValue = React.useDebugValue
RN.useSyncExternalStore = React.useSyncExternalStore

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
RN.SectionList = Components.SectionList
RN.TextInput = Components.TextInput
RN.Modal = Components.Modal
RN.Switch = Components.Switch
RN.Pressable = Components.Pressable
RN.ActivityIndicator = Components.ActivityIndicator
RN.RefreshControl = Components.RefreshControl
RN.KeyboardAvoidingView = Components.KeyboardAvoidingView
RN.SafeAreaView = Components.SafeAreaView
RN.ImageBackground = Components.ImageBackground
RN.DraggableView = Components.DraggableView
RN.PinchableView = Components.PinchableView
RN.DrawingCanvas = Components.DrawingCanvas
RN.Joystick = Components.Joystick
RN.PagerSlideView = Components.PagerSlideView
RN.ConfirmButton = Components.ConfirmButton
RN.SwitchButton = Components.SwitchButton

-- Touch
RN.TouchRegistry = require("lib.TouchRegistry")

-- Navigation
local Navigation = require("navigation")
RN.NavigationContainer = Navigation.NavigationContainer
RN.createStackNavigator = Navigation.createStackNavigator
RN.createBottomTabNavigator = Navigation.createBottomTabNavigator
RN.createDrawerNavigator = Navigation.createDrawerNavigator
RN.Header = Navigation.Header
RN.NavigationTestUtils = Navigation.NavigationTestUtils

-- SDF Shapes: anti-aliased vector shapes via GLSL (optional)
local sdfOk, SDFShapes = pcall(require, "lib.sdf-shapes")
if sdfOk then RN.SDFShapes = SDFShapes end

return RN
