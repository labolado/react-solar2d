--- Navigation module.
-- Public exports for the navigation system.
-- @module navigation

local M = {}

M.NavigationContainer = require("navigation.NavigationContainer")
M.createStackNavigator = require("navigation.StackNavigator")
M.createBottomTabNavigator = require("navigation.TabNavigator")
M.createDrawerNavigator = require("navigation.DrawerNavigator")
M.Header = require("navigation.Header")
M.NavigationTestUtils = require("navigation.NavigationTestUtils")

return M
