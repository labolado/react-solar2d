-- tests/helpers/json.lua
-- JSON stub for testing outside Solar2D

local M = {}

-- Simple JSON encoder
function M.encode(obj)
    local function serialize(o)
        if type(o) == "nil" then
            return "null"
        elseif type(o) == "boolean" then
            return o and "true" or "false"
        elseif type(o) == "number" then
            return tostring(o)
        elseif type(o) == "string" then
            return string.format("%q", o)
        elseif type(o) == "table" then
            local items = {}
            local isArray = true
            local n = 0
            for k, v in pairs(o) do
                n = n + 1
                if type(k) ~= "number" or k ~= n then
                    isArray = false
                    break
                end
            end

            if isArray then
                for i = 1, n do
                    table.insert(items, serialize(o[i]))
                end
                return "[" .. table.concat(items, ",") .. "]"
            else
                for k, v in pairs(o) do
                    if type(k) == "string" then
                        table.insert(items, string.format("%q:%s", k, serialize(v)))
                    end
                end
                return "{" .. table.concat(items, ",") .. "}"
            end
        end
        return "null"
    end

    return serialize(obj)
end

-- Simple JSON decoder (handles basic cases needed for testing)
function M.decode(str)
    if not str or str == "" then
        return nil
    end

    str = str:gsub("^%s*", ""):gsub("%s*$", "")

    -- null
    if str == "null" then
        return nil
    end

    -- boolean
    if str == "true" then return true end
    if str == "false" then return false end

    -- number
    local num = tonumber(str)
    if num then return num end

    -- string
    if str:match('^"') then
        local val = str:match('^"(.-)"$')
        if val then
            -- Unescape
            val = val:gsub("\\n", "\n")
            val = val:gsub("\\t", "\t")
            val = val:gsub('\\"', '"')
            val = val:gsub("\\\\", "\\")
            return val
        end
        return nil
    end

    -- array
    if str:match('^%[') then
        local result = {}
        local content = str:match('^%[(.-)%]$')
        if content and content ~= "" then
            -- Parse array elements
            local pos = 1
            while pos <= #content do
                -- Find next value
                local val, endPos = M._parseValue(content, pos)
                if val ~= nil then
                    table.insert(result, val)
                    pos = endPos + 1
                    -- Skip comma and whitespace
                    while pos <= #content and content:sub(pos, pos):match("[%s,]") do
                        pos = pos + 1
                    end
                else
                    break
                end
            end
        end
        return result
    end

    -- object
    if str:match('^{') then
        local result = {}
        local content = str:match('^{(.-)}$')
        if content and content ~= "" then
            local pos = 1
            while pos <= #content do
                -- Skip whitespace
                while pos <= #content and content:sub(pos, pos):match("%s") do
                    pos = pos + 1
                end

                -- Parse key (must be string)
                if content:sub(pos, pos) ~= '"' then break end
                local keyEnd = pos + 1
                while keyEnd <= #content do
                    if content:sub(keyEnd, keyEnd) == '"' and content:sub(keyEnd-1, keyEnd-1) ~= "\\" then
                        break
                    end
                    keyEnd = keyEnd + 1
                end
                local key = content:sub(pos + 1, keyEnd - 1)
                pos = keyEnd + 1

                -- Skip whitespace and colon
                while pos <= #content and content:sub(pos, pos):match("[%s:]") do
                    pos = pos + 1
                end

                -- Parse value
                local val, endPos = M._parseValue(content, pos)
                if val ~= nil then
                    result[key] = val
                    pos = endPos + 1
                    -- Skip comma and whitespace
                    while pos <= #content and content:sub(pos, pos):match("[%s,]") do
                        pos = pos + 1
                    end
                else
                    break
                end
            end
        end
        return result
    end

    return nil
end

-- Parse a single JSON value starting at pos
function M._parseValue(str, pos)
    pos = pos or 1

    -- Skip whitespace
    while pos <= #str and str:sub(pos, pos):match("%s") do
        pos = pos + 1
    end

    if pos > #str then return nil, pos end

    local char = str:sub(pos, pos)

    -- string
    if char == '"' then
        local endPos = pos + 1
        while endPos <= #str do
            if str:sub(endPos, endPos) == '"' and str:sub(endPos-1, endPos-1) ~= "\\" then
                local val = M.decode(str:sub(pos, endPos))
                return val, endPos
            end
            endPos = endPos + 1
        end
        return nil, pos
    end

    -- object or array
    if char == '{' or char == '[' then
        local closeChar = char == '{' and '}' or ']'
        local depth = 1
        local endPos = pos + 1
        while endPos <= #str and depth > 0 do
            local c = str:sub(endPos, endPos)
            if c == '"' then
                -- Skip string
                endPos = endPos + 1
                while endPos <= #str do
                    if str:sub(endPos, endPos) == '"' and str:sub(endPos-1, endPos-1) ~= "\\" then
                        break
                    end
                    endPos = endPos + 1
                end
            elseif c == char then
                depth = depth + 1
            elseif c == closeChar then
                depth = depth - 1
            end
            endPos = endPos + 1
        end
        local val = M.decode(str:sub(pos, endPos - 1))
        return val, endPos - 1
    end

    -- number, boolean, null
    local endPos = pos
    while endPos <= #str do
        local c = str:sub(endPos, endPos)
        if c:match("[%s,}%]]") then
            break
        end
        endPos = endPos + 1
    end

    local val = M.decode(str:sub(pos, endPos - 1))
    return val, endPos - 1
end

return M
