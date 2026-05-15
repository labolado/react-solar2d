-- Bootstrap entry point for Solar2D plugin system.
-- Solar2D loads this when require("plugin.react-solar2d") is called.
-- Corona's custom require only searches for flat .lua files, not ?/init.lua.
-- We override the global require so sub-module directories resolve correctly.
do
    local info = debug.getinfo(1, "S")
    local dir = info.source:match("^@(.+/)")
    if dir then
        local origRequire = _G.require
        _G.require = function(name)
            if package.loaded[name] then return package.loaded[name] end
            -- Check dir + name/init.lua (subdirectory packages)
            local path = dir .. name:gsub("%.", "/") .. "/init.lua"
            local f = loadfile(path)
            if f then
                local result = f()
                package.loaded[name] = result
                return result
            end
            -- Check dir + name.lua (flat files)
            path = dir .. name:gsub("%.", "/") .. ".lua"
            f = loadfile(path)
            if f then
                local result = f()
                package.loaded[name] = result
                return result
            end
            -- Fallback to original require
            return origRequire(name)
        end
    end
end
return require("react_solar2d")
