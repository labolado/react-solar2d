-- Real Modal test - simulates actual Solar2D structure
package.path = "./?.lua;./?/init.lua;" .. package.path

local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay
display.contentWidth = 1536
display.contentHeight = 2048
display.contentCenterX = 768
display.contentCenterY = 1024

native = { systemFont = "systemFont", systemFontBold = "systemFontBold" }
timer = { performWithDelay = function() return {} end, cancel = function() end }
transition = { to = function() end, cancel = function() end }

local React = require("react")
local HostConfig = require("renderer.HostConfig")
local Renderer = require("renderer")

print("=== Real Modal Structure Test ===")

-- Create structure like KitchenSinkApp:
-- View (flex:1)
--   categoryBar (zIndex:100)
--   content (zIndex:50)
--     ScrollView
--       Modal (zIndex:10000)

local root = display.newGroup()

-- 1. Create categoryBar
local categoryBar = HostConfig.createInstance("View", {
    style = {
        width = 1536, height = 100,
        backgroundColor = "#161B22",
        zIndex = 100,
    },
})
categoryBar.y = 40  -- SAFE_TOP
print("categoryBar created at y=40, zIndex=100")

-- 2. Create content area (below categoryBar)
local content = HostConfig.createInstance("View", {
    style = {
        width = 1536, height = 1908,  -- 2048 - 100 - 40
        backgroundColor = "#0D1117",
        zIndex = 50,
    },
})
content.y = 140  -- 40 + 100
print("content created at y=140, zIndex=50")

-- 3. Create Modal inside content
local modalClosed = false
local modal = HostConfig.createInstance("View", {
    style = {
        position = "absolute",
        left = 0, top = 0,
        width = 1536, height = 2048,
        zIndex = 10000,
    },
})

-- Modal backdrop
local backdrop = HostConfig.createInstance("View", {
    style = {
        position = "absolute",
        left = 0, top = 0,
        width = 1536, height = 2048,
        backgroundColor = "rgba(0,0,0,0.6)",
    },
    onPress = function()
        modalClosed = true
        print("Backdrop pressed - modal should close")
    end,
})

-- Modal content
local dialog = HostConfig.createInstance("View", {
    style = {
        width = 300, height = 200,
        backgroundColor = "#FFFFFF",
        borderRadius = 12,
    },
})
dialog.x = 768 - 150  -- center
dialog.y = 1024 - 100

HostConfig.appendChild(modal, backdrop)
HostConfig.appendChild(modal, dialog)
HostConfig.appendChild(content, modal)

print("\nStructure created:")
print("  content.y =", content.y)
print("  modal is child of content")
print("  modal.zIndex = 10000, content.zIndex = 50")

-- Now test Yoga layout application
print("\n=== Simulating layout pass ===")

-- Apply layout like renderer does
-- If style.position == "absolute", use top/left directly
local style = { position = "absolute", left = 0, top = 0 }
local l, t = 0, 0  -- Yoga would compute this as relative to content

if style.position == "absolute" then
    if style.left ~= nil then l = style.left end
    if style.top ~= nil then t = style.top end
end

print("Modal layout position: l=" .. l .. ", t=" .. t)
print("Modal actual y (including parent):", content.y + t)

-- The issue: modal.y = content.y (140) + t (0) = 140
-- But it should be at screen y=0 to cover categoryBar

print("\n=== ISSUE FOUND ===")
print("Modal.y = 140 (inside content), but needs to be at 0 to cover categoryBar")
print("\nSOLUTION: Modal must NOT be inside content")
print("  Option 1: Render Modal as sibling of content (not child)")
print("  Option 2: Use screen coordinates for position:absolute")

-- Test option 2: Calculate screen position
print("\n=== Testing Option 2 ===")
local screenY = content.y + t  -- This is what renderer does
print("Current: screenY = content.y + t = " .. screenY)

-- Correct approach: Modal needs to be at 0,0 in screen space
-- So it must be a child of root, not content
