--- Global touch finger registry.
-- Tracks which component owns each finger (event.id).
-- Prevents two components from fighting over the same finger.
-- Inspired by labo_papercut_dinosaur's TouchManager canFocus/setFocus pattern.
-- @module lib.TouchRegistry

local M = {}

-- [event.id] = owner_instance (the display object that claimed this finger)
local focusMap = {}

--- Check if a finger can be claimed by the given owner.
-- Returns true if the finger is unclaimed or already owned by this owner.
-- @param id any Touch event.id
-- @param owner table Display object or component instance
-- @return boolean
function M.canFocus(id, owner)
    local cur = focusMap[id]
    return cur == nil or cur == owner
end

--- Claim a finger for an owner.
-- @param id any Touch event.id
-- @param owner table Display object or component instance
function M.claim(id, owner)
    focusMap[id] = owner
end

--- Release a specific finger. Only the current owner can release it.
-- @param id any Touch event.id
-- @param owner table Display object or component instance
function M.release(id, owner)
    if focusMap[id] == owner then
        focusMap[id] = nil
    end
end

--- Release all fingers owned by this owner (cleanup sweep).
-- @param owner table Display object or component instance
function M.releaseAll(owner)
    for id, o in pairs(focusMap) do
        if o == owner then focusMap[id] = nil end
    end
end

--- Get the owner of a finger.
-- @param id any Touch event.id
-- @return table|nil Owner instance or nil
function M.getOwner(id)
    return focusMap[id]
end

--- Clear all focus mappings (scene transition safety).
function M.clearAll()
    focusMap = {}
end

--- Force-cancel a finger: remove from registry and return the owner
-- so the caller can send a synthetic cancelled event.
-- @param id any Touch event.id
-- @return table|nil Previous owner
function M.cancelFinger(id)
    local owner = focusMap[id]
    focusMap[id] = nil
    return owner
end

--- Get count of active fingers (for debugging).
-- @return number
function M.activeCount()
    local n = 0
    for _ in pairs(focusMap) do n = n + 1 end
    return n
end

return M
