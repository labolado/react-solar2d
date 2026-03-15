-- layout/init.lua
-- High-level Yoga wrapper for react-solar2d
-- Translates RN-style style tables into Yoga C API calls

local ok, yoga = pcall(require, "plugin.yoga")
if not ok then
    package.cpath = "./plugins/yoga/build/?.so;" .. package.cpath
    yoga = require("plugin_yoga")
end

local M = {}

local function parsePercent(v)
    if type(v) == "string" then
        return tonumber(v:match("^(.-)%%$"))
    end
    return nil
end

local dimensionSetters = {
    width = function(n, v)
        if v == "auto" then n:setWidthAuto()
        elseif parsePercent(v) then n:setWidthPercent(parsePercent(v))
        else n:setWidth(v) end
    end,
    height = function(n, v)
        if v == "auto" then n:setHeightAuto()
        elseif parsePercent(v) then n:setHeightPercent(parsePercent(v))
        else n:setHeight(v) end
    end,
    minWidth    = function(n, v) n:setMinWidth(v) end,
    minHeight   = function(n, v) n:setMinHeight(v) end,
    maxWidth    = function(n, v) n:setMaxWidth(v) end,
    maxHeight   = function(n, v) n:setMaxHeight(v) end,
}

local flexDirectionMap = {
    column             = yoga.FlexDirection.column,
    ["column-reverse"] = yoga.FlexDirection.columnReverse,
    row                = yoga.FlexDirection.row,
    ["row-reverse"]    = yoga.FlexDirection.rowReverse,
}

local justifyMap = {
    ["flex-start"]    = yoga.Justify.flexStart,
    center            = yoga.Justify.center,
    ["flex-end"]      = yoga.Justify.flexEnd,
    ["space-between"] = yoga.Justify.spaceBetween,
    ["space-around"]  = yoga.Justify.spaceAround,
    ["space-evenly"]  = yoga.Justify.spaceEvenly,
}

local alignMap = {
    auto              = yoga.Align.auto,
    ["flex-start"]    = yoga.Align.flexStart,
    center            = yoga.Align.center,
    ["flex-end"]      = yoga.Align.flexEnd,
    stretch           = yoga.Align.stretch,
    baseline          = yoga.Align.baseline,
    ["space-between"] = yoga.Align.spaceBetween,
    ["space-around"]  = yoga.Align.spaceAround,
    ["space-evenly"]  = yoga.Align.spaceEvenly,
}

local wrapMap = {
    nowrap             = yoga.Wrap.noWrap,
    wrap               = yoga.Wrap.wrap,
    ["wrap-reverse"]   = yoga.Wrap.wrapReverse,
}

local positionTypeMap = {
    relative = yoga.PositionType.relative,
    absolute = yoga.PositionType.absolute,
}

local overflowMap = {
    visible = yoga.Overflow.visible,
    hidden  = yoga.Overflow.hidden,
    scroll  = yoga.Overflow.scroll,
}

local E = yoga.Edge
local G = yoga.Gutter

function M.applyStyle(node, style)
    if not style then return end

    for prop, setter in pairs(dimensionSetters) do
        if style[prop] ~= nil then setter(node, style[prop]) end
    end

    if style.flexDirection then
        node:setFlexDirection(flexDirectionMap[style.flexDirection] or yoga.FlexDirection.column)
    end
    if style.justifyContent then
        node:setJustifyContent(justifyMap[style.justifyContent] or yoga.Justify.flexStart)
    end
    if style.alignItems then
        node:setAlignItems(alignMap[style.alignItems] or yoga.Align.stretch)
    end
    if style.alignSelf then
        node:setAlignSelf(alignMap[style.alignSelf] or yoga.Align.auto)
    end
    if style.alignContent then
        node:setAlignContent(alignMap[style.alignContent] or yoga.Align.flexStart)
    end
    if style.flexWrap then
        node:setFlexWrap(wrapMap[style.flexWrap] or yoga.Wrap.noWrap)
    end

    if style.flex then node:setFlex(style.flex) end
    if style.flexGrow then node:setFlexGrow(style.flexGrow) end
    if style.flexShrink then node:setFlexShrink(style.flexShrink) end
    if style.flexBasis then
        if style.flexBasis == "auto" then node:setFlexBasisAuto()
        else node:setFlexBasis(style.flexBasis) end
    end

    if style.padding then node:setPadding(E.all, style.padding) end
    if style.paddingVertical then node:setPadding(E.vertical, style.paddingVertical) end
    if style.paddingHorizontal then node:setPadding(E.horizontal, style.paddingHorizontal) end
    if style.paddingTop then node:setPadding(E.top, style.paddingTop) end
    if style.paddingRight then node:setPadding(E.right, style.paddingRight) end
    if style.paddingBottom then node:setPadding(E.bottom, style.paddingBottom) end
    if style.paddingLeft then node:setPadding(E.left, style.paddingLeft) end

    if style.margin then
        if style.margin == "auto" then node:setMarginAuto(E.all)
        else node:setMargin(E.all, style.margin) end
    end
    if style.marginVertical then
        if style.marginVertical == "auto" then node:setMarginAuto(E.vertical)
        else node:setMargin(E.vertical, style.marginVertical) end
    end
    if style.marginHorizontal then
        if style.marginHorizontal == "auto" then node:setMarginAuto(E.horizontal)
        else node:setMargin(E.horizontal, style.marginHorizontal) end
    end
    if style.marginTop then
        if style.marginTop == "auto" then node:setMarginAuto(E.top)
        else node:setMargin(E.top, style.marginTop) end
    end
    if style.marginRight then
        if style.marginRight == "auto" then node:setMarginAuto(E.right)
        else node:setMargin(E.right, style.marginRight) end
    end
    if style.marginBottom then
        if style.marginBottom == "auto" then node:setMarginAuto(E.bottom)
        else node:setMargin(E.bottom, style.marginBottom) end
    end
    if style.marginLeft then
        if style.marginLeft == "auto" then node:setMarginAuto(E.left)
        else node:setMargin(E.left, style.marginLeft) end
    end

    if style.borderWidth then node:setBorder(E.all, style.borderWidth) end
    if style.borderTopWidth then node:setBorder(E.top, style.borderTopWidth) end
    if style.borderRightWidth then node:setBorder(E.right, style.borderRightWidth) end
    if style.borderBottomWidth then node:setBorder(E.bottom, style.borderBottomWidth) end
    if style.borderLeftWidth then node:setBorder(E.left, style.borderLeftWidth) end

    if style.gap then node:setGap(G.all, style.gap) end
    if style.rowGap then node:setGap(G.row, style.rowGap) end
    if style.columnGap then node:setGap(G.column, style.columnGap) end

    if style.position then
        node:setPositionType(positionTypeMap[style.position] or yoga.PositionType.relative)
    end
    if style.top then node:setPosition(E.top, style.top) end
    if style.right then node:setPosition(E.right, style.right) end
    if style.bottom then node:setPosition(E.bottom, style.bottom) end
    if style.left then node:setPosition(E.left, style.left) end

    if style.display == "none" then node:setDisplay(yoga.Display.none) end
    if style.overflow then
        node:setOverflow(overflowMap[style.overflow] or yoga.Overflow.visible)
    end

    if style.aspectRatio then node:setAspectRatio(style.aspectRatio) end
end

function M.newNode(style)
    local node = yoga.newNode()
    M.applyStyle(node, style)
    return node
end

M.yoga = yoga
M.Edge = yoga.Edge
M.Gutter = yoga.Gutter

return M
