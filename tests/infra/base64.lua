-- base64.lua - Base64 encoding/decoding for Solar2D
-- Pure Lua implementation for test server screenshot encoding

local M = {}

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64lookup = {}
for i = 1, #b64chars do
    b64lookup[b64chars:sub(i, i)] = i - 1
end

-- Encode binary string to base64
function M.encode(data)
    local result = {}
    local padding = (3 - #data % 3) % 3

    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        b = b or 0
        c = c or 0

        local n = a * 65536 + b * 256 + c
        local w = b64chars:sub(n // 262144 % 64 + 1, n // 262144 % 64 + 1)
            .. b64chars:sub(n // 4096 % 64 + 1, n // 4096 % 64 + 1)
            .. b64chars:sub(n // 64 % 64 + 1, n // 64 % 64 + 1)
            .. b64chars:sub(n % 64 + 1, n % 64 + 1)

        table.insert(result, w)
    end

    result = table.concat(result)
    if padding > 0 then
        result = result:sub(1, -padding - 1) .. string.rep('=', padding)
    end

    return result
end

-- Decode base64 to binary string
function M.decode(data)
    data = data:gsub('%s', ''):gsub('=', '')
    local result = {}

    for i = 1, #data, 4 do
        local a = b64lookup[data:sub(i, i)] or 0
        local b = b64lookup[data:sub(i + 1, i + 1)] or 0
        local c = b64lookup[data:sub(i + 2, i + 2)] or 0
        local d = b64lookup[data:sub(i + 3, i + 3)] or 0

        local n = a * 262144 + b * 4096 + c * 64 + d
        table.insert(result, string.char(n // 65536 % 256))
        if data:sub(i + 2, i + 2) ~= '' then
            table.insert(result, string.char(n // 256 % 256))
        end
        if data:sub(i + 3, i + 3) ~= '' then
            table.insert(result, string.char(n % 256))
        end
    end

    return table.concat(result)
end

return M
