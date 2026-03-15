-- tests/helpers/mock_display.lua
local M = {}

local nextId = 0
local function newId()
    nextId = nextId + 1
    return nextId
end

local function newDisplayObject(objType)
    local obj = {
        _type = objType,
        _id = newId(),
        _children = {},
        _parent = nil,
        _listeners = {},
        x = 0, y = 0,
        width = 0, height = 0,
        anchorX = 0.5, anchorY = 0.5,
        alpha = 1,
        isVisible = true,
        rotation = 0,
        xScale = 1, yScale = 1,
        _fillColor = {1, 1, 1, 1},
        _strokeColor = {0, 0, 0, 1},
        strokeWidth = 0,
        numChildren = 0,
    }

    function obj:setFillColor(r, g, b, a)
        self._fillColor = {r, g or r, b or r, a or 1}
    end
    function obj:setStrokeColor(r, g, b, a)
        self._strokeColor = {r, g or r, b or r, a or 1}
    end
    function obj:addEventListener(event, fn)
        self._listeners[event] = self._listeners[event] or {}
        table.insert(self._listeners[event], fn)
    end
    function obj:removeEventListener(event, fn)
        local list = self._listeners[event]
        if list then
            for i, f in ipairs(list) do
                if f == fn then table.remove(list, i); break end
            end
        end
    end
    function obj:toFront() end
    function obj:toBack() end
    function obj:removeSelf()
        if self._parent then
            for i, c in ipairs(self._parent._children) do
                if c == self then
                    table.remove(self._parent._children, i)
                    self._parent.numChildren = #self._parent._children
                    break
                end
            end
            self._parent = nil
        end
    end

    -- Group methods
    function obj:insert(indexOrChild, child)
        local c = child or indexOrChild
        if c._parent then c:removeSelf() end
        c._parent = self
        if child then
            table.insert(self._children, indexOrChild, c)
        else
            table.insert(self._children, c)
        end
        self.numChildren = #self._children
    end

    function obj:remove(indexOrChild)
        if type(indexOrChild) == "number" then
            local c = self._children[indexOrChild]
            if c then c._parent = nil end
            table.remove(self._children, indexOrChild)
        else
            indexOrChild:removeSelf()
        end
        self.numChildren = #self._children
    end

    setmetatable(obj, {
        __index = function(t, k)
            if type(k) == "number" then return t._children[k] end
        end
    })

    return obj
end

function M.newGroup()
    return newDisplayObject("group")
end

function M.newRect(parent, x, y, w, h)
    local r = newDisplayObject("rect")
    r.x, r.y, r.width, r.height = x, y, w, h
    r.path = { width = w, height = h }
    if parent then parent:insert(r) end
    return r
end

function M.newRoundedRect(parent, x, y, w, h, cornerRadius)
    local r = M.newRect(parent, x, y, w, h)
    r._type = "roundedRect"
    r._cornerRadius = cornerRadius
    return r
end

function M.newText(options)
    local t = newDisplayObject("text")
    t.text = options.text or ""
    t.size = options.fontSize or 14
    t.x = options.x or 0
    t.y = options.y or 0
    t.width = options.width or 100
    t.height = options.height or 20
    t._font = options.font or "systemFont"
    t._align = options.align or "left"
    if options.parent then options.parent:insert(t) end
    return t
end

function M.newImage(parent, filename, x, y)
    local img = newDisplayObject("image")
    img._filename = filename
    img.x, img.y = x or 0, y or 0
    if parent then parent:insert(img) end
    return img
end

function M.newImageRect(parent, filename, w, h)
    local img = M.newImage(parent, filename)
    img.width, img.height = w, h
    img.path = { width = w, height = h }
    return img
end

function M.newContainer(parentOrW, wOrH, hOrNil)
    local c = newDisplayObject("container")
    if type(parentOrW) == "number" then
        -- display.newContainer(w, h)
        c.width, c.height = parentOrW, wOrH
    else
        -- display.newContainer(parent, w, h)
        c.width, c.height = wOrH, hOrNil
        if parentOrW then parentOrW:insert(c) end
    end
    c.anchorChildren = true
    return c
end

-- currentStage mock (for setFocus)
M.currentStage = {
    setFocus = function(self, obj) end
}

function M.resetIdCounter()
    nextId = 0
end

return M
