-- plugins/yoga/test/main.lua
-- Open this file in Corona Simulator to test the plugin in-engine.
-- Prerequisite: copy plugin_yoga.so to the same directory or set package.cpath.

-- Try loading as Solar2D plugin first, fall back to direct cpath
local ok, yoga = pcall(require, "plugin.yoga")
if not ok then
    package.cpath = "./?.so;" .. package.cpath
    yoga = require("plugin_yoga")
end

-- Build a simple layout: header + content + footer
local root = yoga.newNode()
root:setWidth(display.contentWidth)
root:setHeight(display.contentHeight)

local header = yoga.newNode()
header:setHeight(60)

local content = yoga.newNode()
content:setFlexGrow(1)

local footer = yoga.newNode()
footer:setHeight(40)

root:insertChild(header, 0)
root:insertChild(content, 1)
root:insertChild(footer, 2)

root:calculateLayout()

-- Render results using Solar2D display objects
local colors = {
    { 0.2, 0.6, 1 },    -- header: blue
    { 0.9, 0.9, 0.9 },  -- content: light gray
    { 0.2, 0.8, 0.4 },  -- footer: green
}
local labels = { "Header (60px)", "Content (flex:1)", "Footer (40px)" }

for i = 0, 2 do
    local node = root:getChild(i)
    local l, t, w, h = node:getLayout()
    local c = colors[i + 1]

    local rect = display.newRect(l + w/2, t + h/2, w, h)
    rect:setFillColor(c[1], c[2], c[3])

    local text = display.newText({
        text = labels[i + 1],
        x = l + w/2,
        y = t + h/2,
        fontSize = 16,
    })
    text:setFillColor(0, 0, 0)
end

-- Display info
local info = display.newText({
    text = string.format("Yoga v3.2.1 | %dx%d", display.contentWidth, display.contentHeight),
    x = display.contentCenterX,
    y = display.contentHeight - 15,
    fontSize = 12,
})
info:setFillColor(1, 1, 1)

root:freeRecursive()
print("Yoga Solar2D integration test: SUCCESS")
