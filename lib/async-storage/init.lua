-- lib/async-storage/init.lua
-- @react-native-async-storage/async-storage implementation for Solar2D
-- Pure Lua, uses JSON files in system.DocumentsDirectory

local M = {}

-- Use Solar2D's json or fall back to test helper
local ok, json = pcall(require, "json")
if not ok then
    json = require("tests.helpers.json")
end

-- Handle system availability (Solar2D vs test environment)
local STORAGE_DIR, pathForFile
if system then
    STORAGE_DIR = system.DocumentsDirectory
    pathForFile = system.pathForFile
else
    -- Test environment fallback
    STORAGE_DIR = "/tmp"
    pathForFile = function(filename, dir)
        return dir .. "/" .. filename
    end
end

local STORAGE_FILE = "async_storage.json"

-- In-memory cache
cache = nil

-- Load data from disk
local function loadFromDisk()
    if cache ~= nil then return cache end

    local path = pathForFile(STORAGE_FILE, STORAGE_DIR)
    local file = io.open(path, "r")

    if file then
        local contents = file:read("*a")
        io.close(file)

        local ok, data = pcall(json.decode, contents)
        if ok and type(data) == "table" then
            cache = data
            return cache
        end
    end

    cache = {}
    return cache
end

-- Save data to disk
local function saveToDisk()
    local path = pathForFile(STORAGE_FILE, STORAGE_DIR)
    local file = io.open(path, "w")

    if file then
        local ok, encoded = pcall(json.encode, cache)
        if ok then
            file:write(encoded)
        end
        io.close(file)
        return ok
    end

    return false
end

-- Get item from storage
function M.getItem(key, callback)
    assert(type(key) == "string", "key must be a string")

    local data = loadFromDisk()
    local value = data[key]

    if callback then
        timer.performWithDelay(0, function()
            callback(nil, value)
        end)
    end

    return value
end

-- Set item in storage
function M.setItem(key, value, callback)
    assert(type(key) == "string", "key must be a string")
    assert(type(value) == "string", "value must be a string")

    local data = loadFromDisk()
    data[key] = value

    local success = saveToDisk()

    if callback then
        timer.performWithDelay(0, function()
            if success then
                callback(nil)
            else
                callback({ message = "Failed to save to disk" })
            end
        end)
    end

    return success
end

-- Remove item from storage
function M.removeItem(key, callback)
    assert(type(key) == "string", "key must be a string")

    local data = loadFromDisk()
    data[key] = nil

    local success = saveToDisk()

    if callback then
        timer.performWithDelay(0, function()
            if success then
                callback(nil)
            else
                callback({ message = "Failed to save to disk" })
            end
        end)
    end

    return success
end

-- Merge item with existing value (for objects)
function M.mergeItem(key, value, callback)
    assert(type(key) == "string", "key must be a string")
    assert(type(value) == "string", "value must be a string")

    local data = loadFromDisk()
    local existing = data[key]

    local ok1, existingTable = pcall(json.decode, existing or "{}")
    local ok2, newTable = pcall(json.decode, value)

    if ok1 and ok2 and type(existingTable) == "table" and type(newTable) == "table" then
        for k, v in pairs(newTable) do
            existingTable[k] = v
        end

        local ok3, merged = pcall(json.encode, existingTable)
        if ok3 then
            data[key] = merged
            local success = saveToDisk()

            if callback then
                timer.performWithDelay(0, function()
                    if success then
                        callback(nil)
                    else
                        callback({ message = "Failed to save to disk" })
                    end
                end)
            end

            return success
        end
    end

    return M.setItem(key, value, callback)
end

-- Get all keys
function M.getAllKeys(callback)
    local data = loadFromDisk()
    local keys = {}

    for k, _ in pairs(data) do
        table.insert(keys, k)
    end

    if callback then
        timer.performWithDelay(0, function()
            callback(nil, keys)
        end)
    end

    return keys
end

-- Clear all storage
function M.clear(callback)
    cache = {}
    local success = saveToDisk()

    if callback then
        timer.performWithDelay(0, function()
            if success then
                callback(nil)
            else
                callback({ message = "Failed to clear storage" })
            end
        end)
    end

    return success
end

-- Get storage info
function M.getCurrentSize()
    local data = loadFromDisk()
    local path = pathForFile(STORAGE_FILE, STORAGE_DIR)
    local file = io.open(path, "r")

    if file then
        local size = file:seek("end")
        io.close(file)
        return size
    end

    return 0
end

return M
