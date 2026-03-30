--- DeepLinking module.
-- Resolves a URL to navigation state based on linking config.
-- @module navigation.DeepLinking

local M = {}

-- Parse path pattern like "detail/:id" into { segments, paramNames }
local function parsePattern(pattern)
    local segments = {}
    local paramNames = {}
    for seg in pattern:gmatch("[^/]+") do
        if seg:sub(1, 1) == ":" then
            segments[#segments + 1] = ":"
            paramNames[#paramNames + 1] = seg:sub(2)
        else
            segments[#segments + 1] = seg
        end
    end
    return segments, paramNames
end

-- Match a path against a pattern, extract params
local function matchPattern(path, pattern)
    local pathSegs = {}
    for seg in path:gmatch("[^/]+") do
        pathSegs[#pathSegs + 1] = seg
    end

    local patternSegs, paramNames = parsePattern(pattern)

    if #pathSegs ~= #patternSegs then return nil end

    local params = {}
    local paramIdx = 0
    for i, pseg in ipairs(patternSegs) do
        if pseg == ":" then
            paramIdx = paramIdx + 1
            params[paramNames[paramIdx]] = pathSegs[i]
        elseif pseg ~= pathSegs[i] then
            return nil
        end
    end

    return params
end

--- Resolve a URL to a navigation state.
-- @param url string Incoming URL
-- @param linkingConfig table {prefixes={}, config={screens={}}}
-- @return table|nil Navigation state or nil if no match
function M.resolve(url, linkingConfig)
    if not url or not linkingConfig then return nil end

    -- Strip prefix
    local path = url
    for _, prefix in ipairs(linkingConfig.prefixes or {}) do
        if path:sub(1, #prefix) == prefix then
            path = path:sub(#prefix + 1)
            break
        end
    end

    -- Remove leading/trailing slashes
    path = path:gsub("^/+", ""):gsub("/+$", "")

    local screens = linkingConfig.config and linkingConfig.config.screens or {}

    -- Try each screen pattern
    for screenName, pattern in pairs(screens) do
        if type(pattern) == "string" then
            local params = matchPattern(path, pattern)
            if params then
                local routes = {}
                -- If not root screen, add Home first
                if pattern ~= "" then
                    -- Find the root screen (empty pattern)
                    for rootName, rootPattern in pairs(screens) do
                        if rootPattern == "" then
                            routes[#routes + 1] = { name = rootName }
                            break
                        end
                    end
                end
                routes[#routes + 1] = {
                    name = screenName,
                    params = next(params) and params or nil,
                }
                return {
                    type = "stack",
                    index = #routes,
                    routes = routes,
                }
            end
        end
    end

    return nil
end

return M
